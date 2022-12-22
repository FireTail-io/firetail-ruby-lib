require 'json-schema'
require 'json'

class Error < StandardError; end

class JsonValidator

  def self.validate(payload)
    schema_location = File.join(Rails.root, "config/schema.yaml") 
    schema_exists = File.exists?(schema_location)
    if schema_exists
      data = JSON.parse(payload)

      schema = YAML.load_file(schema_location)
      result = JSON::Validator.validate!(schema, data)
      puts "result: #{result}, data: #{data}"
      if result
        return false
      end
      true
    else
      false
      raise Error.new "need your API specification in \"config/schema.yaml\""
    end
  end
end
