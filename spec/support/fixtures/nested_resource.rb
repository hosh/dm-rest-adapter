class NestedResource
  include DataMapper::Resource

  property :parent_id,  Integer, :key => true
  property :id,         Serial

  property :name,       String

  # Using composite storage name + composite primary key to express the notion of a nested resource
  class_inheritable_accessor :_resource_name
  self._resource_name = %w(parents resources)

  def self.storage_name(repository)
    self._resource_name
  end

  def self.storage_names
    { :default => self._resource_name }
  end
end
