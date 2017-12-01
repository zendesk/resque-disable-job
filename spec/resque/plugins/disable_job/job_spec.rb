require_relative '../../../spec_helper'

describe Resque::Plugins::DisableJob::Job do
  before do
    ::Resque.redis.namespace = 'random:namespace'
    RedisDbTruncater.flush
  end

  describe '#is_disabled?' do
    before do
      @job = SimpleJob.new
    end

    class SimpleJob
      include Resque::Plugins::DisableJob
    end

    it 'should work' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      specific_setting = Resque::Plugins::DisableJob::Settings.new('TestJob', [654])
      Resque.redis.expects(:incr).with(specific_setting.setting_key).once
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', [654]).must_equal true
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', []).must_equal false
    end

    it 'should return false if there is a args type mismatch' do
      Resque.redis.keys.must_be_empty
      Resque::Plugins::DisableJob::Job.disable_job('SimpleJob', specific_args: [654])
      Resque::Plugins::DisableJob::Job.disabled?('SimpleJob', { a: 654 }).must_equal false
      Resque::Plugins::DisableJob::Job.disable_job('SimpleJob2', specific_args: { a: 654 })
      Resque::Plugins::DisableJob::Job.disabled?('SimpleJob2', [654]).must_equal false
    end

    it 'should return false if the setting is expired' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', [654]).must_equal true
      setting = Resque::Plugins::DisableJob::Settings.new('TestJob', [654])
      Resque.redis.expire(setting.setting_key, -1)
      Resque::Plugins::DisableJob::Job.expects(:remove_specific_setting).once
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', [654]).must_equal false
    end

    it 'should return false if there is and error with the JSON parsing' do
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', [654]).must_equal true
      JSON.expects(:parse).raises(StandardError).once
      Resque::Plugins::DisableJob::Job.disabled?('TestJob', [654]).must_equal false
    end
  end

  describe '#disable_job' do
    it 'should save data in Redis' do
      Resque.redis.keys.must_be_empty
      Resque::Plugins::DisableJob::Job.disable_job('TestJob', specific_args: [654])
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').size.must_equal 3
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
        Resque::Plugins::DisableJob::Job.args_match(args, set_args).must_equal match
      end
    end
  end
end
