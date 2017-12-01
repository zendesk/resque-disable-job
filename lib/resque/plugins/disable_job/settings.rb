# frozen_string_literal: true

require 'digest/sha1'
require 'json'

module Resque
  module Plugins
    module DisableJob
      # Settings
      #
      # This class handles the references (aka redis key names) and some logic to interact
      # with the DisableJob settings data structures
      #
      # We use a few Redis structures:
      # * `main_set` - is Redis Set where we store all the jobs that are disabled at one time
      # * `all_key` - is the Redis Hash that stores all the arguments we disable for one job
      # * `setting_key` - a Redis Counter that stores how many times we disabled that job with the specific parameters
      #                 This key has a TTL equal with the timeout set, so if it's gone we won't disable the job
      # * `data` - the job's specified arguments in JSON format
      # * `digest` - the job's specified arguments as a digest. used to identify the job settings in the key
      class Settings
        SETTINGS_SET = 'disabled_jobs'
        attr_reader :name, :args

        def initialize(name, args = [], digest = '')
          @name = name
          if args.is_a?(Enumerable)
            @args = args
          else
            @args_data = args
          end
          @setting_digest = digest unless digest.empty?
        end

        def main_set
          SETTINGS_SET
        end

        def all_key
          @all_settings_key ||= main_set + ':' + @name
        end

        def setting_key
          @setting_key ||= all_key + ':' + digest
        end

        def data
          @args_data ||= @args.to_json
        end

        def digest
          @setting_digest ||= Digest::SHA1.hexdigest(data)
        end
      end
    end
  end
end
