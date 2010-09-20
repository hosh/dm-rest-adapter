class NonStandardResource
  include DataMapper::Resource

  storage_names[:default] = 'resources'

  property :id,         Serial
  property :name,       String

  def self.element_name(repository)
    storage_name(repository).singularize
  end
end
