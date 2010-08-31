# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
require 'ap' # Debugging

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'dm-rest-adapter'

Rspec.configure do |config|
  config.mock_with :rspec
end
