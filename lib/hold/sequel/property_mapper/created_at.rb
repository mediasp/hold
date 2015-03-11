module Hold
  module Sequel
    class PropertyMapper
      # Column with a timestamp when the model is first persisted.
      class CreatedAt < PropertyMapper::Column
        def build_insert_row(_entity, table, row, _id = nil)
          row[@column_name] = Time.now if table == @table
        end

        def build_update_row(_entity, _table, _row)
        end

        def post_insert(entity, rows, _last_insert_id = nil)
          entity[@property_name] = rows[@table][@column_name]
        end
      end
    end
  end
end
