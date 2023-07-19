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
        Job.disabled?('TestJob', [654]).must_equal true
        Job.disabled?('TestJob', []).must_equal false
      end

      it 'should return false if the rule is expired' do
        Job.disable_job('TestJob', specific_args: [654])
        Job.disabled?('TestJob', [654]).must_equal true
        rule = Rule.new('TestJob', [654])
        Resque.redis.expire(rule.rule_key, -1)
        Job.expects(:remove_specific_rule).once
        Job.disabled?('TestJob', [654]).must_equal false
      end

      it 'should return false if there is and error with the JSON parsing' do
        Job.disable_job('TestJob', specific_args: [654])
        Job.disabled?('TestJob', [654]).must_equal true
        JSON.expects(:parse).raises(StandardError).once
        Job.disabled?('TestJob', [654]).must_equal false
      end
    end

    describe '#disable_job' do
      it 'should save data in Redis' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob', specific_args: [654])
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 3
      end

      it 'should set the specified TTL in Redis' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob', specific_args: [654], timeout: 2 * SimpleJob::DEFAULT_TIMEOUT)
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 3
        rule = Rule.new('TestJob', [654])
        (Resque.redis.ttl(rule.rule_key) > SimpleJob::DEFAULT_TIMEOUT).must_equal true
      end
    end

    describe '#enable_job' do
      it 'should remove the rule' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob', specific_args: [654])
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 3
        Job.enable_job('TestJob', specific_args: [654])
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 0
      end
    end

    describe '#enable_all' do
      it 'should remove all the job\'s rules' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob')
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 3
        Job.disable_job('TestJob', specific_args: [654])
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 4
        Job.enable_all('TestJob')
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 0
      end
    end

    describe '#enable_all!' do
      it 'should remove all the rules in the system' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob')
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 3
        Job.disable_job('SampleJob', specific_args: [654])
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 5
        Job.enable_all!
        Resque.redis.keys("#{Rule::JOBS_SET}*").size.must_equal 0
      end
    end
  end
end
