require 'digest/sha1'
require 'json'

module Resque
  module Plugins
    module DisableJob
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
