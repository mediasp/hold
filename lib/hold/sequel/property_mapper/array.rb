module Hold
  module Sequel
    class PropertyMapper
      # A property which is an array of primitive values. Persisted 'all in one
      # go' in a separate table.
      class Array < PropertyMapper
        attr_reader :table, :foreign_key, :value_column

        def initialize(repo, property_name, options = {})
          super(repo, property_name)

          main_table = repo.main_table

          @table = options.fetch(:table, :"#{main_table}_#{property_name}")
          @foreign_key =
            options.fetch(:foreign_key, :"#{main_table.to_s.singularize}_id")

          @value_column = options.fetch(:value_column, :value)
          @order_column = options[:order_column]

          @dataset = @repository.db[@table]
        end

        def load_value(_row = nil, id = nil, _properties = nil)
          select_v.filter(@foreign_key => id).map { |row| row[:value] }
        end

        def load_values(_rows = nil, ids = nil, _properties = nil, &block)
          results = Hash.new { |h, k| h[k] = [] }
          select_all.filter(@foreign_key => ids).each do |row|
            results[row[:id]] << row[:value]
          end
          result.values_at(*ids).each_with_index(&block)
        end

        def pre_delete(entity)
          @dataset.filter(@foreign_key => entity.id).delete
        end

        def post_insert(entity, _rows, last_insert_id = nil)
          array = entity[@property_name] || (return)
          insert_rows = []
          array.each_with_index do |v, i|
            row = { @foreign_key => entity.id || last_insert_id,
                    @value_column => v }
            row[@order_column] = i if @order_column
            insert_rows << row
          end
          @dataset.multi_insert(insert_rows)
        end

        def post_update(entity, update_entity, _rows, _data_from_pre_update)
          array = update_entity[@property_name] || (return)
          id = entity.id
          @dataset.filter(@foreign_key => id).delete
          insert_rows = []
          array.each_with_index do |v, i|
            row = { @foreign_key => id, @value_column => v }
            row[@order_column] = i if @order_column
            insert_rows << row
          end
          @dataset.multi_insert(insert_rows)
        end

        private

        def select_v
          @select_v ||=
            begin
              select_v = @repository.db[@table]
                         .select(Sequel.as(@value_column, :value))
              select_v.order(@order_column) if @order_column
              select_v
            end
        end

        def select_all
          @select_all ||=
            begin
              select_all = @repository.db[@table].select(
                Sequel.as(@value_column, :value),
                Sequel.as(@foreign_key, :id))
              select_all.order(@order_column) if @order_column
              select_all
            end
        end
      end
    end
  end
end
