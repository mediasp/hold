module Hold
  module Sequel
    class PropertyMapper
      # ID column
      class Identity < PropertyMapper
        def columns_for_select(preferred_table = nil)
          [qualified_column_name(preferred_table)]
        end

        def aliases_for_select(preferred_table = nil)
          [qualified_column_name(preferred_table).as(:id)]
        end

        def tables_for_select(preferred_table = nil)
          [preferred_table || @repository.main_table]
        end

        def qualified_column_name(preferred_table)
          preferred_table ||= @repository.main_table
          id_column = @repository.table_id_column(preferred_table)
          ::Sequel::SQL::QualifiedIdentifier.new(preferred_table, id_column)
        end

        # the ID needs to go into insert rows for /all/ tables of the repo
        def build_insert_row(entity, table, id = nil)
          id ||= entity[@property_name] || (return {})
          id_column = @repository.table_id_column(table)
          { id_column => id }
        end

        # we don't update the ID - considered immutable
        def build_update_row(_entity, _table)
          {}
        end

        # After a successful insert, we assign the last_insert_id back onto the
        # entity's id property:
        def post_insert(entity, _rows, last_insert_id = nil)
          entity[@property_name] = last_insert_id if last_insert_id
        end

        def load_value(row, _id = nil, _version = nil)
          row[:id]
        end

        def make_filter(value, columns_mapped_to)
          { columns_mapped_to.first => value }
        end

        def make_multi_filter(values, columns_mapped_to)
          { columns_mapped_to.first => values }
        end
      end
    end
  end
end
