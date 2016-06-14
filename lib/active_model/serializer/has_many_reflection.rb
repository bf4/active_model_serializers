module ActiveModel
  class Serializer < ::RailsAPI::Resource
    # @api private
    class HasManyReflection < CollectionReflection
    end
  end
end
