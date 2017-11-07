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

      Resque::Plugins::DisableJob.enable_job("TestJob", [654])
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
      Resque.enqueue(TestJob,654, 5)
      TestJob.expects(:perform).with(654, 5).once
      perform_next_job(worker)
      Resque.redis.keys(Resque::Plugins::DisableJob::Settings::SETTINGS_SET + '*').must_be_empty
    end
  end

  describe '#disable_job' do
    it 'should save data in Redis' do
      Resque.redis.keys.must_be_empty
      Resque::Plugins::DisableJob.disable_job("TestJob", [654])
      Resque.redis.keys.size.must_equal 3
      # TODO Add more
    end
  end

  describe '#args_match' do
    class SimpleJob
      include Resque::Plugins::DisableJob
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
      # Hash parameters
      [{a:20,b:134},      {},               true ],
      [{a:20,b:134},      {a:20},           true ],
      [{a:20,b:134},      {b:134},          true ],
      [{a:20,b:134},      {b:134,a:20},     true ]
    ].each do |args, set_args, match|
      it "#{match ? "should" : "shouldn't"} match #{set_args} set with received #{args}" do
        SimpleJob.new().args_match(args, set_args).must_equal match
      end
    end
  end
end
