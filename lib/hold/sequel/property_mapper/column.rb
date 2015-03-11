module Hold
  module Sequel
    # Simplest case: maps the property directly to a column on the corresponding
    # table.
    class PropertyMapper
      class Column < PropertyMapper
        attr_reader :column_name, :table, :column_alias, :column_qualified

        def initialize(repo, property_name,
                       table: nil,
                       column_name: property_name)
          super(repo, property_name)

          @table = table || @repository.main_table

          @column_name = column_name.to_sym
          @column_alias = :"#{@table}_#{@column_name}"
          @column_qualified =
            ::Sequel::SQL::QualifiedIdentifier.new(@table, @column_name)
        end

        def columns_for_select
          [@column_qualified]
        end

        def aliases_for_select
          [::Sequel::SQL::AliasedExpression
            .new(@column_qualified, @column_alias)]
        end

        def tables_for_select
          [@table]
        end

        def load_value(row, _id = nil, _version = nil)
          row[@column_alias]
        end

        def build_insert_row(entity, table, row, _id = nil)
          (value = entity[@property_name]) &&
            row[@column_name] = value if @table == table
        end

        alias_method :build_update_row, :build_insert_row

        # for now ignoring the columns_mapped_to, since Identity mapper is the
        # only one for which this matters at present

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
