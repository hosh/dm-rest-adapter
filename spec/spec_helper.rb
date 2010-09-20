# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
require 'ap' # Debugging

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
require 'dm-core'
require 'rspec/core'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'dm-rest-adapter'

Rspec.configure do |config|
  config.mock_with :rspec
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end

