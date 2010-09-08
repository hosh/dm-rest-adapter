require 'rubygems'
require 'rake'

begin
  gem 'jeweler', '~> 1.4'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'dm-rest-adapter'
    gem.summary     = 'Typheous REST Adapter for DataMapper'
    gem.description = gem.summary
    gem.email       = 'hosh@sparkfly.com'
    gem.homepage    = 'http://github.com/datamapper/%s' % gem.name
    gem.authors     = [ 'Ho-Sheng Hsiao @ Sparkfly', 'Scott Burton @ Joyent Inc' ]

    gem.rubyforge_project = 'datamapper'

    gem.add_dependency 'dm-core',       '~> 1.0.0'
    gem.add_dependency 'activesupport', '~> 3.0.0'

    #gem.add_development_dependency 'rspec',          '>= 2.0.0.beta.20'
  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end
