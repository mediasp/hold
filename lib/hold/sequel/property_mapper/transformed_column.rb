module Hold
  module Sequel
    # A column mapper which allows you to supply a customized pair of
    # transformations between the sequel values persisted in the db, and the
    # values used for the outward-facing model property
    class PropertyMapper
      class TransformedColumn < PropertyMapper::Column
        def initialize(repo, property_name, to_sequel: nil, from_sequel: nil)
          super(repo, property_name, {})
          @to_sequel = to_sequel
          @from_sequel = from_sequel
        end

        def to_sequel(value)
          @to_sequel.call(value)
        end

        def from_sequel(value)
          @from_sequel.call(value)
        end

        def load_value(row, _id = nil, _properties = nil)
          from_sequel(row[@column_alias])
        end

        def build_insert_row(entity, table, row, _id = nil)
          row[@column_name] =
            to_sequel(entity[@property_name]) if @table == table &&
                                                 entity.key?(@property_name)
        end

        alias_method :build_update_row, :build_insert_row

        def make_filter(value, _columns_mapped_to = nil)
          { @column_qualified => to_sequel(value) }
        end

        def make_multi_filter(values, _columns_mapped_to = nil)
          { @column_qualified => values.map { |v| to_sequel(v) } }
        end
      end
    end
  end
end
