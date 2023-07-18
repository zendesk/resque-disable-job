# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'codecov'
SimpleCov.formatter = SimpleCov::Formatter::Codecov

require 'bundler/setup'
require 'resque'
require 'resque-disable-job'

require 'minitest/autorun'
require 'mocha/minitest'

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
