require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new(:spec) do |test|
  test.pattern = 'spec/**/*_spec.rb'
  test.verbose = true
  test.warning = false
end

task :default => :spec