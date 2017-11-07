require_relative '../../spec_helper'

describe Resque::Plugins::DisableJob do

  describe '#args_match' do
    class TestJob
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
        TestJob.new().args_match(args, set_args).must_equal match
      end
    end
  end
end
