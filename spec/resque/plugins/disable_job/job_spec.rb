# frozen_string_literal: true

require_relative '../../../spec_helper'

module Resque::Plugins::DisableJob
  describe Job do
    before do
      ::Resque.redis.namespace = 'random:namespace'
      RedisDbTruncater.flush
    end

    describe '#disabled?' do
      before do
        @job = SimpleJob.new
      end

      class SimpleJob
        include Resque::Plugins::DisableJob
      end

      it 'should work' do
        Job.disable_job('TestJob', specific_args: [654])
        rule = Rule.new('TestJob', [654])
        Resque.redis.expects(:incr).with(rule.rule_key).once
        assert_equal(true, Job.disabled?('TestJob', [654]))
        assert_equal(false, Job.disabled?('TestJob', []))
      end

      it 'should return false if the rule is expired' do
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(true, Job.disabled?('TestJob', [654]))
        rule = Rule.new('TestJob', [654])
        Resque.redis.expire(rule.rule_key, -1)
        Job.expects(:remove_specific_rule).once
        assert_equal(false, Job.disabled?('TestJob', [654]))
      end

      it 'should return false if there is and error with the JSON parsing' do
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(true, Job.disabled?('TestJob', [654]))
        JSON.expects(:parse).raises(StandardError).once
        assert_equal(false, Job.disabled?('TestJob', [654]))
      end
    end

    describe '#disable_job' do
      it 'should save data in Redis' do
        assert_empty(Resque.redis.keys)
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(3, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
      end

      it 'should set the specified TTL in Redis' do
        assert_empty(Resque.redis.keys)
        Job.disable_job('TestJob', specific_args: [654], timeout: 2 * SimpleJob::DEFAULT_TIMEOUT)
        assert_equal(3, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        rule = Rule.new('TestJob', [654])
        assert_equal(true, Resque.redis.ttl(rule.rule_key) > SimpleJob::DEFAULT_TIMEOUT)
      end
    end

    describe '#enable_job' do
      it 'should remove the rule' do
        assert_empty(Resque.redis.keys)
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(3, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        Job.enable_job('TestJob', specific_args: [654])
        assert_equal(0, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
      end
    end

    describe '#enable_all' do
      it 'should remove all the job\'s rules' do
        assert_empty(Resque.redis.keys)
        Job.disable_job('TestJob')
        assert_equal(3, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(4, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        Job.enable_all('TestJob')
        assert_equal(0, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
      end
    end

    describe '#enable_all!' do
      it 'should remove all the rules in the system' do
        assert_empty(Resque.redis.keys)
        Job.disable_job('TestJob')
        assert_equal(3, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        Job.disable_job('SampleJob', specific_args: [654])
        assert_equal(5, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
        Job.enable_all!
        assert_equal(0, Resque.redis.keys("#{Rule::JOBS_SET}*").size)
      end
    end
  end
end
