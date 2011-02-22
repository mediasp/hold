module Persistence::Sequel
  class PropertyMapper::UpdatedAt < PropertyMapper::Column
    def build_insert_row(entity, table, row, id=nil)
      row[@column_name] = Time.now if table == @table
    end

    alias :build_update_row :build_insert_row

    def post_insert(entity, rows, last_insert_id=nil)
      entity[@property_name] = rows[@table][@column_name]
    end

    def post_update(id, update_entity, rows, from_pre_update)
      update_entity[@property_name] = rows[@table][@column_name]
    end
  end
end
