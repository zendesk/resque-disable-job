require_relative '../../../spec_helper'

describe Resque::Plugins::DisableJob::Job do
  before do
    ::Resque.redis.namespace = 'random:namespace'
    RedisDbTruncater.flush
  end

  describe '#all_disabled_jobs' do
    it 'should work' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Stats.all_disabled_jobs.keys.must_equal ['TestJob']
      Resque::Plugins::DisableJob::Job.disable_job('TestJob2', specific_args: [654])
      Resque::Plugins::DisableJob::Stats.all_disabled_jobs.keys.sort.must_equal %w[TestJob TestJob2].sort
    end
  end

  describe '#job_disabled_settings' do
    it 'should work' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Stats.job_disabled_settings('TestJob').values.must_equal ['[654]']
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [65])
      Resque::Plugins::DisableJob::Stats.job_disabled_settings('TestJob').values.must_equal %w([654] [65])
      Resque::Plugins::DisableJob::Job.enable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Stats.job_disabled_settings('TestJob').values.must_equal ['[65]']
    end
  end

  describe '#get_disabled_stats' do
    it 'should work' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [])
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Job.disable_job('SimpleJob', specific_args: { a: 4 })
      Resque::Plugins::DisableJob::Stats.disabled_stats.size.must_equal 3
    end
  end
end
