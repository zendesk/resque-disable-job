# frozen_string_literal: true

require_relative '../../../spec_helper'

module Resque::Plugins::DisableJob
  describe Rule do
    describe '#initialize' do
      it 'should initialize with name and args' do
        name = 'TestJob'
        args = [765]
        rule = Rule.new(name, args)

        rule.main_set.must_equal Rule::JOBS_SET
        rule.job_name.must_equal name
        rule.arguments.must_equal args
        rule.all_rules_key.must_equal "#{rule.main_set}:#{name}"
        rule.rule_key.must_equal "#{rule.all_rules_key}:#{rule.digest}"
        rule.serialized_arguments.must_equal args.to_json
        rule.digest.must_equal Digest::SHA1.hexdigest(rule.serialized_arguments)
      end

      it 'should initialize with name and digest' do
        name = 'TestJob'
        args_data = [765].to_json
        digest = Digest::SHA1.hexdigest(args_data)
        rule = Rule.new(name, args_data, digest)

        rule.main_set.must_equal Rule::JOBS_SET
        rule.job_name.must_equal name
        rule.all_rules_key.must_equal "#{rule.main_set}:#{name}"
        rule.rule_key.must_equal "#{rule.all_rules_key}:#{digest}"
        rule.serialized_arguments.must_equal args_data
        rule.digest.must_equal digest
      end

      it 'should initialize with just a name' do
        name = 'TestJob'
        rule = Rule.new(name)

        rule.main_set.must_equal Rule::JOBS_SET
        rule.job_name.must_equal name
        rule.all_rules_key.must_equal "#{rule.main_set}:#{name}"
      end
    end

    describe '#match?' do
      [
        # job args,           set args,               should match?
        [[],                  [],                      true],
        [[{}],                [],                      true],
        [[{}],                {},                      true],
        [[],                  [654],                   false],
        [[20, 134, [134]],    [],                      true],
        [[20, 134, [134]],    [20],                    true],
        [[20, 134, [134]],    [20, 134],               true],
        [[20, 134, [134]],    [60, 134],               false],
        [[20, 134, { a: 1 }], [20, 134, { a: 1 }],     true],
        [[20, 134, [134]],    [20, 13],               false],
        [[20, 134, [134, 4]], [21],                   false],
        [[20, 134, [134, 4]], [21, 134, 5],           false],
        [[20, 134, { a: 1 }], [21, 134, { a: 2 }],    false],
        [[20, 134, { a: 1 }], [21, 134, { a: 1 }],    false],
        [[20, 134, { a: 1 }], [21, 134, { a: 1 }, 9], false],
        [[20, 134, [134, 4]], [134],                  false],
        # Hash parameters
        [[{ a: 20, b: 134 }],   {}, true],
        [[{ a: 4 }],            { a: 4 }, true],
        [[{ a: 20, b: 134 }],   { a: 20 },               true],
        [[{ a: 20, b: 134 }],   { a: 21 },               false],
        [[{ a: 20, b: 134 }],   { b: 134 },              true],
        [[{ a: 20, b: 134 }],   { b: 134, a: 20 },       true],
        # hash parameters with string keys
        [[{ 'key_1' => 1, 'key_2' => 4, 'time' => 3 }],   { 'key_1' => 1 }, true],
        [[{ 'key_1' => 1, 'key_2' => 4, 'time' => 3 }],   { 'key_1' => 2 }, false]
      ].each do |args, set_args, match|
        it "#{match ? 'should' : "shouldn't"} match #{set_args} set with received #{args}" do
          Rule.new('test', set_args).match?(args).must_equal match
        end
      end
    end
  end
end
