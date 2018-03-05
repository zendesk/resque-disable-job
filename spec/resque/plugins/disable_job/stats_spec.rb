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
        Stats.all_disabled_jobs.size.must_equal 1
        Stats.all_disabled_jobs.first.must_be_kind_of Rule
        Stats.all_disabled_jobs.first.job_name.must_equal 'TestJob'

        Job.disable_job('TestJob2', specific_args: [654])
        Stats.all_disabled_jobs.map(&:job_name).sort.must_equal %w[TestJob TestJob2].sort
      end
    end

    describe '#job_disabled_rules' do
      it 'should work' do
        Job.disable_job('TestJob', specific_args: [654])
        Stats.job_disabled_rules('TestJob').map(&:serialized_arguments).must_equal ['[654]']
        Job.disable_job('TestJob', specific_args: [65])
        Stats.job_disabled_rules('TestJob').map(&:serialized_arguments).sort.must_equal %w([654] [65]).sort
        Job.enable_job('TestJob', specific_args: [654])
        Stats.job_disabled_rules('TestJob').map(&:serialized_arguments).must_equal ['[65]']
      end
    end

    describe '#disabled_stats' do
      it 'should work' do
        matched_job = 'SimpleJob'
        Job.disable_job('TestJob', specific_args: [])
        Job.disable_job('TestJob', specific_args: [654])
        Job.disable_job(matched_job, specific_args: { a: 4 })
        stats = Stats.disabled_stats
        stats.size.must_equal 3
        stats.first.must_be_kind_of Rule
        stats.map(&:count).must_equal [0, 0, 0]
        # This should increment the rule counter
        Job.disabled?(matched_job, [{ a: 4 }])
        Stats.disabled_stats.select { |r| r.job_name == matched_job }.first.count.must_equal 1
      end
    end
  end
end
