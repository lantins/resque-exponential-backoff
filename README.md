resque-exponential-backoff
==========================

A [Resque][rq] plugin. Requires Resque 1.8.0 & [resque-scheduler][rqs].

resque-exponential-backoff is a plugin to add retry/exponential backoff to
your resque jobs.

Usage
-----
Simply extend your module/class with this module:

    require 'resque-exponential-backoff'
    
    class DeliverWebHook
        extend Resque::Plugins::ExponentialBackoff
        
        def self.perform(url, hook_id, hmac_key)
            heavy_lifting
        end
    end
  

### BEFORE performing job
The job increments the number of `attempts` in redis. The first attempt == 1.

### SUCSESSFULL job
Sucsessful jobs clean up any 'attempts state' from redis.

### FAILED job
If `attempts < max_attempts` the job will be requeued. The delay between retry
attempts is determine using the backoff strategy.

*Exceptions are always passed the failure backends.*

Customise & Extend
------------------

### Defaults

If you just extend with this module and nothing else, these are the defaults:

    @max_attempts = 7
    
                # key: m = minutes, h = hours
                # no delay, 1m, 10m,   1h,    3h,    6h
    @backoff_strategy = [0, 60, 600, 3600, 10800, 21600]

### Job identifier/key

**n.b.** The job attempts count is incremented/stored in a redis key, the key
is built using the name of your jobs class/module and its arguments.

If you have lots of arguments, really long ones, you should consider overriding
`#identifier` to implement a more suitable custom identifier.

    def self.identifier(database_id, massive_url_list, meow_purr)
        "#{database_id}"
    end

For the examples in this readme, the default key looks like this:

    exponential-backoff:<name>:<args>
    exponential-backoff:DeliverWebHook:http://lividpenguin.com-1305-cd8079192'


### Custom max attempts, backoff strategy

    # 4 attempts maximum.
    #
    # 1st retry: no delay
    # 2nd retry: 60 seconds delay
    # nth retry:  2 minutes delay
    class DeliverWebHook
        extend Resque::Plugins::ExponentialBackoff
        
        @max_attempts = 5
        @backoff_strategy = [0, 60, 120]
        
        def self.perform(url, hook_id, hmac_key)
            heavy_lifting
        end
    end

### Custom delay handling

Override `#retry_delay_seconds` to implement your own delay handling.

    class DeliverWebHook
        extend Resque::Plugins::ExponentialBackoff
        @max_attempts = 5
        
        def self.perform(url, hook_id, hmac_key)
            heavy_lifting
        end
        
        def self.retry_delay_seconds
            (attempts * 60) ** 2
        end
    end


Install
-------

    gem install resque-exponential-backoff


License
-------
Copyright (c) 2010 Luke Antins <luke@lividpenguin.com>

Released under the MIT license. See LICENSE file for details.

[rq]: http://github.com/defunkt/resque
[rqs]: http://github.com/bvandenbos/resque-scheduler