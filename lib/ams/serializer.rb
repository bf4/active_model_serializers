# frozen_string_literal: true

require "json"
require "ams/inflector"
require "ams/dsl_support"
module AMS
  # Lightweight mapping of a model to a JSON API resource object
  # with attributes and relationships
  #
  # The fundamental building block of AMS is the Serializer.
  # A Serializer is used by subclassing it, and then declaring its
  # type, attributes, relations, and uniquely identifying field.
  #
  # The term 'fields' may refer to attributes of the model or the names of related
  # models, as in {http://jsonapi.org/format/#document-resource-object-fields
  # JSON:API resource object fields}
  #
  # @example
  #
  #  class ApplicationSerializer < AMS::Serializer; end
  #  class UserModelSerializer < ApplicationSerializer
  #    type :users
  #    id_field :id
  #    attribute :first_name, key: 'first-name'
  #    attribute :last_name, key: 'last-name'
  #    attribute :email
  #    relation :department, type: :departments, to: :one
  #    relation :roles, type: :roles, to: :many
  #  end
  #
  #  user = User.last
  #  ums = UserModelSerializer.new(user)
  #  ums.to_json
  class Serializer < BasicObject
    extend DSLSupport
    # delegate constant lookup to Object
    def self.const_missing(name)
      ::Object.const_get(name)
    end

    class << self
      attr_accessor :_attributes, :_relations, :_id_field, :_type
      attr_accessor :_fields, :_query_params

      # @!visibility private
      def _infer_type(base)
        Inflector.pluralize(
          Inflector.underscore(
            base.name.split("::")[-1].sub(/Serializer/, "")
          )
         )
      end

      def inherited(base)
        super
        base._attributes = _attributes.dup
        base._relations = _relations.dup
        base._type = _infer_type(base)
        base._fields = _fields.dup
        base._query_params = _query_params.dup

        add_class_method "def class; #{base}; end", base
        add_instance_method "def id; object.id; end", base
      end

      # Configure resource type
      # Inferred from serializer name by default
      #
      # @example
      #   type :users
      def type(type)
        self._type = type
      end

      # Configures the field on the object which uniquely identifies it.
      # By default, id `object.id`
      #
      # @example
      #   id_field :user_id
      def id_field(id_field)
        self._id_field = id_field
        add_instance_method <<-METHOD, self
        def id
          object.#{id_field}
        end
        METHOD
      end

      # @example
      #   attribute :color, key: :hue
      #
      #   1. Generates the method
      #     def color
      #       object.color
      #     end
      #   2. Stores the attribute :color
      #     with options key: :hue
      def attribute(attribute_name, key: attribute_name)
        fail "ForbiddenKey" if attribute_name == :id
        _fields << key
        _attributes[attribute_name] = { key: key }

        # protect inheritance chains and open classes
        # if a serializer inherits from another OR
        #  attributes are added later in a classes lifecycle
        # poison the cache
        add_instance_method <<-METHOD, self
          def _fast_attributes
            raise NameError
          end
        METHOD

        add_instance_method <<-METHOD, self
        def #{attribute_name}
          object.#{attribute_name}
        end
        METHOD
      end

      #   1. Generates the methods
      #   2. Stores the relationship :articles with the given options
      #
      # @example
      #   relation :articles, type: :articles, to: :many, key: :posts
      #   relation :articles, type: :articles, to: :many, key: :posts, ids: "object.article_ids"
      #   relation :article, type: :articles, to: :one, key: :post
      #   relation :article, type: :articles, to: :one, key: :post, id: "object.article_id"
      #
      #   #=> { data: { id: 1, type: :users} }
      #   #=> { data: [ { id: 1, type: :users}, { id: 2, type: :users] } }
      def relation(relation_name, type:, to:, key: relation_name, **options)
        case to
        when :many then _relation_to_many(relation_name, type: type, key: key, **options)
        when :one then _relation_to_one(relation_name, type: type, key: key, **options)
        else
          fail ArgumentError, "UnknownRelationship to='#{to}'"
        end
        _fields << key
        _relations[relation_name] = { key: key, type: type, to: to }
      end

      # @example
      #   relation :articles, type: :articles, to: :many, key: :posts, ids: "object.article_ids"
      #
      #     def related_articles_ids
      #       object.article_ids
      #     end
      #
      #     def related_articles_data
      #       related_articles_ids.map {|id| relationship_data(id, :articles) }
      #     end
      #
      #     def articles
      #       {}.tap do |hash|
      #         hash[:data] = related_articles_data
      #       end
      #     end
      def _relation_to_many(relation_name, type:, ids:, key: relation_name, **options)
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_ids
            #{ids}
          end
        METHOD
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_data
            related_#{relation_name}_ids.map { |id| relationship_data(id, "#{type}") }
          end
        METHOD
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_links
            related_link_to_many("#{type}")
          end
        METHOD
        add_instance_method <<-METHOD, self
          def #{relation_name}
            {}.tap do |hash|
              hash[:data] = related_#{relation_name}_data
            end
          end
        METHOD
      end

      # @example
      #   relation :article, type: :articles, to: :one, key: :post, id: "object.article_id"
      #
      #     def related_article_id
      #       object.article_id
      #     end
      #
      #     def related_article_data
      #       relationship_data(related_article_id, :articles)
      #     end
      #
      #     def article
      #       {}.tap do |hash|
      #         hash[:data] = related_article_data
      #       end
      #     end
      def _relation_to_one(relation_name, type:, id:, key: relation_name, **options)
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_id
            #{id}
          end
        METHOD
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_data
            relationship_data(related_#{relation_name}_id, "#{type}")
          end
        METHOD
        add_instance_method <<-METHOD, self
          def related_#{relation_name}_links
            related_link_to_one(related_#{relation_name}_id, "#{type}")
          end
        METHOD
        add_instance_method <<-METHOD, self
          def #{relation_name}
            {}.tap do |hash|
              hash[:data] = related_#{relation_name}_data
            end
          end
        METHOD
      end

      # Configure allowed query parameters
      #
      # @example
      #   query_params(:start_at, :end_at, filter: [:user_id])
      def query_params(*args)
        _query_params.concat args
      end

      # Add pagination query params
      def paginated
        _query_params << { page: [:number, :size] }
      end

      # @return allowed parameters for a single serializer
      def show_params
        [{ fields: _fields }]
      end

      # @return allowed parameters for a collection serializer
      def index_params
        show_params + _query_params
      end
    end
    self._attributes = {}
    self._relations = {}
    self._fields = []
    self._query_params = []

    attr_reader :object

    # @param object [Object] the model whose data is used in serialization
    def initialize(object)
      @object = object
    end

    # Builds a Hash representation of the object
    # using id, type, attributes, relationships
    def to_h
      {
        id: id.to_s,
        type: type
      }.merge({
        attributes: attributes,
        relationships: relations
      }.reject { |_, v| v.empty? })
    end
    alias as_json to_h

    # Builds a JSON representation from as_json
    def to_json
      dump(as_json)
    end

    # Builds a Hash of specified attributes
    #
    # 1. For each configured attribute
    # 2.  map its :key to the attribute
    #
    # @example
    #   For the configured attribute:
    #
    #     attribute :color, key: :hue
    #
    #   The attributes hash will include:
    #
    #     attributes[:hue] = send(:color)
    #
    # TODO: Support sparse fieldsets
    def attributes
      _fast_attributes
    rescue NameError
      faster_method = String.new(%(def _fast_attributes\n hash={}\n))
      _attributes.each do |attribute_name, config|
        faster_method << %(hash[:"#{config[:key]}"] = #{attribute_name} # if include?(attribute_name)\n)
      end
      faster_method << "hash\nend"
      self.class.add_instance_method faster_method, self.class
      _fast_attributes
    end

    # Builds a Hash of specified relations
    #
    # 1. For each configured relation
    # 2.  map its :key to the relationship
    #
    # @example
    #   For the configured relation:
    #
    #     relation :user, key: :author
    #
    #   The relationships hash will include:
    #
    #     relations[:author] = send(:user)
    #
    # TODO: Support sparse fieldsets
    def relations
      hash = {}
      _relations.each do |relation_name, config|
        hash[config[:key]] = send(relation_name)
      end
      hash
    end

    # The configured type
    def type
      self.class._type
    end

    # The configured attributes
    def _attributes
      self.class._attributes
    end

    # The configured relations
    def _relations
      self.class._relations
    end

    # resource linkage
    def relationship_data(id, type)
      { id: id.to_s, type: type }
    end

    # Dumps obj to JSON
    # @param obj [Hash,Array,String,nil,Number]
    # @return [String] JSON
    def dump(obj)
      JSON.dump(obj)
    end

    # @!visibility private
    def send(*args)
      __send__(*args)
    end

    KERNEL_METHOD_METHOD = ::Kernel.instance_method(:method)
    def method(method_name)
      KERNEL_METHOD_METHOD.bind(self).call(method_name)
    end

    private

      def method_missing(name, *args, &block)
        object.send(name, *args, &block)
      end
  end
end
