class NonStandardResource
  include DataMapper::Resource

  storage_names[:default] = 'resources'

  property :id,         Serial
  property :name,       String
end
