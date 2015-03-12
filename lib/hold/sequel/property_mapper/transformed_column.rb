module Hold
  module Sequel
    class PropertyMapper
      # A column mapper which allows you to supply a customized pair of
      # transformations between the sequel values persisted in the db, and the
      # values used for the outward-facing model property
      module TransformedColumn
        def self.new(repo, property_name, options = {})
          column = Column.new(repo, property_name)
            .extend(TransformedColumn)

          column.to_sequel = options.fetch(:to_sequel)
          column.from_sequel = options.fetch(:from_sequel)

          column
        end

        attr_writer :to_sequel, :from_sequel

        def to_sequel(value)
          @to_sequel.call(value)
        end

        def from_sequel(value)
          @from_sequel.call(value)
        end

        def load_value(row, _id = nil, _properties = nil)
          from_sequel(row[column_alias])
        end

        def build_insert_row(entity, with_table, _id = nil)
          if with_table == table && entity.key?(@property_name)
            { column_name => to_sequel(entity[@property_name]) }
          else
            {}
          end
        end

        alias_method :build_update_row, :build_insert_row

        def make_filter(value, _columns_mapped_to = nil)
          { column_qualified => to_sequel(value) }
        end

        def make_multi_filter(values, _columns_mapped_to = nil)
          { column_qualified => values.map { |v| to_sequel(v) } }
        end
      end
    end
  end
end
