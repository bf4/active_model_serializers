require 'jsonapi/deserializable/resource'
module ActiveModelSerializers
  module Adapter
    class JsonApi
      module Deserialization
        InvalidDocument = Class.new(ArgumentError)

        module_function

        # Transform a JSON API document, containing a single data object,
        # into a hash that is ready for ActiveRecord::Base.new() and such.
        # Raises InvalidDocument if the payload is not properly formatted.
        #
        # @param [Hash|ActionController::Parameters] document
        # @param [Hash] options
        #   only: Array of symbols of whitelisted fields.
        #   except: Array of symbols of blacklisted fields.
        #   keys: Hash of translated keys (e.g. :author => :user).
        #   polymorphic: Array of symbols of polymorphic fields.
        # @return [Hash]
        #
        # @example
        #   document = {
        #     data: {
        #       id: 1,
        #       type: 'post',
        #       attributes: {
        #         title: 'Title 1',
        #         date: '2015-12-20'
        #       },
        #       associations: {
        #         author: {
        #           data: {
        #             type: 'user',
        #             id: 2
        #           }
        #         },
        #         second_author: {
        #           data: nil
        #         },
        #         comments: {
        #           data: [{
        #             type: 'comment',
        #             id: 3
        #           },{
        #             type: 'comment',
        #             id: 4
        #           }]
        #         }
        #       }
        #     }
        #   }
        #
        #   parse(document) #=>
        #     # {
        #     #   title: 'Title 1',
        #     #   date: '2015-12-20',
        #     #   author_id: 2,
        #     #   second_author_id: nil
        #     #   comment_ids: [3, 4]
        #     # }
        #
        #   parse(document, only: [:title, :date, :author],
        #                   keys: { date: :published_at },
        #                   polymorphic: [:author]) #=>
        #     # {
        #     #   title: 'Title 1',
        #     #   published_at: '2015-12-20',
        #     #   author_id: '2',
        #     #   author_type: 'people'
        #     # }
        #
        # @example
        #   def deserialized_params
        #     ActionController::Parameters.new(
        #       ActiveModelSerializers::Deserialization.jsonapi_parse!(
        #         request.request_parameters # no need for request.query_parameters, request.path_parameters
        #       )
        #     )
        #   end
        def parse!(document, options = {})
          document = document.dup.permit!.to_h if document.is_a?(ActionController::Parameters)
          primary_data = document.slice('data')
          hash = JSONAPI::Deserializable::Resource.call(primary_data)
          id_keys = hash.keys.select { |key| key.to_s.end_with?('_id') }.map { |key| key.to_s.sub(/_id\z/, '') }
          ids_keys = hash.keys.select { |key| key.to_s.end_with?('_ids') }.map { |key| key.to_s.sub(/_ids\z/, '') }
          excluded_keys = id_keys.map { |key| "#{key}_type" } .concat(ids_keys.map { |key| "#{key}_types" })
          excluded_keys << :type
          excluded_keys.map!(&:to_sym)
          hash = hash.except(*excluded_keys)
          filter_fields(hash, options)
          transform_keys(hash, options)
        rescue NoMethodError, JSONAPI::Parser::InvalidDocument => e
          if block_given?
            yield(e)
          else
            raise InvalidDocument, "Invalid payload (#{e.message}): #{primary_data}"
          end
        end

        # Same as parse!, but returns an empty hash instead of raising InvalidDocument
        # on invalid payloads.
        def parse(document, options = {})
          parse!(document, options) do
            {}
          end
        end

        # @api private
        def filter_fields(fields, options)
          if (only = options[:only])
            fields.slice!(*Array(only).map(&:to_s))
          elsif (except = options[:except])
            fields.except!(*Array(except).map(&:to_s))
          end
        end

        # @api private
        def transform_keys(hash, options)
          transform = options[:key_transform] || :underscore
          CaseTransform.send(transform, hash)
        end
      end
    end
  end
end
