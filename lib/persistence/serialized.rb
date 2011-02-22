require 'persistence/interfaces'

module Persistence

  module Serialized; end

  # A repository which caches serialized versions of an entity in a string-based key/value cache.
  #
  # Wraps a string-based HashRepository, and requires a serializer responding to 'serialize' and
  # 'deserialize'.
  #
  # May optionally have a 'key_prefix', which is a prefixed namespace added to the cache keys
  # before getting/setting the serialized values in the underlying cache.
  class Serialized::HashRepository
    include Persistence::HashRepository

    attr_reader :cache, :serializer, :key_prefix

    def initialize(cache, serializer, key_prefix=nil)
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
      json = @cache.get_with_key(cache_key(key)) and @serializer.deserialize(json)
    end

    def get_many_with_keys(keys)
      jsons = @cache.get_many_with_keys(*keys.map {|key| cache_key(key)})
      jsons.map {|json| json && @serializer.deserialize(json)}
    end

    def has_key?(key)
      @cache.has_key?(cache_key(key))
    end

    def clear_key(key)
      @cache.clear_key(cache_key(key))
    end
  end

  class Serialized::IdentitySetRepository
    include Persistence::IdentitySetRepository

    attr_reader :cache, :serializer, :key_prefix

    def initialize(cache, serializer, key_prefix=nil)
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
      id = object.id or raise MissingIdentity
      @cache.set_with_key(cache_key(id), @serializer.serialize(object))
      object
    end

    def delete(object)
      id = object.id or raise MissingIdentity
      delete_id(id)
    end

    def contains?(object)
      id = object.id or raise MissingIdentity
      contains_id?(id)
    end

    def get_by_id(id)
      json = @cache.get_with_key(cache_key(id)) and @serializer.deserialize(json)
    end

    def delete_id(id)
      @cache.clear_key(cache_key(id))
    end

    def contains_id?(id)
      @cache.has_key?(cache_key(id))
    end

  end
end
