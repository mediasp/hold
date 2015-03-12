module Hold
  module Sequel
    class PropertyMapper
      # Column storing a timestamp everytime the model is updated.
      module UpdatedAt
        def self.new(*args)
          Column.new(*args).extend(self)
        end

        def build_insert_row(_entity, _table, _id = nil)
          { column_name => Time.now }
        end

        alias_method :build_update_row, :build_insert_row

        def post_insert(entity, rows, _last_insert_id = nil)
          entity[@property_name] = rows[table][column_name]
        end

        def post_update(_id, update_entity, rows, _from_pre_update)
          update_entity[@property_name] = rows[table][column_name]
        end
      end
    end
  end
end
