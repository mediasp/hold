module Hold
  module InMemory
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

      def get_slice(start, length)
        @array[start, length]
      end

      def get_length
        @array.length
      end
    end
  end
end
