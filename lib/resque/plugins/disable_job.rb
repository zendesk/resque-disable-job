require 'resque/plugins/disable_job/settings'

module Resque
  module Plugins
    module DisableJob
      MAX_JOB_SETTINGS  = 10
      DEFAULT_TIMEOUT = 3600 # seconds

      def before_perform_allow_disable_job(*args)
        if is_disabled?(self.name, args)
          disable_job_handler("Skipped running job #{self.name}(#{args})", args)
        end
      end

      # Override this if you want custom processing
      def disable_job_handler(message, *args)
        raise Resque::Job::DontPerform.new(message)
      end

      def is_disabled?(name, args)
        settings = Settings.new(name)
        disabled_settings = ::Resque.redis.hgetall(settings.all_key)
        # We should limit this to 10 for performance reasons. Each check delays the job from being performed
        matched_setting = disabled_settings.take(MAX_JOB_SETTINGS).detect do |a|
          begin
            digest, set_args = a
            set_args_data = JSON.parse(set_args)
            specific_setting = Settings.new(name, set_args_data)
            Resque.logger.error "The DIGEST does not match" if specific_setting.digest != digest
            if !is_expired?(specific_setting)
              if (set_args_data.is_a?(Array) && args.is_a?(Array)) ||
                 (set_args_data.is_a?(Hash) && args.is_a?(Hash))
                args_match(args, set_args_data)
              else
                Resque.logger.error "TYPE MISMATCH while checking disable rule #{digest} (#{set_args}) for #{name}: \
                    args is a #{args.class} & set_args is a #{set_args_data.class}"
                false
              end
            else
              self.remove_specific_setting(specific_setting)
              false
            end
          rescue StandardError => e
            Resque.logger.error "Failed to parse AllowDisableJob settings for #{name}: #{set_args}. Error: #{e.message}"
            false
          end
        end

        if !matched_setting.nil?
          digest, args_data = matched_setting
          specific_setting = Settings.new(name, args_data, digest)
          Resque.redis.incr specific_setting.setting_key
          Resque.logger.info "Matched running job #{name}(#{args}) because it was disabled by #{matched_setting}"
          true
        else
          false
        end
      end

      def self.disable_job(name, specific_args = {}, timeout = DEFAULT_TIMEOUT)
        settings = Settings.new(name, specific_args)
        Resque.redis.multi do
          Resque.redis.sadd settings.main_set, settings.name
          Resque.redis.hset(settings.all_key, settings.digest, settings.data)
          Resque.redis.set(settings.setting_key, 0)
          Resque.redis.expire(settings.setting_key, timeout)
        end
      end

      def self.enable_job(name, specific_args = {})
        remove_specific_setting(Settings.new(name, specific_args))
      end

      def self.all_disabled_jobs
        Hash[Resque.redis.smembers(Settings::SETTINGS_SET).map{ |name| [name, job_disabled_settings(name)] }]
      end

      def self.job_disabled_settings(name)
        Resque.redis.hgetall(Settings.new(name).all_key)
      end

      def self.get_disabled_stats
        counts = all_disabled_jobs.map do |name, settings|
          settings.map do |d,a|
            {
              name: name,
              digest: d,
              args: a,
              count: Resque.redis.get(Settings.new(name, a, d).setting_key)
            }
          end
        end
        counts.flatten
      end

      # private

      def is_expired?(setting)
        Resque.redis.ttl(setting.setting_key) < 0
      end

      def self.remove_specific_setting(setting)
        Resque.redis.del(setting.setting_key)
        Resque.redis.hdel(setting.all_key, setting.digest)
        if Resque.redis.hlen(setting.all_key) == 0
          Resque.redis.srem(setting.main_set, setting.name)
        end
      end

      # To set the arguments to block we need to keep in mind the parameter order and that
      # if we don't specify anything, that means we are blocking everything.
      # The rule is from generic to specific.
      def args_match(args, set_args)
        should_block = args.to_a.map.with_index do |a,i|
          # We check each parameter (65) or parameters set (["account_id", 65]) in the args with the args to be blocked
          # if it's nil, then we match, if it's specified, we check for equality (65 == 65 or ["account_id", 65] == ["account_id", 65])
          set_args[i] == nil || a == set_args[i]
        end
        # if all params are matched [reduce(:&)]
        should_block.reduce(:&)
      end
    end
  end
end
