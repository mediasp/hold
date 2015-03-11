module Hold
  # Persists values in a key/value store
  module HashRepository
    # Gets multiple entities at a time by a list of keys.
    # May override with an efficient multi-get implementation.
    def get_many_with_keys(keys)
      keys.map { |key| get_with_key(key) }
    end

    def key_cell(key)
      KeyCell.new(self, key)
    end

    # Can override to indicate if you only support getting/setting values of a
    # particular class or classes:
    def can_get_class?(_)
      true
    end

    def can_set_class?(_)
      true
    end

    # Key cell
    class KeyCell
      include Cell

      def initialize(hash_repository, key)
        @hash_repository, @key = hash_repository, key
      end

      def get
        @hash_repository.get_with_key(@key)
      end

      def set(value)
        @hash_repository.set_with_key(@key, value)
      end

      def clear
        @hash_repository.clear_key(@key)
      end

      def empty?
        @hash_repository.key?(@key)
      end

      def can_get_class?(klass)
        @hash_repository.can_get_class?(klass)
      end

      def can_set_class?(klass)
        @hash_repository.can_set_class?(klass)
      end
    end
  end
end
