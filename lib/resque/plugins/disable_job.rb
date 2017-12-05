# frozen_string_literal: true

require 'resque/plugins/disable_job/job'
require 'resque/plugins/disable_job/rule'

module Resque
  module Plugins
    # DisableJob
    #
    # This class handles the main logic of the DisableJob plugin.
    # We can configure a job to be allowed to be disabled, set a job to be disabled or enable a job, and
    # we can see the status of the currently disabled jobs.
    module DisableJob
      MAX_JOB_RULES = 10
      DEFAULT_TIMEOUT = 3600 # seconds

      def before_perform_allow_disable_job(*args)
        if Job.disabled?(name, args)
          disable_job_handler("Skipped running job #{name}(#{args})", args)
        end
      end

      # Override this if you want custom processing
      def disable_job_handler(message, *_args)
        raise Resque::Job::DontPerform, message
      end

      def disable(specific_args = [], timeout = DEFAULT_TIMEOUT)
        Job.disable_job(name, specific_args: specific_args, timeout: timeout)
      end

      def enable(specific_args = [])
        Job.enable_job(name, specific_args: specific_args)
      end

      def enable_all
        Job.enable_all(name)
      end
    end
  end
end
