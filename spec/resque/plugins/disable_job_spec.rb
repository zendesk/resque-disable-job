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
      Resque.enqueue(TestJob,654, 5)
      TestJob.expects(:perform).with(654, 5).once

      perform_next_job(worker)
    end

    it 'should block the execution' do
      worker = Resque::Worker.new(:test)
      Resque::Plugins::DisableJob.disable_job(TestJob.name, [654])
      Resque.enqueue(TestJob,654, 5)
      TestJob.expects(:perform).with(654, 5).never

      perform_next_job(worker)
    end

    it 'should re-enable correctly the job' do
      Resque.redis.keys.must_be_empty
      worker = Resque::Worker.new(:test)
      Resque::Plugins::DisableJob.disable_job(TestJob.name, [654])
      Resque.enqueue(TestJob,654, 5)
      perform_next_job(worker)

      Resque::Plugins::DisableJob.enable_job('TestJob', [654])
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
      Resque.enqueue(TestJob,654, 5)
      TestJob.expects(:perform).with(654, 5).once
      perform_next_job(worker)
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
    end
  end

  describe '#is_disabled?' do
    before do
      @job = SimpleJob.new()
    end

    class SimpleJob
      include Resque::Plugins::DisableJob
    end

    it 'should work' do
      Resque::Plugins::DisableJob.disable_job('TestJob', [654])
      specific_setting = Resque::Plugins::DisableJob::Settings.new('TestJob', [654])
      Resque.redis.expects(:incr).with(specific_setting.setting_key).once
      @job.is_disabled?('TestJob', [654]).must_equal true
      @job.is_disabled?('TestJob', []).must_equal false
    end

    it 'should return false if there is a args type mismatch' do
      Resque.redis.keys.must_be_empty
      Resque::Plugins::DisableJob.disable_job('SimpleJob', [654])
      @job.is_disabled?('SimpleJob', {a: 654}).must_equal false
      Resque::Plugins::DisableJob.disable_job('SimpleJob2', {a:654})
      @job.is_disabled?('SimpleJob2', [654]).must_equal false
    end

    it 'should return false if the setting is expired' do
      Resque::Plugins::DisableJob.disable_job('TestJob', [654])
      @job.is_disabled?('TestJob', [654]).must_equal true
      setting = Resque::Plugins::DisableJob::Settings.new('TestJob', [654])
      Resque.redis.expire(setting.setting_key, -1)
      @job.expects(:remove_specific_setting).once
      @job.is_disabled?('TestJob', [654]).must_equal false
    end

    it 'should return false if there is and error with the JSON parsing' do
      Resque::Plugins::DisableJob.disable_job('TestJob', [654])
      @job.is_disabled?('TestJob', [654]).must_equal true
      JSON.expects(:parse).raises(StandardError).once
      @job.is_disabled?('TestJob', [654]).must_equal false
    end
  end

  describe '#disable_job' do
    it 'should save data in Redis' do
      Resque.redis.keys.must_be_empty
      Resque::Plugins::DisableJob.disable_job("TestJob", [654])
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').size.must_equal 3
    end
  end

  describe '#args_match' do
    class SimpleJob
      include Resque::Plugins::DisableJob
    end

    before do
      @job = SimpleJob.new()
    end

    [
      # job args     ,    set args,        should match?
      [[20,134,[134]],    [],               true ],
      [[20,134,[134]],    [20],             true ],
      [[20,134,[134]],    [20,134],         true ],
      [[20,134,{a:1}],    [20,134,{a:1}],   true ],
      [[20,134,[134]],    [20,13],          false],
      [[20,134,[134,4]],  [21],             false],
      [[20,134,[134,4]],  [21,134,5],       false],
      [[20,134,{a:1}],    [21,134,{a:2}],   false],
      [[20,134,{a:1}],    [21,134,{a:1}],   false],
      [[20,134,{a:1}],    [21,134,{a:1},9], false],
      [[20,134,[134,4]],  [134],            false],
      # [[20],              [20,134],         false], TODO fix this case, or should we?
      # Hash parameters
      [{a:20,b:134},      {},               true ],
      [{a:20,b:134},      {a:20},           true ],
      [{a:20,b:134},      {b:134},          true ],
      [{a:20,b:134},      {b:134,a:20},     true ]
    ].each do |args, set_args, match|
      it "#{match ? "should" : "shouldn't"} match #{set_args} set with received #{args}" do
        @job.args_match(args, set_args).must_equal match
      end
    end
  end

  describe 'operations' do
    describe '#all_disabled_jobs' do
      it 'should work' do
        Resque::Plugins::DisableJob.disable_job('TestJob', [654])
        Resque::Plugins::DisableJob.all_disabled_jobs.keys.must_equal ['TestJob']
        Resque::Plugins::DisableJob.disable_job('TestJob2', [654])
        Resque::Plugins::DisableJob.all_disabled_jobs.keys.sort.must_equal ['TestJob', 'TestJob2'].sort
      end
    end

    describe '#job_disabled_settings' do
      it 'should work' do
        Resque::Plugins::DisableJob.disable_job('TestJob', [654])
        Resque::Plugins::DisableJob.job_disabled_settings('TestJob').values.must_equal ['[654]']
        Resque::Plugins::DisableJob.disable_job('TestJob', [65])
        Resque::Plugins::DisableJob.job_disabled_settings('TestJob').values.must_equal %w([654] [65])
        Resque::Plugins::DisableJob.enable_job('TestJob', [654])
        Resque::Plugins::DisableJob.job_disabled_settings('TestJob').values.must_equal ['[65]']
      end
    end

    describe '#get_disabled_stats' do
      it 'should work' do
        Resque::Plugins::DisableJob.disable_job('TestJob', [])
        Resque::Plugins::DisableJob.disable_job('TestJob', [654])
        Resque::Plugins::DisableJob.disable_job('SimpleJob', {a: 4})
        Resque::Plugins::DisableJob.get_disabled_stats.size.must_equal 3

      end
    end
  end
end
