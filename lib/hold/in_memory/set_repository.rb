module Hold
  module InMemory
    class SetRepository
      include Hold::SetRepository

      def initialize
        @set = Set.new
      end

      def store(value)
        @set << value
      end

      def delete(value)
        @set.delete(value)
      end

      def contains?(value)
        @set.include?(value)
      end

      def all
        @set.to_a
      end
      alias_method :get_all, :all
    end
  end
end
