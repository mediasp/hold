module Persistence::Sequel
  # Mixin for Sequel::IdentitySetRepository which adds support for a polymorphic type column which
  # is used to persist the class of the model.
  module WithPolymorphicTypeColumn

    def can_get_class?(model_class)
      @class_to_type_mapping.has_key?(model_class)
    end

    def can_set_class?(model_class)
      @class_to_type_mapping.has_key?(model_class)
    end

    def construct_entity(property_hash, row=nil)
      type_value = row && row[:type] or return super
      klass = @type_to_class_mapping[type_value || @restricted_to_types.first] or
        raise "WithPolymorphicTypeColumn: type column value #{type_value} not found in mapping"
      klass.new(property_hash)
    end

    # ensure we select the type column in addition to any columns for mapped properties,
    # so we know which class to instantiate for each row.
    #
    # If we're restricted to only one class, we don't need to select the type column
    def columns_aliases_and_tables_for_properties(properties)
      columns_by_property, aliased_columns, tables = super
      unless @restricted_to_types && @restricted_to_types.length == 1
        aliased_columns << @aliased_type_column
        tables << @type_column_table unless tables.include?(@type_column_table)
      end
      return columns_by_property, aliased_columns, tables
    end

    # Where 'restricted_to_types' has been set, ensure we add a filter to the where
    # clause restricting to rows with the allowed class (or classes).
    #
    # Except, where one of the tables used is specified in this repo's config as
    # :restricts_type => true, this is taken to mean that (inner) joining to this table
    # effectively acts as this repo's restricted_to_types restriction. hence no additional
    # where clause is needed in order to do this. Helps with Class Table Inheritance.
    def dataset_to_select_tables(*tables)
      if @restricted_to_types && !@tables_restricting_type.values_at(*tables).any?
        super.filter(@qualified_type_column => @restricted_to_types)
      else
        super
      end
    end

    private

      def use_table(name, options={})
        super
        if options[:restricts_type]
          raise "call restrict_type_to before passing :restricts_type => true to use_table" unless @tables_restricting_type
          @tables_restricting_type[name] = true
        end
      end

      def set_type_column(column, table=nil, mapping=nil, inverse_mapping=nil)
        table, mapping = nil, table if table.is_a?(Hash)

        @type_column = column
        @type_column_table = table || @main_table

        @qualified_type_column = Sequel::SQL::QualifiedIdentifier.new(@type_column_table, @type_column)
        @aliased_type_column = Sequel::SQL::AliasedExpression.new(@qualified_type_column, :type)

        @class_to_type_mapping = mapping || {}
        @type_to_class_mapping = inverse_mapping || @class_to_type_mapping.invert
      end

      def restrict_class_to(*klasses)
        restrict_type_to(*@class_to_type_mapping.values_at(*klasses))
      end

      def restrict_type_to(*types)
        @restricted_to_types = types
        @tables_restricting_type = {}
      end

      def insert_row_for_entity(entity, table, id=nil)
        row = super
        if table == @type_column_table
          row[@type_column] = @class_to_type_mapping[entity.class] or
            raise "WithPolymorphicTypeColumn: class #{entity.class} not found in mapping"
        end
        row
      end
  end
end
