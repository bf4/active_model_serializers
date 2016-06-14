module ActiveModel
  class Serializer < ::RailsAPI::Resource
    # @api private
    class HasOneReflection < SingularReflection
    end
  end
end
