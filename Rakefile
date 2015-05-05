require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'


namespace :style do
  # Style tests - Rubocop
  desc 'Run Ruby style checks'
  RuboCop::RakeTask.new(:ruby)
end

namespace :unit do
  desc 'Run ChefSpec unit tests'
  RSpec::Core::RakeTask.new(:spec) do |t, args|
    t.rspec_opts = 'test'
  end
end

task default: ['unit:spec', 'style:ruby']
