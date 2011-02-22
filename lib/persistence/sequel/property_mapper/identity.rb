module Persistence::Sequel
  class PropertyMapper::Identity < PropertyMapper
    def columns_aliases_and_tables_for_select(preferred_table=@repository.main_table)
      qualified = qualified_column_name(preferred_table)
      return [qualified], [qualified.as(:id)], [preferred_table]
    end

    def qualified_column_name(preferred_table=@repository.main_table)
      id_column = @repository.table_id_column(preferred_table)
      Sequel::SQL::QualifiedIdentifier.new(preferred_table, id_column)
    end

    # the ID needs to go into insert rows for /all/ tables of the repo
    def build_insert_row(entity, table, row, id=nil)
      id ||= entity[@property_name] or return
      id_column = @repository.table_id_column(table)
      row[id_column] = id
    end

    # we don't update the ID - considered immutable
    def build_update_row(entity, table, row)
    end

    # After a successful insert, we assign the last_insert_id back onto the entity's id property:
    def post_insert(entity, rows, last_insert_id=nil)
      entity[@property_name] = last_insert_id if last_insert_id
    end

    def load_value(row, id=nil, version=nil)
      row[:id]
    end

    def make_filter(value, columns_mapped_to)
      {columns_mapped_to.first => value}
    end

    def make_multi_filter(values, columns_mapped_to)
      {columns_mapped_to.first => values}
    end
  end
end
