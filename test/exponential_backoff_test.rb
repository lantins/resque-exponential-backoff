require 'test_helper'

class GoodJob
    extend Resque::Plugins::ExponentialBackoff
    @queue = :testing
    
    def self.perform(*args)
    end
end

module BadJob
    extend Resque::Plugins::ExponentialBackoff
    @queue = :testing
    
    def self.perform(*args)
        raise
    end
end

module CustomBackoffStrategyJob
    extend Resque::Plugins::ExponentialBackoff
    @queue = :testing
    @backoff_strategy = [3600, 86_400]
    
    def self.perform(*args)
        raise
    end
end

module CustomBackoffJob
    extend Resque::Plugins::ExponentialBackoff
    @queue = :testing
    
    def self.retry_delay_seconds
        attempts * 42
    end
    
    def self.perform(*args)
        raise
    end
end

class ExponentialBackoffTest < Test::Unit::TestCase
    def setup
        Resque.redis.flushall
        @worker = Resque::Worker.new(:testing)
    end
    
    def test_resque_plugin_lint
        assert_nothing_raised do
            Resque::Plugin.lint(Resque::Plugins::ExponentialBackoff)
        end
    end
    
    def test_resque_version
        major, minor, patch = Resque::Version.split('.')
        assert_equal 1, major.to_i, 'major version does not match'
        assert_operator minor.to_i, :>=, 8, 'minor version is too low'
    end
    
    def test_good_job
        Resque.enqueue(GoodJob, 1234, { :cats => :maiow }, [true, false, false])
        @worker.work(0)
        
        assert_equal 1, Resque.info[:processed]
        assert_equal 0, Resque.info[:failed]
        assert_equal 0, Resque.delayed_queue_schedule_size
    end
    
    def test_retry_job
        Resque.enqueue(BadJob, 1234)
        @worker.work(0)
        
        assert_equal 2, Resque.info[:processed]
        assert_equal 2, Resque.info[:failed]
        assert_equal 1, Resque.delayed_queue_schedule_size
        assert_equal Time.now.to_i + 60, Resque.delayed_queue_peek(0, 1).first
    end
    
    def test_custom_backoff_strategy_job
        Resque.enqueue(CustomBackoffStrategyJob, 1234)
        Resque.enqueue(CustomBackoffStrategyJob, 1234)
        @worker.work(0)
        
        assert_equal 2, Resque.info[:processed]
        assert_equal 2, Resque.info[:failed]
        
        delayed = Resque.delayed_queue_peek(0, 2)
        assert_equal Time.now.to_i + 3600, delayed.first
        assert_equal Time.now.to_i + 86_400, delayed.last
    end
    
    def test_custom_backoff_job
        Resque.enqueue(CustomBackoffJob)
        Resque.enqueue(CustomBackoffJob)
        @worker.work(0)
        
        assert_equal 2, Resque.info[:processed]
        assert_equal 2, Resque.info[:failed]
        
        delayed = Resque.delayed_queue_peek(0, 2)
        assert_equal Time.now.to_i + 42, delayed.first
        assert_equal Time.now.to_i + 84, delayed.last
    end
end