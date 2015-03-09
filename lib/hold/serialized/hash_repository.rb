module Hold
  module Serialized
    # A repository which caches serialized versions of an entity in a
    # string-based key/value cache.
    #
    # Wraps a string-based HashRepository, and requires a serializer responding
    # to 'serialize' and 'deserialize'.
    #
    # May optionally have a 'key_prefix', which is a prefixed namespace added
    # to the cache keys before getting/setting the serialized values in the
    # underlying cache.
    class HashRepository
      include Hold::HashRepository

      attr_reader :cache, :serializer, :key_prefix

      def initialize(cache, serializer, key_prefix = nil)
        @cache = cache
        @serializer = serializer
        @key_prefix = key_prefix
      end

      def cache_key(key)
        @key_prefix ? @key_prefix + key.to_s : key.to_s
      end

      def set_with_key(key, entity)
        @cache.set_with_key(cache_key(key), @serializer.serialize(entity))
      end

      def get_with_key(key)
        if (json = @cache.get_with_key(cache_key(key)))
          @serializer.deserialize(json)
        end
      end

      def get_many_with_keys(keys)
        jsons = @cache.get_many_with_keys(*keys.map { |key| cache_key(key) })
        jsons.map { |json| json && @serializer.deserialize(json) }
      end

      def key?(key)
        @cache.key?(cache_key(key))
      end
      alias_method :has_key?, :key?

      def clear_key(key)
        @cache.clear_key(cache_key(key))
      end
    end
  end
end
