module Resque
    module Plugins
        ##
        # resque-exponential-backoff is a plugin to add retry/exponential backoff
        # to your resque jobs.
        # 
        # Simply extend your module/class with this module:
        # 
        #   require 'resque-exponential-backoff'
        #   
        #   class DeliverWebHook
        #       extend Resque::Plugins::ExponentialBackoff
        #       
        #       def self.perform(url, hook_id, hmac_key)
        #           heavy_lifting
        #       end
        #   end
        #
        # Or do something more custom:
        #
        #   class DeliverWebHook
        #       extend Resque::Plugins::ExponentialBackoff
        #       
        #       # max number of attempts.
        #       @max_attempts = 4
        #       # retry delay in seconds.
        #       @backoff_strategy = [0, 60]
        #
        #       # used to build redis key to store job attempts counter.
        #       def self.identifier(url, hook_id, hmac_key)
        #           "#{url}-#{hook_id}"
        #       end
        #
        #       def self.perform(url, hook_id, hmac_key)
        #           heavy_lifting
        #       end
        #   end
        module ExponentialBackoff
            
            ##
            # @abstract You may override to implement a custom identifier,
            #           you should consider doing this if your job arguments
            #           are many/long or may not cleanly cleanly to strings.
            #
            # Builds an identifier using the job arguments. This identifier
            # is used as part of the redis key.
            #
            # @param [Array] args job arguments
            # @return [String] job identifier
            def identifier(*args)
                args.join('-')
            end
            
            ##
            # Builds the redis key to be used for keeping state of the job
            # attempts.
            #
            # @return [String] redis key
            def key(*args)
                ['exponential-backoff', name, identifier(*args)].compact.join(":")
            end
            
            ##
            # Maximum number of attempts we can use to successfully perform the job.
            # Default value: 7
            #
            # @return [Fixnum] number of attempts
            def max_attempts
                @max_attempts ||= 7
            end
            
            ##
            # Number of attempts so far to try and perform the job.
            # Default value: 0
            #
            # @return [Fixnum] number of attempts
            def attempts
                @attempts ||= 0
            end
            
            ##
            # @abstract You may override to implement your own delay logic.
            #
            # Returns the number of seconds to delay until the job is tried
            # again. By default, this delay is taken from the `#backoff_strategy`.
            # 
            # @return [Number, #to_i] number of seconds to delay.
            def retry_delay_seconds
                backoff_strategy[attempts - 1] || backoff_strategy.last
            end
            
            ##
            # Default backoff strategy.
            # 
            #   1st retry  :  0 delay
            #   2nd retry  :  1 minute
            #   3rd retry  : 10 minutes
            #   4th retry  :  1 hour
            #   5th retry  :  3 hours
            #   6th retry  :  6 hours
            #
            # You can set your own backoff strategy in your job module/class:
            #
            # @example custom backoff strategy, in your class/module:
            #   @backoff_strategy = [0, 0, 120]
            #
            # Using this strategy, the first two retries will be immediate,
            # the third and any subsequent retries will be delayed by 2 minutes.
            def backoff_strategy
                @backoff_strategy ||= [0, 60, 600, 3600, 10_800, 21_600]
            end
            
            ##
            # Called before `#perform`.
            # - Initialise or increment attempts counter.
            def before_perform_exponential_backoff(*args)
                Resque.redis.setnx(key(*args), 0)         # default to 0 if not set.
                @attempts = Resque.redis.incr(key(*args)) # increment by 1.
            end
            
            ##
            # Called after if `#perform` was successfully.
            # - Delete attempts counter from redis.
            def after_perform_exponential_backoff(*args)
                delete_attempts_counter(*args)
            end
            
            ##
            # Called if the job raises an exception.
            # - Requeue the job if maximum attempts has not been reached.
            def on_failure_exponential_backoff(exception, *args)
                if attempts >= max_attempts
                    delete_attempts_counter(*args)
                    return
                end
                
                requeue(*args)
            end
            
            ##
            # Delete the attempts counter from redis, keepin it clean ;-)
            def delete_attempts_counter(*args)
                Resque.redis.del(key(*args))
            end
            
            ##
            # Requeue the current job, immediately or delayed if `#retry_delay_seconds`
            # returns grater then zero.
            # 
            # @param [Array] args job arguments
            def requeue(*args)
                if retry_delay_seconds > 0
                    Resque.enqueue_in(retry_delay_seconds, self, *args)
                else
                    Resque.enqueue(self, *args)
                end
            end
        end
    end
end