module Persistence

  # These are a set of implementations of Persistence interfaces based on in-memory storage.
  # They're not threadsafe or for production use, but are here as lightweight implementations to use in
  # tests, and for illustrative purposes.
  module InMemory; end

  ARG_EMPTY = Object.new.freeze # something different to everything else

  class InMemory::Cell
    include Cell

    # new -- empty
    # new(nil) -- non-empty, value is nil
    # new(123) -- non-empty, value is 123
    def initialize(value=ARG_EMPTY)
      @value = value unless ARG_EMPTY.equal?(value)
    end

    def get
      @value
    end

    def set(value)
      @value = value
    end

    def empty?
      !instance_variable_defined?(:@value)
    end

    def clear
      remove_instance_variable(:@value) if instance_variable_defined?(:@value)
    end
  end

  class InMemory::ArrayCell
    include ArrayCell

    def initialize(array=[])
      @array = array
    end

    def get
      @array.dup
    end

    def set(value)
      @array.replace(value)
    end

    def get_slice(start,length)
      @array[start, length]
    end

    def get_length
      @array.length
    end
  end

  class InMemory::ObjectCell < InMemory::Cell
    include ObjectCell

    def get
      @value && @value.dup
    end

    def get_property(property_name)
      @value && @value[property_name]
    end

    def set_property(property_name, value)
      raise EmptyConflict unless @value
      @value[property_name] = value
    end

    def clear_property(property_name)
      raise EmptyConflict unless @value
      @value.delete(property_name)
    end

    def has_property?(property_name)
      raise EmptyConflict unless @value
      @value.has_key?(property_name)
    end
  end

  class InMemory::HashRepository
    include HashRepository

    def initialize
      @hash = {}
    end

    def set_with_key(key, value)
      @hash[key] = value
    end

    def get_with_key(key)
      value = @hash[key] and value.dup
    end

    def clear_key(key)
      @hash.delete(key)
    end

    def has_key?(key)
      @hash.has_key?(key)
    end
  end

  class InMemory::IdentityHashRepository < InMemory::HashRepository
    include IdentityHashRepository
  end
end
