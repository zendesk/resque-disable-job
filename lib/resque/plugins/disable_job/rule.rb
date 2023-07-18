# frozen_string_literal: true

require 'digest/sha1'
require 'json'

module Resque
  module Plugins
    module DisableJob
      # Rule
      #
      # This class handles the references (aka redis key names) and some logic to interact
      # with the DisableJob rules data structures
      #
      # We use a few Redis structures:
      # * `main_set` - is Redis Set where we store all the jobs that are disabled at one time
      # * `all_rules_key` - is the Redis Hash that stores all the arguments we disable for one job
      # * `rule_key` - a Redis Counter that stores how many times we disabled that job with the specific parameters
      #                 This key has a TTL equal with the timeout set, so if it's gone we won't disable the job
      # * `serialized_arguments` - the job's specified arguments in JSON format
      # * `arguments` - the job's specified arguments
      # * `digest` - the job's specified arguments as a digest; used to identify the job rules in the key
      class Rule
        JOBS_SET = 'disabled_jobs'
        attr_reader :job_name
        attr_accessor :count

        def initialize(job_name, arguments = [], digest = '')
          @job_name = job_name
          if arguments.is_a?(Enumerable)
            @arguments = arguments
          else
            @serialized_args = arguments
          end
          @rule_digest = digest unless digest.empty?
        end

        def main_set
          JOBS_SET
        end

        def all_rules_key
          @all_rules_key ||= "#{main_set}:#{@job_name}"
        end

        def rule_key
          @rule_key ||= "#{all_rules_key}:#{digest}"
        end

        def serialized_arguments
          @serialized_args ||= @arguments.to_json # rubocop:disable Naming/MemoizedInstanceVariableName
        end

        def arguments
          @arguments ||= JSON.parse(@serialized_args)
        end

        def digest
          @rule_digest ||= Digest::SHA1.hexdigest(serialized_arguments) # rubocop:disable Naming/MemoizedInstanceVariableName
        end

        def match?(args)
          job_args = normalize_job_args(args)
          return true if job_args == arguments

          # We check each parameter in the job_args with the rule arguments to be blocked
          # if it's nil, then we match as we handle the 'any' case,
          # if it's specified, we check for equality (65 == 65)
          should_block = if arguments.is_a?(Hash)
            job_args.map { |k, v| match_or_nil(k, v) }
          else
            job_args.map.with_index { |a, i| match_or_nil(i, a) }
          end
          # `!should_block.empty?` handles the edge case of a job with no parameters and the rule args have parameters
          !should_block.empty? && !should_block.include?(false)
        end

        protected

        def normalize_job_args(job_args)
          # If the rule arguments is a hash we try to extract the job arguments as a hash to compare apples with apples
          if arguments.is_a?(Hash)
            job_args.size == 1 && job_args.first.is_a?(Hash) ? job_args.first : job_args
          else
            job_args
          end
        end

        def match_or_nil(key, value)
          arguments[key].nil? || value == arguments[key]
        end
      end
    end
  end
end
