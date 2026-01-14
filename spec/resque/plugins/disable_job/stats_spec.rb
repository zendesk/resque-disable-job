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
        assert_equal(1, Stats.all_disabled_jobs.size)
        assert_kind_of(Rule, Stats.all_disabled_jobs.first)
        assert_equal('TestJob', Stats.all_disabled_jobs.first.job_name)

        Job.disable_job('TestJob2', specific_args: [654])
        assert_equal(%w[TestJob TestJob2].sort, Stats.all_disabled_jobs.map(&:job_name).sort)
      end
    end

    describe '#job_disabled_rules' do
      it 'should work' do
        Job.disable_job('TestJob', specific_args: [654])
        assert_equal(['[654]'], Stats.job_disabled_rules('TestJob').map(&:serialized_arguments))
        Job.disable_job('TestJob', specific_args: [65])
        assert_equal(%w([654] [65]).sort, Stats.job_disabled_rules('TestJob').map(&:serialized_arguments).sort)
        Job.enable_job('TestJob', specific_args: [654])
        assert_equal(['[65]'], Stats.job_disabled_rules('TestJob').map(&:serialized_arguments))
      end
    end

    describe '#disabled_stats' do
      it 'should work' do
        matched_job = 'SimpleJob'
        Job.disable_job('TestJob', specific_args: [])
        Job.disable_job('TestJob', specific_args: [654])
        Job.disable_job(matched_job, specific_args: { a: 4 })
        stats = Stats.disabled_stats
        assert_equal(3, stats.size)
        assert_kind_of(Rule, stats.first)
        assert_equal([0, 0, 0], stats.map(&:count))
        # This should increment the rule counter
        Job.disabled?(matched_job, [{ a: 4 }])
        assert_equal(1, Stats.disabled_stats.select { |r| r.job_name == matched_job }.first.count)
      end
    end
  end
end
