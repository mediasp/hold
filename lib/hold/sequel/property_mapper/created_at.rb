module Hold
  module Sequel
    class PropertyMapper
      # Column with a timestamp when the model is first persisted.
      module CreatedAt
        def self.new(*args)
          Column.new(*args).extend(self)
        end

        def build_insert_row(_entity, _table, _id = nil)
          { column_name => Time.now }
        end

        def build_update_row(_entity, _table)
          {}
        end

        def post_insert(entity, rows, _last_insert_id = nil)
          entity[@property_name] = rows[table][column_name]
        end
      end
    end
  end
end
