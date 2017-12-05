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

      it 'should return false if there is a args type mismatch' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('SimpleJob', specific_args: [654])
        Job.disabled?('SimpleJob', { a: 654 }).must_equal false
        Job.disable_job('SimpleJob2', specific_args: { a: 654 })
        Job.disabled?('SimpleJob2', [654]).must_equal false
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
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 3
      end
    end

    describe '#enable_job' do
      it 'should remove the rule' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob', specific_args: [654])
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 3
        Job.enable_job('TestJob', specific_args: [654])
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 0
      end
    end

    describe '#enable_all' do
      it 'should remove all the job\'s rules' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob')
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 3
        Job.disable_job('TestJob', specific_args: [654])
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 4
        Job.enable_all('TestJob')
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 0
      end
    end

    describe '#enable_all!' do
      it 'should remove all the rules in the system' do
        Resque.redis.keys.must_be_empty
        Job.disable_job('TestJob')
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 3
        Job.disable_job('SampleJob', specific_args: [654])
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 5
        Job.enable_all!
        Resque.redis.keys(Rule::JOBS_SET + '*').size.must_equal 0
      end
    end

    describe '#args_match' do
      class SimpleJob
        include Resque::Plugins::DisableJob
      end

      before do
        @job = SimpleJob.new
      end

      [
        # job args,           set args,               should match?
        [[],                  [],                      true],
        [[20, 134, [134]],    [],                      true],
        [[20, 134, [134]],    [20],                    true],
        [[20, 134, [134]],    [20, 134],               true],
        [[20, 134, { a: 1 }], [20, 134, { a: 1 }],     true],
        [[20, 134, [134]],    [20, 13],               false],
        [[20, 134, [134, 4]], [21],                   false],
        [[20, 134, [134, 4]], [21, 134, 5],           false],
        [[20, 134, { a: 1 }], [21, 134, { a: 2 }],    false],
        [[20, 134, { a: 1 }], [21, 134, { a: 1 }],    false],
        [[20, 134, { a: 1 }], [21, 134, { a: 1 }, 9], false],
        [[20, 134, [134, 4]], [134],                  false],
        # [[20],              [20,134],               false], TODO fix this case, or should we?
        # Hash parameters
        [{ a: 20, b: 134 },   {},                      true],
        [{ a: 20, b: 134 },   { a: 20 },               true],
        [{ a: 20, b: 134 },   { b: 134 },              true],
        [{ a: 20, b: 134 },   { b: 134, a: 20 },       true]
      ].each do |args, set_args, match|
        it "#{match ? 'should' : "shouldn't"} match #{set_args} set with received #{args}" do
          Job.args_match(args, set_args).must_equal match
        end
      end
    end
  end
end
