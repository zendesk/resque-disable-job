# frozen_string_literal: true

require_relative '../../../spec_helper'

module Resque::Plugins::DisableJob
  describe Job do
    before do
      ::Resque.redis.namespace = 'random:namespace'
      RedisDbTruncater.flush
    end

    describe '#all_disabled_jobs' do
      it 'should work' do
        Job.disable_job('TestJob', specific_args: [654])
        Stats.all_disabled_jobs.keys.must_equal ['TestJob']
        Job.disable_job('TestJob2', specific_args: [654])
        Stats.all_disabled_jobs.keys.sort.must_equal %w[TestJob TestJob2].sort
      end
    end

    describe '#job_disabled_rules' do
      it 'should work' do
        Job.disable_job('TestJob', specific_args: [654])
        Stats.job_disabled_rules('TestJob').values.must_equal ['[654]']
        Job.disable_job('TestJob', specific_args: [65])
        Stats.job_disabled_rules('TestJob').values.must_equal %w([654] [65])
        Job.enable_job('TestJob', specific_args: [654])
        Stats.job_disabled_rules('TestJob').values.must_equal ['[65]']
      end
    end

    describe '#disabled_stats' do
      it 'should work' do
        Job.disable_job('TestJob', specific_args: [])
        Job.disable_job('TestJob', specific_args: [654])
        Job.disable_job('SimpleJob', specific_args: { a: 4 })
        Stats.disabled_stats.size.must_equal 3
      end
    end
  end
end
