require 'rspec/core'
require 'rspec/core/rake_task'

Rake.application.instance_variable_get('@tasks').delete('default')

task :default => :spec

desc "Run all specs in spec directory (excluding plugin specs)"
Rspec::Core::RakeTask.new(:spec)
