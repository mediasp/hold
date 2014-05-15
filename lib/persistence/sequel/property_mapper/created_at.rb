module Hold::Sequel
  class PropertyMapper::CreatedAt < PropertyMapper::Column
    def build_insert_row(entity, table, row, id=nil)
      row[@column_name] = Time.now if table == @table
    end

    def build_update_row(entity, table, row)
    end

    def post_insert(entity, rows, last_insert_id=nil)
      entity[@property_name] = rows[@table][@column_name]
    end
  end
end
