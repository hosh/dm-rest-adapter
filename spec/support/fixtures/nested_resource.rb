class NestedResource
  include DataMapper::Resource

  storage_names[:default] = %w(parents resources)

  property :parent_id,  Integer, :key => true
  property :id,         Serial

  property :name,       String

  def self.element_name(repository)
    'nested_resource'
  end
end
