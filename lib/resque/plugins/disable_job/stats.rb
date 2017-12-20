# frozen_string_literal: true

require_relative 'rule'

module Resque
  module Plugins
    module DisableJob
      # Stats
      # These are methods that inspect the rules
      class Stats
        def self.all_disabled_jobs
          Job.disabled_jobs.map { |name| job_disabled_rules(name) }.flatten
        end

        def self.job_disabled_rules(name)
          Resque.redis.hgetall(Rule.new(name).all_rules_key).each_with_object([]) do |(digest, arguments), rules|
            rules << Rule.new(name, arguments, digest)
          end
        end

        def self.disabled_stats
          all_disabled_jobs.map do |rule|
            rule.count = Resque.redis.get(rule.rule_key).to_i
            rule
          end
        end
      end
    end
  end
end
