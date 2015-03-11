module Hold
  module InMemory
    # In memory array cell
    class ArrayCell
      include Hold::ArrayCell

      def initialize(array = [])
        @array = array
      end

      def get
        @array.dup
      end

      def set(value)
        @array.replace(value)
      end

      def slice(start, length)
        @array[start, length]
      end
      alias_method :get_slice, :slice

      def length
        @array.length
      end
      alias_method :get_length, :length
    end
  end
end
