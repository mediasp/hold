module Hold
  module InMemory
    class HashRepository
      include Hold::HashRepository

      def initialize
        @hash = {}
      end

      def set_with_key(key, value)
        @hash[key] = value
      end

      def get_with_key(key)
        (value = @hash[key]) && value.dup
      end

      def clear_key(key)
        @hash.delete(key)
      end

      def key?(key)
        @hash.key?(key)
      end
      alias_method :has_key?, :key?
    end
  end
end
