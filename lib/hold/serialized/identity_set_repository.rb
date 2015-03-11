module Hold
  module Serialized
    # Serialized identity set repository
    class IdentitySetRepository
      include Hold::IdentitySetRepository

      attr_reader :cache, :serializer, :key_prefix

      def initialize(cache, serializer, key_prefix = nil)
        @cache = cache
        @serializer = serializer
        @key_prefix = key_prefix
      end

      def cache_key(key)
        @key_prefix ? @key_prefix + key.to_s : key.to_s
      end

      def allocates_ids?
        false
      end

      def store(object)
        id = object.id || (fail MissingIdentity)
        @cache.set_with_key(cache_key(id), @serializer.serialize(object))
        object
      end

      def delete(object)
        id = object.id || (fail MissingIdentity)
        delete_id(id)
      end

      def contains?(object)
        id = object.id || (fail MissingIdentity)
        contains_id?(id)
      end

      def get_by_id(id)
        (json = @cache.get_with_key(cache_key(id))) &&
          @serializer.deserialize(json).each_with_object({}) do |(k, v), memo|
            memo[k.to_sym] = v
          end
      end

      def delete_id(id)
        @cache.clear_key(cache_key(id))
      end

      def contains_id?(id)
        @cache.key?(cache_key(id))
      end
    end
  end
end
