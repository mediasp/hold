module Hold
  # Interface extending Cell which offers some array-specific persistence
  # methods for use only with Arrays.
  # Default implementations are in terms of get, but it's expected that you'd
  # override with more efficient implementations.
  module ArrayCell
    include Cell

    def get_slice(start, length)
      value = get() and value[start, length]
    end

    def get_length
      value = get() and value.length
    end

    # returns an instance of ThinModels::LazyArray which lazily computes slices
    # and length based on the get_length and get_slice methods you define.
    def get_lazy_array
      LazyArray.new(self)
    end

    def can_get_class?(klass); klass == Array; end
    def can_set_class?(klass); klass <= Array; end

    # Can override to indicate if you only support getting/setting arrays with
    # items of a particular class or classes:
    def can_get_item_class?(_); true; end
    def can_set_item_class?(_); true; end

    class LazyArray < ThinModels::LazyArray::Memoized
      def initialize(array_cell)
        @array_cell = array_cell
      end

      def _each(&b)
        @array_cell.get.each(&b)
      end

      def slice_from_start_and_length(start, length)
        @array_cell.get_slice(start, length)
      end

      def _length
        @array_cell.get_length
      end
    end
  end
end
