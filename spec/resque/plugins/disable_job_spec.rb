# frozen_string_literal: true

require_relative '../../spec_helper'

describe Resque::Plugins::DisableJob do
  before do
    ::Resque.redis.namespace = 'random:namespace'
    RedisDbTruncater.flush
  end

  class TestJob
    extend Resque::Plugins::DisableJob
    @queue = :test

    def self.perform(some_id, other_id)
    end
  end

  describe 'integration' do
    it 'should install the before_perform hook' do
      Resque::Plugin.before_hooks(TestJob).must_equal ['before_perform_allow_disable_job']
    end

    it 'should work by default' do
      worker = Resque::Worker.new(:test)
      Resque.enqueue(TestJob, 654, 5)
      TestJob.expects(:perform).with(654, 5).once

      perform_next_job(worker)
    end

    it 'should block the execution' do
      worker = Resque::Worker.new(:test)
      Resque::Plugins::DisableJob::Job.disable_job(TestJob.name, specific_args: [654])
      Resque.enqueue(TestJob, 654, 5)
      TestJob.expects(:perform).with(654, 5).never

      perform_next_job(worker)
    end

    it 'should work with jobs with no arguments' do
      p 'should work with jobs with no arguments'
      worker = Resque::Worker.new(:test)
      Resque::Plugins::DisableJob::Job.disable_job(TestJob.name, specific_args: [])
      Resque.enqueue(TestJob)
      TestJob.expects(:perform).never

      perform_next_job(worker)
    end

    it 'should re-enable correctly the job' do
      Resque.redis.keys.must_be_empty
      worker = Resque::Worker.new(:test)
      Resque::Plugins::DisableJob::Job.disable_job(TestJob.name, specific_args: [654])
      Resque.enqueue(TestJob, 654, 5)
      perform_next_job(worker)

      Resque::Plugins::DisableJob::Job.enable_job('TestJob', specific_args: [654])
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
      Resque.enqueue(TestJob, 654, 5)
      TestJob.expects(:perform).with(654, 5).once
      perform_next_job(worker)
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
    end
  end
end
