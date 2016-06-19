module ActiveModel
  class Serializer
    module CollectionCaching
      def to_json(*args)
        if caching_enabled?
          keyed = keyed_hash('to-json')
          keys  = keyed.keys.map(&:dup)

          cached = cache.fetch_multi(*keys) do |key|
            keyed[key].to_json
          end

          "[#{cached.join(',')}]"
        else
          super
        end
      end

      def serializable_hash(adapter_options, options, adapter_instance)
        @adapter_instance = adapter_instance
        if caching_enabled?
          keyed = keyed_hash('serialize')
          keys  = keyed.keys.map(&:dup)

          cache.fetch_multi(*keys) do |key|
            keyed[key].serializable_hash
          end
        else
          super
        end
      end

      private

      def cache
        @cache ||= serializers.detect(&:cache_store)
      end

      def caching_enabled?
        @caching_enabled ||= object.any?(&:caching_enabled?)
      end

      def adapter_instance
        return @adapter_instance if defined?(@adapter_instance)
        @adapter_instance = serializers.detect(&:adapter_instance)
      end

      def keyed_hash(suffix)
        serializers.each_with_object({}) do |serializer, hash|
          hash[serializer.expanded_cache_key(suffix, adapter_instance)] = serializer
          # serializer.perform_caching = false
        end
      end
    end
  end
end
