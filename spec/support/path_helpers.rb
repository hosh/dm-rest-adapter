# Drop this into spec/support
# Load gem path the way Bundler / Rubygems will load
def load_lib_path
  project_path = File.join(File.dirname(__FILE__), '..', '..', 'lib')
  return nil if $LOAD_PATH.include?(File.expand_path(project_path))
  $LOAD_PATH.unshift(File.expand_path(project_path))
end
