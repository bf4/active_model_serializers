# frozen_string_literal: true
require "test_helper"

module AMS
  class Serializer
    class RelationshipsTest < Test
      class ParentModelSerializer < Serializer
        # TODO: test to: :many without :ids option
        # TODO: test to: :one without :id option
        relation :child_models, type: :comments, to: :many, ids: "object.child_models.map(&:id)"
        relation :child_model, type: :comments, to: :one, id: "object.child_model.id"
      end

      def setup
        super
        @object = ParentModel.new(
          child_models: [ ChildModel.new(id: 2, name: "comments") ],
          child_model: ChildModel.new(id: 1, name: "comment")
        )
        @serializer_class = ParentModelSerializer
        @serializer_instance = @serializer_class.new(@object)
      end

      def test_relation_macro_missing_type
        exception = assert_raises(ArgumentError) do
          ParentModelSerializer.relation :missing_type, to: :anything
        end
        assert_match(/missing keyword: type/, exception.message)
      end

      def test_relation_macro_bad_to
        exception = assert_raises(ArgumentError) do
          ParentModelSerializer.relation :unknown_relation_to, type: :anything, to: :unknown_option
        end
        assert_match(/UnknownRelationship to='unknown_option'/, exception.message)
      end

      def test_relation_macro_missing_to
        exception = assert_raises(ArgumentError) do
          ParentModelSerializer.relation :missing_relation_to, type: :anything
        end
        assert_match(/missing keyword: to/, exception.message)
      end

      def test_relation_macro_to_many_missing_ids
        exception = assert_raises(ArgumentError) do
          ParentModelSerializer.relation :missing_relation_ids, type: :anything, to: :many
        end
        assert_match(/missing keyword: ids/, exception.message)
      end

      def test_relation_macro_to_one_missing_id
        exception = assert_raises(ArgumentError) do
          ParentModelSerializer.relation :missing_relation_id, type: :anything, to: :one
        end
        assert_match(/missing keyword: id/, exception.message)
      end

      def test_model_instance_relations
        expected_relations = {
          child_models: {
            data: [{ type: "comments", id: "2" }]
          },
          child_model: {
            data: { type: "comments", id: "1" }
          }
        }
        assert_equal expected_relations, @serializer_instance.relations
      end

      def test_model_instance_relationship_data
        expected = {
          type: :bananas, id: "5"
        }
        assert_equal expected, @serializer_instance.relationship_data(5, :bananas)
      end

      def test_model_instance_relationship_to_one
        expected = {
          data: { id: @object.child_model.id.to_s, type: "comments" }
        }
        assert_equal expected, @serializer_instance.child_model
      end

      def test_model_instance_relationship_to_one_id
        expected = @object.child_model.id
        assert_equal expected, @serializer_instance.related_child_model_id
      end

      def test_model_instance_relationship_to_many
        expected = {
          data: [{ id: @object.child_models.first.id.to_s, type: "comments" }]
        }
        assert_equal expected, @serializer_instance.child_models
      end

      def test_model_instance_relationship_to_many_ids
        expected = @object.child_models.map(&:id)
        assert_equal expected, @serializer_instance.related_child_models_ids
      end
    end
  end
end
