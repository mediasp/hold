module Hold
  module Sequel
    # Query an array cell
    class QueryArrayCell
      include Hold::ArrayCell

      def initialize(repo, *_query_args, &query_block)
        @repo, @query_block = repo, query_block
      end

      def get(properties = nil)
        @repo.query(properties, &@query_block).to_a
      end

      def slice(start, length, properties = nil)
        @repo.query(properties, &@query_block).to_a(true)[start, length]
      end
      alias_method :get_slice, :slice

      def length
        Query.new(@repo, [], &@query_block).to_a(true).length
      end
      alias_method :get_length, :length
    end
  end
end
