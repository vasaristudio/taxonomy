ENV['BUNDLE_GEMFILE'] = File.dirname(__FILE__) + '/../Gemfile'

require 'rake'
require 'rake/testtask'
require 'rspec'
require 'rspec/core/rake_task'

desc "Run the test suite"
task :spec => ['spec:setup', 'spec:generators', 'spec:taxonomy', 'spec:models', 'spec:cleanup']

namespace :spec do
  desc "Setup the test environment"
  task :setup do
    rails_path = File.expand_path(File.dirname(__FILE__) + '/../spec/dummy')
    system "cd #{rails_path} && RAILS_ENV=test bundle exec rake db:schema:load"
  end

  desc "Test taxonomy legacy"
  RSpec::Core::RakeTask.new(:taxonomy) do |task|
    taxonomy_root = File.expand_path(File.dirname(__FILE__) + '/..')
    task.pattern = taxonomy_root + '/spec/taxonomy/**/*_spec.rb'
  end
  
  desc "Test taxonomy"
  RSpec::Core::RakeTask.new(:models) do |task|
    taxonomy_root = File.expand_path(File.dirname(__FILE__) + '/..')
    task.pattern = taxonomy_root + '/spec/models/**/*_spec.rb'
  end
  
  desc "Test taxonomy migration generation"
  RSpec::Core::RakeTask.new(:generators) do |task|
    taxonomy_root = File.expand_path(File.dirname(__FILE__) + '/..')
    task.pattern = taxonomy_root + '/spec/generators/**/*_spec.rb'
  end

  desc "Cleanup the test environment"
  task :cleanup do
    File.delete(File.expand_path(File.dirname(__FILE__) + '/../spec/dummy/db/test.sqlite3'))
  end

end
