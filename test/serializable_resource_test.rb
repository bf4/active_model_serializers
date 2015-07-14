require 'test_helper'

module ActiveModel
  class SerializableResourceTest < ActiveSupport::TestCase
    def setup
      @resource = Profile.new({ name: 'Name 1', description: 'Description 1', comments: 'Comments 1' })
      @serializer = ProfileSerializer.new(@resource)
      @adapter = ActiveModel::Serializer::Adapter.create(@serializer)
      @serializable_resource = ActiveModel::SerializableResource.new(@resource)
    end

    def test_serializable_resource_delegates_serializable_hash_to_the_adapter
      options = nil
      assert_equal @adapter.serializable_hash(options), @serializable_resource.serializable_hash(options)
    end

    def test_serializable_resource_delegates_to_json_to_the_adapter
      options = nil
      assert_equal @adapter.to_json(options), @serializable_resource.to_json(options)
    end

    def test_serializable_resource_delegates_as_json_to_the_adapter
      options = nil
      assert_equal @adapter.as_json(options), @serializable_resource.as_json(options)
    end

    def test_use_adapter_with_adapter_option
      assert ActiveModel::SerializableResource.new(@resource, { adapter: 'json' }).use_adapter?
    end

    def test_use_adapter_with_adapter_option_as_false
      refute ActiveModel::SerializableResource.new(@resource, { adapter: false }).use_adapter?
    end

    class SerializableResourceErrorsTest < Minitest::Test
      def test_serializable_resource_with_errors
        options = nil
        resource = ModelWithErrors.new
        resource.errors.add(:name, 'must be awesome')
        serializable_resource = ActiveModel::SerializableResource.new(resource)
        expected_response_document =
          { 'errors'.freeze =>
            [
              { :source => { :pointer => '/data/attributes/name' }, :detail => 'must be awesome' }
            ]
        }
        assert_equal serializable_resource.as_json(options), expected_response_document
      end

      def test_serializable_resource_with_collection_containing_errors
        options = nil
        resources = []
        resources << resource = ModelWithErrors.new
        resource.errors.add(:title, 'must be amazing')
        resources << ModelWithErrors.new
        serializable_resource = ActiveModel::SerializableResource.new(resources)
        expected_response_document =
          { 'errors'.freeze =>
            [
              { :source => { :pointer => '/data/attributes/title' }, :detail => 'must be amazing' }
            ]
        }
        assert_equal serializable_resource.as_json(options), expected_response_document
      end
    end
  end
end
