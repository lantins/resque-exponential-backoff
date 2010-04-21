module Resque
    module Plugins
        module ExponentialBackoff
            def identifier(*args)
                args.join('-')
            end
            
            def key(*args)
                ['exponential-backoff', name, identifier(*args)].compact.join(":")
            end
            
            def max_attempts
                @max_attempts ||= 6
            end
            
            def attempt
                @attempt ||= 0
            end
            
            def retry_delay_seconds
                backoff_strategy[attempt - 1] || backoff_strategy.last
            end
            
            def backoff_strategy
                # 0, 1m, 10m, 1h, 3h, 6h
                @backoff_strategy ||= [0, 60, 600, 3600, 10_800, 21_600, 43_200]
            end
            
            def before_perform_exponential_backoff(*args)
                Resque.redis.setnx(key(*args), 0)
                @attempt = Resque.redis.incr(key(*args))
            end
            
            def after_perform_exponential_backoff(*args)
                Resque.redis.del(key(*args))
            end
            
            def on_failure_exponential_backoff(exception, *args)
                if attempt >= max_attempts
                    Resque.redis.del(key(*args))
                    return
                end
                
                requeue(*args)
            end
            
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