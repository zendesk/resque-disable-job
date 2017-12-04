# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/disable_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'resque-disable-job'
  spec.version       = Resque::DisableJob::VERSION
  spec.authors       = ['Andrei Balcanasu']
  spec.email         = ['abalcanasu@zendesk.com']

  spec.summary       = 'Resque plugin that can disable jobs from being processed.'
  spec.description   = 'This is a Resque plugin that allows us to disable jobs from being processed, by using the job class name and arguments.
It uses some Redis data structures to keep a record of what jobs need to be disabled and how many jobs were disabled for that rule.'
  spec.homepage      = 'https://github.com/zendesk/resque-disable-job'
  spec.license       = 'Apache License 2.0'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'resque', '~> 1.25'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-rg'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '0.51.0'
  spec.add_development_dependency 'simplecov'
end
