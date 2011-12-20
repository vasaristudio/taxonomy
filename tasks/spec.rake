ENV['BUNDLE_GEMFILE'] = File.dirname(__FILE__) + '/../Gemfile'

require 'rake'
require 'rake/testtask'
require 'rspec'
require 'rspec/core/rake_task'

desc "Run the test suite"
task :spec => ['spec:setup', 'spec:taxonomy', 'spec:cleanup']

namespace :spec do
  desc "Setup the test environment"
  task :setup do
  end
  
  desc "Cleanup the test environment"
  task :cleanup do
    File.delete(File.expand_path(File.dirname(__FILE__) + '/../spec/test.db'))
  end
  
  desc "Test taxonomy"
  RSpec::Core::RakeTask.new(:taxonomy) do |task|
    taxonomy_root = File.expand_path(File.dirname(__FILE__) + '/..')
    task.pattern = taxonomy_root + '/spec/lib/**/*_spec.rb'
  end
end
