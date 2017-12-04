# frozen_string_literal: true

require_relative 'rule'

module Resque
  module Plugins
    module DisableJob
      # Stats
      # These are methods that inspect the rules
      class Stats
        def self.all_disabled_jobs
          Hash[Resque.redis.smembers(Rule::RULES_SET).map { |name| [name, job_disabled_rules(name)] }]
        end

        def self.job_disabled_rules(name)
          Resque.redis.hgetall(Rule.new(name).all_rules_key)
        end

        def self.disabled_stats
          counts = all_disabled_jobs.map do |name, rules|
            rules.map do |digest, arguments|
              {
                job_name: name,
                digest: digest,
                arguments: arguments,
                count: Resque.redis.get(Rule.new(name, arguments, digest).rule_key)
              }
            end
          end
          counts.flatten
        end
      end
    end
  end
end
