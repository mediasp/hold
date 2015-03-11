module Hold
  module InMemory
    # In memory Cell
    class Cell
      include Hold::Cell

      # new -- empty
      # new(nil) -- non-empty, value is nil
      # new(123) -- non-empty, value is 123
      def initialize(value = ARG_EMPTY)
        @value = value unless ARG_EMPTY.equal?(value)
      end

      attr_accessor :value
      alias_method :set, :value=
      alias_method :get, :value

      def empty?
        !instance_variable_defined?(:@value)
      end

      def clear
        remove_instance_variable(:@value) if instance_variable_defined?(:@value)
      end
    end
  end
end
