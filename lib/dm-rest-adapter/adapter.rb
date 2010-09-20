require 'active_support/core_ext/hash/keys'

class DataMapper::Property
  def to_sym
    self.name
  end
end

module DataMapperRest
  class Adapter < DataMapper::Adapters::AbstractAdapter
    # TODO: Refactor better
    JSON_PARSER = proc do |body, model, element_name|
      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      raw_record = Yajl::Parser.parse(body)

      return nil unless raw_record.kind_of?(Hash)

      record = {}
      raise "Unable to find element name: #{raw_record.inspect}" unless raw_record[element_name]
      raw_record[element_name].each do |field, value|
        # TODO: push this to the per-property mix-in for this adapter
        next unless property = field_to_property[field]
        record[field] = property.typecast(value)
      end
      record
    end

    MULTI_JSON_PARSER = proc do |body, model, element_name|
      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      raw_records = Yajl::Parser.parse(body)

      records = []
      return records unless raw_records && raw_records.any?

      raw_records.each do |raw_record|
        record = {}
        next unless raw_record[element_name]
        raw_record[element_name].each do |field, value|
          # TODO: push this to the per-property mix-in for this adapter
          next unless property = field_to_property[field]
          record[field] = property.typecast(value)
        end
        records << record
      end
      records
    end

    def create(resources)
      resources.each do |resource|
        model = resource.model

        response = connection.http_post(collection_path(model), :payload => { element_name(model) => resource.attributes }.to_json)

        update_with_response(resource, response)
      end
    end

    def read(query)
      model = query.model

      records = if id = extract_id_from_query(query)
        response = connection.http_get(resource_path(model, id))
        [ JSON_PARSER.call(response.body, model, element_name(model)) ]
      else
        id, params = extract_params_from_query(query)
        response = connection.http_get(collection_path(model, id), :params => params)
        MULTI_JSON_PARSER.call(response.body, model, element_name(model))
      end

      query.filter_records(records)
    end

    def update(dirty_attributes, collection)
      updated_attributes = dirty_attributes.symbolize_keys
      collection.select do |resource|
        model = resource.model
        key   = model.key
        id    = key.get(resource)

        response = connection.http_put(resource_path(model, id), :payload => { element_name(model) => updated_attributes }.to_json)
        dirty_attributes.each { |p, v| p.set!(resource, v) }

        update_with_response(resource, response)
      end.size
    end

    def delete(collection)
      collection.select do |resource|
        model = resource.model
        key   = model.key
        id    = key.get(resource)

        response = connection.http_delete(resource_path(model, id))
        response.success?
      end.size
    end

    private

    def collection_path(model, key = [] )
      if key.is_a?(Array)
        resource_name(model).zip(key).join('/')
      else
        resource_name(model).join('/')
      end
    end

    def resource_path(model, key)
      resource_name(model).zip(key).join('/')
    end

    def format
      @format = @options.fetch(:format, 'json')
    end

    def connection
      @connection ||= DataMapperRest::Connection.new(:site_uri => site_uri, :format => format)
    end

    def connection_options
      @options
    end

    def site_uri
      @site_uri ||= if @options[:site_uri]
                      Addressable::URI.parse(@options[:site_uri]).freeze
                    else
                      Addressable::URI.new(
                        :scheme       => (ssl? ? 'https' : 'http'),
                        :user         => @options[:user],
                        :password     => @options[:password],
                        :host         => @options[:host],
                        :port         => @options[:port],
                        :path         => @options[:path],
                        :fragment     => @options[:fragment]
                      ).freeze
                    end
    end

    def ssl?
      @ssl ||= @options.fetch(:ssl, false)
    end

    # Here, the primary key may be more than one, depending on what we have
    # in storage_name.
    # Normally:
    #   storage_name(:default) # returns => 'resource'
    #
    # But if we want to declare a nested resource:
    #   storage_name(:default) # returns => [ 'parent_resource', 'resource' ]
    #
    # Naturally, composite primary key will have to match up.
    #
    # TODO: REFACTOR
    # This and extract_param_from_query needs to be refactored in light of composite keys
    # I mean, shouldn't this just return all keys from the query? And if so, we cannot
    # really depend on this returning nil to know whether we should parse out the returned
    # resource as an array of resources or not. That ties in with finishing the refactoring
    # with multiple formats. There needs to be both a parsing phase, and a phase that
    # actually walks the tree and maps values to model instances.
    def extract_id_from_query(query)
      return nil unless query.limit == 1

      conditions = query.conditions

      # TODO: Refactor
      _resource_name = resource_name(query.model)

      return nil unless conditions.kind_of?(DataMapper::Query::Conditions::AndOperation)
      return nil unless (key_condition = conditions.select { |o| o.subject.key? }).size == _resource_name.size

      if _resource_name.size == 1
        [ key_condition.first.value ]
      else
        key_condition[0..(_resource_name.size - 1)].map(&:value)
      end
    end

    # TODO: This should be consolidated with extract_id_from_query and refactored carefully
    def extract_params_from_query(query)
      conditions = query.conditions

      return nil unless conditions.kind_of?(DataMapper::Query::Conditions::AndOperation)
      
      _resource_name = resource_name(query.model)
      
      # TODO: Can this be improved?
      condition_keys = conditions.operands.classify { |o| (o.subject.key? ? :keys : :params ) }

      params = {}
      (condition_keys[:params] || []).each do |c|
        params[c.subject.name] = c.value
      end

      return (condition_keys[:keys] || []).map(&:value), params
    end

    def resource_name(model)
      _name = model.storage_name(self.name)
      return [ _name ] unless _name.is_a?(Array)
      return _name
    end

    def element_name(model)
      model.element_name(self.name)
    end


    def update_with_response(resource, response)
      return unless response.success? && !response.body.blank?

      model      = resource.model
      properties = model.properties(name)

      updated_attributes = JSON_PARSER.call(response.body, model, element_name(model))
      return if updated_attributes.blank?
      updated_attributes.each do |key, value|
        if property = properties[key.to_sym]
          property.set!(resource, value)
        end
      end
    end
  end
end
