require 'json'
require 'json_schema'

require 'minitest'
class JsonSchemaTest < Minitest::Test

  def setup
    super
    test_dir = File.expand_path('..', __FILE__)
    @document_store = JsonSchema::DocumentStore.new
    schema_directory = File.join(test_dir, 'schema/schemata')
    @schemas = {}
    Dir.glob("#{schema_directory}/**/*.json").each do |path|
      schema_data = JSON.parse(File.read(path))
      extra_schema = JsonSchema.parse!(schema_data)
      @schemas[File.basename(path).sub(/\.json\z/, '')] = schema_data
      @document_store.add_schema(extra_schema)
    end
  end

  def test_link_string_is_valid
    data = "http://www.example.com"
    assert_schema_definition('link', data)
  end

  def test_link_object_with_href_is_valid
    data = { "href" => "http://www.example.com" }
    assert_schema_definition('link', data)
  end

  def test_link_object_without_href_is_invalid
    data = { "not_a_href" => "http://www.example.com" }
    error_matcher = /\"href\" wasn't supplied/
    refute_schema_definition('link', data, error_matcher)
  end

  def test_link_object_href_not_a_uri_is_invalid
    data = { "href" => "http://www.example.com[]" }
    assert_raises(URI::InvalidURIError) { URI.parse(data["href"]) }
    error_matcher = /not a valid uri/
    refute_schema_definition('link', data, error_matcher)
  end

  def refute_schema_definition(definition, data, error_matcher)
    schema = validator_for_definition(definition)

    status, errors = schema.validate(data)

    refute status, "Expected definition '#{definition}' to be invalid with data '#{data}'"
    assert_match error_matcher, schema_error_message(errors)
  end

  def assert_schema_definition(definition, data)
    schema = validator_for_definition(definition)

    status, errors = schema.validate(data)

    assert status, schema_error_message(errors)
  end

  def validator_for_definition(definition)
    schema_data = @schemas.fetch(definition)
    ## parse the schema - raise SchemaError if it's invalid
    schema = JsonSchema.parse!(schema_data)
    # expand $ref nodes - raise SchemaError if unable to resolve
    schema.expand_references!(store: @document_store)
    schema
  end

  def schema_error_message(errors)
    if errors.is_a?(Array)
      errors.map {|error| schema_error_message(error) }.join("\n")
    elsif errors.nil?
      ''
    else
      if (sub_errors = errors.sub_errors).nil?
        errors.to_s
      else
        schema_error_message(sub_errors)
      end
    end
  end
end
