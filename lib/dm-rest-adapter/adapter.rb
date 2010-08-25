module DataMapperRest
  class Adapter < DataMapper::Adapters::AbstractAdapter
    # TODO: Refactor better
    JSON_PARSER = proc do |body, model|
      element_name = model.storage_name(self.name).singularize
      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      raw_record = Yajl::Parser.parse(body)

      record = {}
      raw_record[element_name].each do |field, value|
        # TODO: push this to the per-property mix-in for this adapter
        next unless property = field_to_property[field]
        record[field] = property.typecast(value)
      end
      record
    end

    MULTI_JSON_PARSER = proc do |body, model|
      element_name = model.storage_name(self.name).singularize
      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      raw_record = Yajl::Parser.parse(body)

      records = []
      raw_records.each do |raw_record|
        record = {}
        raw_record.each do |field, value|
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

        response = connection.http_post("#{resource_name(model)}", :payload => resource.to_json)

        update_with_response(resource, response)
      end
    end

    def read(query)
      model = query.model

      records = if id = extract_id_from_query(query)
        response = connection.http_get("#{resource_name(model)}/#{id}")
        [ JSON_PARSER.call(response.body, model) ]
      else
        response = connection.http_get(resource_name(model), :params => extract_params_from_query(query))
        MULTI_JSON_PARSER.call(response.body, model)
      end

      query.filter_records(records)
    end

    def update(dirty_attributes, collection)
      collection.select do |resource|
        model = resource.model
        key   = model.key
        id    = key.get(resource).join

        dirty_attributes.each { |p, v| p.set!(resource, v) }

        response = connection.http_put("#{resource_name(model)}/#{id}", :payload => resource.to_xml)

        update_with_response(resource, response)
      end.size
    end

    def delete(collection)
      collection.select do |resource|
        model = resource.model
        key   = model.key
        id    = key.get(resource).join

        response = connection.http_delete("#{resource_name(model)}/#{id}")
        response.kind_of?(Net::HTTPSuccess)
      end.size
    end

    private

    def format
      @format = @options.fetch(:format, 'json')
    end

    def connection
      @connection ||= Connection.new(:site_uri => site_uri, :format => format)
    end

    def connection_options
      @options
    end

    def site_uri
      @site_uri ||=
        begin
          site_uri = @options[:site_uri]
          Addressable::URI.parse(site_uri).freeze
        end
    end

    def ssl?
      @ssl ||= @options.fetch(:ssl, false)
    end

    def extract_id_from_query(query)
      return nil unless query.limit == 1

      conditions = query.conditions

      return nil unless conditions.kind_of?(DataMapper::Query::Conditions::AndOperation)
      return nil unless (key_condition = conditions.select { |o| o.subject.key? }).size == 1

      key_condition.first.value
    end

    def extract_params_from_query(query)
      conditions = query.conditions

      return {} unless conditions.kind_of?(DataMapper::Query::Conditions::AndOperation)
      return {} if conditions.any? { |o| o.subject.key? }

      query.options
    end

    def resource_name(model)
      model.storage_name(self.name)
    end

    def update_with_response(resource, response)
      return unless response.kind_of?(Net::HTTPSuccess) && !response.body.blank?

      model      = resource.model
      properties = model.properties(name)

      JSON_PARSER.call(response.body, model).each do |key, value|
        if property = properties[key.to_sym]
          property.set!(resource, value)
        end
      end
    end
  end
end
