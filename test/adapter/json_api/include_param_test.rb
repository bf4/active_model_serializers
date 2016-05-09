require 'test_helper'

module ActiveModel
  class Serializer
    module Adapter
      class JsonApi
        class IncludeParamTest < ActiveSupport::TestCase
          IncludeParamAuthor = Class.new(::Model)

          class CustomCommentLoader
            def all
              [{ foo: 'bar' }]
            end
          end

          class TagSerializer < ActiveModel::Serializer
            attributes :id, :name
          end

          class IncludeParamAuthorSerializer < ActiveModel::Serializer
            class_attribute :comment_loader

            associations_via_include_param(true)

            has_many :tags, serializer: TagSerializer do
              link :self, '//example.com/link_author/relationships/tags'
            end

            has_many :unlinked_tags, serializer: TagSerializer

            has_many :posts, serializer: PostWithTagsSerializer
            has_many :locations
            has_many :comments do
              load_data { IncludeParamAuthorSerializer.comment_loader.all }
            end

            has_many :inline_comments do
              [{ im: 'inline' }]
            end
          end

          def setup
            IncludeParamAuthorSerializer.comment_loader = Class.new(CustomCommentLoader).new
            @tag = Tag.new(id: 1337, name: 'mytag')
            @author = IncludeParamAuthor.new(
              id: 1337,
              tags: [@tag]
            )
          end

          def test_relationship_not_loaded_when_not_included
            expected = {
              links: {
                self: '//example.com/link_author/relationships/tags'
              }
            }

            @author.define_singleton_method(:read_attribute_for_serialization) do |attr|
              fail 'should not be called' if attr == :tags
              super(attr)
            end

            assert_relationship(:tags, expected)
          end

          def test_relationship_included
            expected = {
              data: [
                {
                  id: '1337',
                  type: 'tags'
                }
              ],
              links: {
                self: '//example.com/link_author/relationships/tags'
              }
            }

            assert_relationship(:tags, expected, include: :tags)
          end

          def test_sideloads_included
            expected = [
              {
                id: '1337',
                type: 'tags',
                attributes: { name: 'mytag' }
              }
            ]
            hash = result(include: :tags)
            assert_equal(expected, hash[:included])
          end

          def test_nested_relationship
            expected = {
              data: [
                {
                  id: '1337',
                  type: 'tags'
                }
              ],
              links: {
                self: '//example.com/link_author/relationships/tags'
              }
            }

            expected_no_data = {
              links: {
                self: '//example.com/link_author/relationships/tags'
              }
            }

            assert_relationship(:tags, expected, include: [:tags, { posts: :tags }])

            @author.define_singleton_method(:read_attribute_for_serialization) do |attr|
              fail 'should not be called' if attr == :tags
              super(attr)
            end

            assert_relationship(:tags, expected_no_data, include: { posts: :tags })
          end

          def test_include_params_with_no_block
            @author.define_singleton_method(:read_attribute_for_serialization) do |attr|
              fail 'should not be called' if attr == :locations
              super(attr)
            end

            expected = {}

            assert_relationship(:locations, expected)
          end

          def test_block_relationship
            expected = {
              data: [
                { 'foo' => 'bar' }
              ]
            }

            assert_relationship(:comments, expected, include: [:comments])
          end

          def test_block_relationship_not_included
            expected = {}

            IncludeParamAuthorSerializer.comment_loader.define_singleton_method(:all) do
              fail 'should not be called'
            end

            assert_relationship(:comments, expected)
          end

          # TODO: This is currently testing for backwards-compatibility
          # It can be removed when a decision is reached in
          # https://github.com/rails-api/active_model_serializers/pull/1720
          def test_block_value_without_load_data
            expected = {
              data: [
                { 'im' => 'inline' }
              ]
            }

            assert_relationship(:'inline-comments', expected, include: [:inline_comments])
          end

          def test_node_not_included_when_no_link
            expected = nil
            assert_relationship(:unlinked_tags, expected)
          end

          private

          def result(opts)
            opts = { adapter: :json_api }.merge(opts)
            serializable(@author, opts).serializable_hash
          end

          def assert_relationship(relationship_name, expected, opts = {})
            hash = result(opts)
            assert_equal(expected, hash[:data][:relationships][relationship_name])
          end
        end
      end
    end
  end
end
