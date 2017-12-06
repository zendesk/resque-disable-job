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
        rule.all_rules_key.must_equal rule.main_set + ':' + name
        rule.rule_key.must_equal rule.all_rules_key + ':' + rule.digest
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
        rule.all_rules_key.must_equal rule.main_set + ':' + name
        rule.rule_key.must_equal rule.all_rules_key + ':' + digest
        rule.serialized_arguments.must_equal args_data
        rule.digest.must_equal digest
      end

      it 'should initialize with just a name' do
        name = 'TestJob'
        rule = Rule.new(name)

        rule.main_set.must_equal Rule::JOBS_SET
        rule.job_name.must_equal name
        rule.all_rules_key.must_equal rule.main_set + ':' + name
      end
    end
  end
end
