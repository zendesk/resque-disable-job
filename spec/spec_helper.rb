require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'resque'
require 'resque-disable-job'

require 'minitest/autorun'
require 'mocha/setup'

def perform_next_job(worker, &block)
  return unless job = worker.reserve
  worker.perform(job, &block)
  worker.done_working
end

class RedisDbTruncater
  def self.flush
    redis = ::Resque.redis
    if (keys = redis.keys) && !keys.empty?
      redis.del(keys)
    end
  end
end
