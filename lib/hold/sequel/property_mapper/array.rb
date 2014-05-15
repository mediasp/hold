module Hold::Sequel
  # A property which is an array of primitive values. Persisted 'all in one go' in a separate table.
  class PropertyMapper::Array < PropertyMapper
    attr_reader :table, :foreign_key, :value_column

    def initialize(repo, property_name, options)
      super(repo, property_name)

      @table        = options[:table]        || :"#{repo.main_table}_#{property_name}"
      @foreign_key  = options[:foreign_key]  || :"#{repo.main_table.to_s.singularize}_id"
      @value_column = options[:value_column] || :value
      @order_column = options[:order_column]

      @dataset    = @repository.db[@table]
      @select_v   = @repository.db[@table].select(Sequel.as(@value_column,:value))
      @select_v   = @select_v.order(@order_column) if @order_column
      @select_all = @repository.db[@table].select(
        Sequel.as(@value_column,:value),
        Sequel.as(@foreign_key,:id))
      @select_all = @select_all.order(@order_column) if @order_column
    end

    def load_value(row=nil, id=nil, properties=nil)
      @select_v.filter(@foreign_key => id).map {|row| row[:value]}
    end

    def load_values(rows=nil, ids=nil, properties=nil, &block)
      results = Hash.new {|h,k| h[k]=[]}
      @select_all.filter(@foreign_key => ids).each do |row|
        results[row[:id]] << row[:value]
      end
      result.values_at(*ids).each_with_index(&block)
    end

    def pre_delete(entity)
      @dataset.filter(@foreign_key => entity.id).delete
    end

    def post_insert(entity, rows, last_insert_id=nil)
      array = entity[@property_name] or return
      insert_rows = []
      array.each_with_index do |v,i|
        row = {@foreign_key => entity.id || last_insert_id, @value_column => v}
        row[@order_column] = i if @order_column
        insert_rows << row
      end
      @dataset.multi_insert(insert_rows)
    end

    def post_update(entity, update_entity, rows, data_from_pre_update)
      array = update_entity[@property_name] or return
      @dataset.filter(@foreign_key => entity.id).delete
      insert_rows = []
      array.each_with_index do |v,i|
        row = {@foreign_key => entity.id, @value_column => v}
        row[@order_column] = i if @order_column
        insert_rows << row
      end
      @dataset.multi_insert(insert_rows)
    end
  end
end
