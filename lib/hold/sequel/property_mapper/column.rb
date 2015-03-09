module Hold
  module Sequel
    # Simplest case: maps the property directly to a column on the corresponding
    # table.
    class PropertyMapper
      class Column < PropertyMapper
        attr_reader :column_name, :table, :column_alias, :column_qualified,
                    :columns_aliases_and_tables_for_select

        def initialize(repo, property_name,
                       table: nil,
                       column_name: property_name)
          super(repo, property_name)

          @table = table || @repository.main_table

          @column_name = column_name.to_sym
          @column_alias = :"#{@table}_#{@column_name}"
          @column_qualified =
            ::Sequel::SQL::QualifiedIdentifier.new(@table, @column_name)

          @columns_aliases_and_tables_for_select = [
            [@column_qualified],
            [::Sequel::SQL::AliasedExpression.new(@column_qualified, @column_alias)],
            [@table]
          ]
        end

        def load_value(row, _id = nil, _version = nil)
          row[@column_alias]
        end

        def build_insert_row(entity, table, row, _id = nil)
          if @table == table && entity.key?(@property_name)
            row[@column_name] = entity[@property_name]
          end
        end

        alias_method :build_update_row, :build_insert_row

        # for now ignoring the columns_mapped_to, since Identity mapper is the only
        # one for which this matters at present

        def make_filter(value, _columns_mapped_to = nil)
          { @column_qualified => value }
        end

        def make_multi_filter(values, _columns_mapped_to = nil)
          { @column_qualified => values }
        end
      end
    end
  end
end
