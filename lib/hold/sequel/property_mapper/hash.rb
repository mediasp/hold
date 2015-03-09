module Hold::Sequel
  # A property which is a hash of strings to other primitive values. Persisted
  # 'all in one go' in a separate table.
  class PropertyMapper::Hash < PropertyMapper
    attr_reader :table, :foreign_key, :key_column, :value_column

    def initialize(repo, property_name,
                   table: :"#{repo.main_table}_#{property_name}",
                   foreign_key: :"#{repo.main_table.to_s.singularize}_id",
                   key_column: :key,
                   value_column: :value)

      super(repo, property_name)

      @table = table
      @foreign_key  = foreign_key
      @key_column = key_column
      @value_column = value_column

      @dataset    = @repository.db[@table]
      @select_kv  = @repository.db[@table].select(
        Sequel.as(@key_column, :key),
        Sequel.as(@value_column, :value))
      @select_all = @repository.db[@table].select(
        Sequel.as(@key_column, :key),
        Sequel.as(@value_column, :value),
        Sequel.as(@foreign_key, :id))
    end

    def load_value(_row = nil, id = nil, _properties = nil)
      result = {}
      @select_kv.filter(@foreign_key => id).each do |row|
        result[row[:key]] = row[:value]
      end
      result
    end

    def load_values(_rows = nil, ids = nil, _properties = nil, &block)
      results = Hash.new { |h, k| h[k] = {} }
      @select_all.filter(@foreign_key => ids).each do |row|
        results[row[:id]][row[:key]] = row[:value]
      end
      result.values_at(*ids).each_with_index(&block)
    end

    def pre_delete(entity)
      @dataset.filter(@foreign_key => entity.id).delete
    end

    def post_insert(entity, _rows, last_insert_id = nil)
      hash = entity[@property_name] or return
      @dataset.multi_insert(hash.map do |k, v|
        { @foreign_key => last_insert_id, @key_column => k, @value_column => v }
      end)
    end

    def post_update(entity, update_entity, _rows, _data_from_pre_update)
      hash = update_entity[@property_name] or return
      @dataset.filter(@foreign_key => entity.id).delete
      @dataset.multi_insert(hash.map do |k, v|
        { @foreign_key => entity.id, @key_column => k, @value_column => v }
      end)
    end
  end
end
