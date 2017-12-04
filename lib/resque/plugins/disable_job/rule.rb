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
        RULES_SET = 'disabled_jobs'
        attr_reader :job_name

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
          RULES_SET
        end

        def all_rules_key
          @all_rules_key ||= main_set + ':' + @job_name
        end

        def rule_key
          @rule_key ||= all_rules_key + ':' + digest
        end

        def serialized_arguments
          @serialized_args ||= @arguments.to_json
        end

        def arguments
          @arguments ||= JSON.parse(@serialized_args)
        end

        def digest
          @rule_digest ||= Digest::SHA1.hexdigest(serialized_arguments)
        end
      end
    end
  end
end
