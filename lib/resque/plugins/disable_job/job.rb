# frozen_string_literal: true

require_relative 'rule'

module Resque
  module Plugins
    module DisableJob
      # The Job class contains the logic that determines if the current job is disabled,
      # and methods to disable and enable a specific job.
      class Job
        # disabled? checks if the job and it's arguments is disabled
        def self.disabled?(job_name, job_args)
          # We get all the rules for the current job
          rules = get_all_rules(job_name)
          # We limit this to 10 rules for performance reasons. Each check delays the job from being performed
          matched_rule = match_rules(job_name, job_args, rules)

          if !matched_rule.nil?
            # if we found a matched rule, we record this and return true
            record_matched_rule(job_name, job_args, matched_rule)
            true
          else
            false
          end
        end

        def self.match_rules(job_name, job_args, rules)
          rules.take(MAX_JOB_RULES).detect do |specific_rule|
            begin
              # if the rule is not expired
              if !expired?(specific_rule)
                # if the arguments received and the ones from the rule match, that means that we need to disable the current job
                specific_rule.match?(job_args)
              else
                # we remove the rule if it's expired
                remove_specific_rule(specific_rule)
                false
              end
            rescue StandardError => e
              Resque.logger.error "Failed to parse AllowDisableJob rules for #{job_name}: #{specific_rule.serialized_arguments}. Error: #{e.message}"
              false
            end
          end
        end

        # The rule is expired if the TTL of the rule key is -1.
        def self.expired?(rule)
          Resque.redis.ttl(rule.rule_key) < 0 # .negative? only works in Ruby 2.3 and above
        end

        # To disable a job we need to add it in 3 data structures:
        # - we need to add the job name to the main set so we know what jobs have rules
        # - we add the arguments to the job's rule hash
        # - we create a counter for the individual rule that will keep track of how many times it was matched
        def self.disable_job(name, specific_args: {}, timeout: DEFAULT_TIMEOUT)
          rule = Rule.new(name, specific_args)
          Resque.redis.multi do
            Resque.redis.sadd rule.main_set, rule.job_name
            Resque.redis.hset(rule.all_rules_key, rule.digest, rule.serialized_arguments)
            Resque.redis.set(rule.rule_key, 0)
            Resque.redis.expire(rule.rule_key, timeout)
          end
        end

        # To enable a job, we just need to remove it
        def self.enable_job(name, specific_args: {})
          remove_specific_rule(Rule.new(name, specific_args))
        end

        def self.enable_all(job_name)
          get_all_rules(job_name).map { |r| remove_specific_rule(r) }
        end

        def self.enable_all!
          disabled_jobs.map { |job_name| enable_all(job_name) }
        end

        def self.disabled_jobs
          Resque.redis.smembers(Rule::JOBS_SET)
        end

        # To remove a job we need to delete its counter, the entry from the rules hash and
        # if the job has no more rules, we can remove the job's entry in the main set
        def self.remove_specific_rule(rule)
          Resque.redis.del(rule.rule_key)
          Resque.redis.hdel(rule.all_rules_key, rule.digest)
          if Resque.redis.hlen(rule.all_rules_key).zero?
            Resque.redis.srem(rule.main_set, rule.job_name)
          end
        end

        # Support functions for disabled?

        def self.get_specific_rule(job_name, set_args, digest)
          rule = Rule.new(job_name, set_args)
          Resque.logger.error 'The DIGEST does not match' if rule.digest != digest
          rule
        end

        def self.get_all_rules(job_name)
          Resque.redis.hgetall(Rule.new(job_name).all_rules_key).map do |digest, set_args|
            get_specific_rule(job_name, set_args, digest)
          end
        end

        def self.record_matched_rule(job_name, job_args, rule)
          Resque.redis.incr rule.rule_key
          Resque.logger.info "Matched running job #{job_name}(#{job_args}) because it was disabled by #{rule}"
        end

        private_class_method :record_matched_rule, :get_all_rules, :get_specific_rule
      end
    end
  end
end
