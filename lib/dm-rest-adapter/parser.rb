module DataMapperRest
  # TODO: Abstract this to JSON and XML parser
  class Parser
    def record_from_rexml(entity_element, field_to_property)
      record = {}

      entity_element.elements.map do |element|
        # TODO: push this to the per-property mix-in for this adapter
        field = element.name.to_s.tr('-', '_')
        next unless property = field_to_property[field]
        record[field] = property.typecast(element.text)
      end

      record
    end

    def call(body, model)
      parse_resource(xml, model)
    end

    def parse_resource(xml, model)
      doc = REXML::Document::new(xml)

      element_name = element_name(model)

      unless entity_element = REXML::XPath.first(doc, "/#{element_name}")
        raise "No root element matching #{element_name} in xml"
      end

      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      record_from_rexml(entity_element, field_to_property)
    end

    def parse_resources(xml, model)
      doc = REXML::Document::new(xml)

      field_to_property = model.properties(name).map { |p| [ p.field, p ] }.to_hash
      element_name      = element_name(model)

      doc.elements.collect("/#{resource_name(model)}/#{element_name}") do |entity_element|
        record_from_rexml(entity_element, field_to_property)
      end
    end

    def element_name(model)
      model.storage_name(self.name).singularize
    end

  end
end
