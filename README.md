# Resque::Disable::Job

This is a Resque plugin that allows us to disable jobs from being processed, by using the job class name and arguments.
It uses some Redis data structures to keep a record of what jobs need to be disabled and how many jobs were disabled for that setting.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resque-disable-job'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-disable-job

## Usage

### Job
You can add it to your job like any other Resque plugin:

```ruby
  class TestJob
    extend Resque::Plugins::DisableJob
    @queue = :test

    def self.perform(some_id, other_id)
    end
  end
```
The plugin will add the `before_perform_allow_disable_job` Resque hook. This will check if the current job needs to be stopped and it calls the `disable_job_handler` method.
By default this will just raise `Resque::Job::DontPerform`. If you want to do more you can override it in your job or base class.

### Disabling a Job

In your application's console you can use the `Resque::Plugins::DisableJob.disable_job` method to disable a job.

`Resque::Plugins::DisableJob.disable_job(job_name, matching_arguments, ttl)`

```ruby
# Disable all the jobs of that class:
Resque::Plugins::DisableJob.disable_job(TestJob.name)
# Disable all TestJob jobs with the first argument `65` 
Resque::Plugins::DisableJob.disable_job(TestJob.name, [65])
# Disable all SampleJob jobs that have the argument a == 5
Resque::Plugins::DisableJob.disable_job(SampleJob.name, {a: 5})

# Disable a job for one hour
Resque::Plugins::DisableJob.disable_job(SampleJob.name, {a: 1}, 3600)

# Re-enable jobs:
Resque::Plugins::DisableJob.enable_job(TestJob.name)
Resque::Plugins::DisableJob.enable_job(TestJob.name, [65])
```

**Note**: You can disable many arguments for one job type, but for performance reasons we look at only 10 settings.

### Operations

`Resque::Plugins::DisableJob` comes with a a few methods that will help you keep track of actively disabled jobs and how many times the setting was matched.

* `all_disabled_jobs` - returns a hash of all the disabled jobs and their settings 
* `job_disabled_settings(job_name)` - returns a hash of all the settings for one particular job 
* `get_disabled_stats` - returns an array of all the disabled jobs, their settings, and the counter of how many times it was matched 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zendesk/resque-disable-job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Resque::Disable::Job project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/zendesk/resque-disable-job/blob/master/CODE_OF_CONDUCT.md).

## Copyright and license

Copyright 2017 Zendesk, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
