# frozen_string_literal: true

module Resque
  module Plugins
    module DisableJob
      # Stats
      # These are methods that inspect the settings
      class Stats
        def self.all_disabled_jobs
          Hash[Resque.redis.smembers(Settings::SETTINGS_SET).map { |name| [name, job_disabled_settings(name)] }]
        end

        def self.job_disabled_settings(name)
          Resque.redis.hgetall(Settings.new(name).all_key)
        end

        def self.disabled_stats
          counts = all_disabled_jobs.map do |name, settings|
            settings.map do |d, a|
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
      end
    end
  end
end
