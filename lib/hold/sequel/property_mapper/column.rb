module Hold
  module Sequel
    class PropertyMapper
      # Simplest case: maps the property directly to a column on the
      # corresponding table.
      class Column < PropertyMapper
        def initialize(repo, property_name, options = {})
          super(repo, property_name)
          @options = options
        end

        def table
          @table ||= @options.fetch(:table, @repository.main_table)
        end

        def column_name
          @column_name ||= @options.fetch(:column_name, property_name).to_sym
        end

        def column_alias
          @column_alias ||= :"#{table}_#{column_name}"
        end

        def column_qualified
          @column_qualified ||=
            ::Sequel::SQL::QualifiedIdentifier.new(table, column_name)
        end

        def columns_for_select
          [column_qualified]
        end

        def aliases_for_select
          [::Sequel::SQL::AliasedExpression
            .new(column_qualified, column_alias)]
        end

        def tables_for_select
          [table]
        end

        def load_value(row, _id = nil, _version = nil)
          row[column_alias]
        end

        def build_insert_row(entity, with_table, _id = nil)
          if (value = entity[property_name]) && table == with_table
            { column_name => value }
          else
            {}
          end
        end

        alias_method :build_update_row, :build_insert_row

        # for now ignoring the columns_mapped_to, since Identity mapper is the
        # only one for which this matters at present

        def make_filter(value, _columns_mapped_to = nil)
          { column_qualified => value }
        end

        def make_multi_filter(values, _columns_mapped_to = nil)
          { column_qualified => values }
        end
      end
    end
  end
end
