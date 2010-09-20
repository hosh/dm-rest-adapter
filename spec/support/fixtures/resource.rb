class Resource
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String

  def self.element_name(repository)
    storage_name(repository).singularize
  end
end
