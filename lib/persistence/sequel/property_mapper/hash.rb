module Persistence::Sequel
  # A property which is a hash of strings to other primitive values. Persisted 'all in one go'
  # in a separate table.
  class PropertyMapper::Hash < PropertyMapper
    attr_reader :table, :foreign_key, :key_column, :value_column

    def initialize(repo, property_name, options)
      super(repo, property_name)

      @table        = options[:table]        || :"#{repo.main_table}_#{property_name}"
      @foreign_key  = options[:foreign_key]  || :"#{repo.main_table.to_s.singularize}_id"
      @key_column   = options[:key_column]   || :key
      @value_column = options[:value_column] || :value

      @dataset    = @repository.db[@table]
      @select_kv  = @repository.db[@table].select(@key_column.as(:key), @value_column.as(:value))
      @select_all = @repository.db[@table].select(@key_column.as(:key), @value_column.as(:value), @foreign_key.as(:id))
    end

    def load_value(row=nil, id=nil, version=nil)
      result = {}
      @select_kv.filter(@foreign_key => id).each do |row|
        result[row[:key]] = row[:value]
      end
      result
    end

    def load_values(rows=nil, ids=nil, version=nil, &block)
      results = Hash.new {|h,k| h[k]={}}
      @select_all.filter(@foreign_key => ids).each do |row|
        results[row[:id]][row[:key]] = row[:value]
      end
      result.values_at(*ids).each_with_index(&block)
    end

    def pre_delete(entity)
      @dataset.filter(@foreign_key => entity.id).delete
    end

    def post_insert(entity, rows, last_insert_id=nil)
      hash = entity[@property_name] or return
      @dataset.multi_insert(hash.map do |k,v|
        {@foreign_key => last_insert_id, @key_column => k, @value_column => v}
      end)
    end

    def post_update(entity, update_entity, rows, data_from_pre_update)
      hash = update_entity[@property_name] or return
      @dataset.filter(@foreign_key => entity.id).delete
      @dataset.multi_insert(hash.map do |k,v|
        {@foreign_key => entity.id, @key_column => k, @value_column => v}
      end)
    end
  end
end
