# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

# Pushing to rubygems is handled by a github workflow
ENV['gem_push'] = 'false'

RuboCop::RakeTask.new

Rake::TestTask.new(:spec) do |test|
  test.pattern = 'spec/**/*_spec.rb'
  test.verbose = true
  test.warning = false
end

task default: %i[spec rubocop]
