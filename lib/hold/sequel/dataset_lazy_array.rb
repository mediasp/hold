module Hold
  module Sequel
    class DatasetLazyArray < ThinModels::LazyArray::MemoizedLength
      def initialize(dataset, &block)
        @dataset = dataset
        @block = block
      end

      def _each(&block)
        rows = Hold::Sequel.translate_exceptions { @dataset.all }
        (@block ? @block.call(rows) : rows).each(&block)
      end

      def _length
        Hold::Sequel.translate_exceptions { @dataset.count }
      end

      def slice_from_start_and_length(offset, limit)
        rows = if limit > 0
                 Hold::Sequel.translate_exceptions do
                   @dataset.limit(limit, offset).all
                 end
               else
                 []
               end
        # we're supposed to return nil if offset > length of the array,
        # as per Array#slice:
        return nil if rows.empty? && offset > 0 && offset > length
        @block ? @block.call(rows) : rows
      end
    end
  end
end
