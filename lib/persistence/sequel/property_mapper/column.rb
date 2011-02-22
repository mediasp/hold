module Persistence::Sequel
  # Simplest case: maps the property directly to a column on the corresponding table.
  class PropertyMapper::Column < PropertyMapper
    attr_reader :column_name, :table, :column_alias, :column_qualified, :columns_aliases_and_tables_for_select

    def initialize(repo, property_name, options)
      super(repo, property_name)

      @table = options[:table] || @repository.main_table

      @column_name = (options[:column_name] || property_name).to_sym
      @column_alias = :"#{@table}_#{@column_name}"
      @column_qualified = Sequel::SQL::QualifiedIdentifier.new(@table, @column_name)
      @columns_aliases_and_tables_for_select = [
        [@column_qualified],
        [Sequel::SQL::AliasedExpression.new(@column_qualified, @column_alias)],
        [@table]
      ]
    end

    def load_value(row, id=nil, version=nil)
      row[@column_alias]
    end

    def build_insert_row(entity, table, row, id=nil)
      row[@column_name] = entity[@property_name] if @table == table && entity.has_key?(@property_name)
    end

    alias :build_update_row :build_insert_row

    # for now ignoring the columns_mapped_to, since Identity mapper is the only one
    # for which this matters at present

    def make_filter(value, columns_mapped_to=nil)
      {@column_qualified => value}
    end

    def make_multi_filter(values, columns_mapped_to=nil)
      {@column_qualified => values}
    end
  end
end
