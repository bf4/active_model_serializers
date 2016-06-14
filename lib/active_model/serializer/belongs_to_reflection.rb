module ActiveModel
  class Serializer < ::RailsAPI::Resource
    # @api private
    class BelongsToReflection < SingularReflection
    end
  end
end
