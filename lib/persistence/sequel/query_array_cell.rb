require 'persistence/sequel'
require 'persistence/interfaces'
require_later 'persistence/sequel/query'

module Persistence::Sequel
  class QueryArrayCell
    include Persistence::ArrayCell

    def initialize(repo, *query_args, &query_block)
      @repo, @query_block = repo, query_block
    end

    def get(properties=nil)
      @repo.query(properties, &@query_block).to_a
    end

    def get_slice(start, length, properties=nil)
      @repo.query(properties, &@query_block).to_a(true)[start, length]
    end

    def get_length
      Query.new(@repo, [], &@query_block).to_a(true).length
    end
  end
end
