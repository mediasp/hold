module Hold
  module Sequel
    class IdentitySetRepository
      # Subclass of Sequel::IdentitySetRepository which adds support for a
      # polymorphic type column which is used to persist the class of the model.
      class WithPolymorphicTypeColumn < IdentitySetRepository
        class << self
          def type_column
            @type_column ||= superclass.type_column
          end

          def type_column_table
            @type_column_table ||= superclass.type_column_table
          end

          def class_to_type_mapping
            @class_to_type_mapping ||=
              if superclass < WithPolymorphicTypeColumn
                superclass.class_to_type_mapping
              end
          end

          def type_to_class_mapping
            @type_to_class_mapping ||=
              if superclass < WithPolymorphicTypeColumn
                superclass.type_to_class_mapping
              end
          end

          def restricted_to_types
            @restricted_to_types ||=
              if superclass < WithPolymorphicTypeColumn
                superclass.restricted_to_types
              end
          end

          def supported_classes
            if restricted_to_types
              type_to_class_mapping.values_at(*restricted_to_types)
            else
              class_to_type_mapping.keys
            end
          end

          private

          def set_type_column(column, table, mapping = nil)
            unless superclass == WithPolymorphicTypeColumn
              fail 'set_type_column only on the topmost subclass'
            end

            table, mapping = tables.first.first, table if table.is_a?(Hash)
            @type_column = column
            @type_column_table = table
            @class_to_type_mapping = mapping
            @type_to_class_mapping = mapping.invert
          end

          def model_class=(model_class)
            @model_class = model_class
            unless class_to_type_mapping
              fail 'set_type_column before set_model_class'
            end

            klasses = class_to_type_mapping.keys
                      .select { |klass| klass <= model_class }

            @restricted_to_types = if klasses.size < @class_to_type_mapping.size
                                     class_to_type_mapping.values_at(*klasses)
                                   end
          end

          alias_method :set_model_class, :model_class=
        end

        def qualified_type_column
          @qualified_type_column ||=
            begin
              klass = self.class
              ::Sequel::SQL::QualifiedIdentifier.new(klass.type_column_table,
                                                     klass.type_column)
            end
        end

        def aliased_type_column
          @aliased_type_column ||=
            ::Sequel::SQL::AliasedExpression.new(qualified_type_column, :type)
        end

        def restricted_to_types
          self.class.restricted_to_types
        end

        def tables_restricting_type
          @tables_restricting_type ||=
            self.class.tables.each_with_object({}) do |(name, options), hash|
              hash[name] = true if options[:restricts_type]
            end
        end

        def can_get_class?(model_class)
          self.class.supported_classes.include?(model_class)
        end

        def can_set_class?(model_class)
          self.class.supported_classes.include?(model_class)
        end

        def construct_entity(property_hash, row = nil)
          type_value = row && row[:type] || (return super)
          klass =
            self.class.type_to_class_mapping[type_value] ||
            (fail "WithPolymorphicTypeColumn: type column value #{type_value}" \
                  ' not found in mapping')
          klass.new(property_hash)
        end

        # This optimisation has to be turned off for polymorphic repositories,
        # since even if we know the ID, we have to query the db to find out the
        # appropriate class to construct the object as.
        def can_construct_from_id_alone?(properties)
          super && restricted_to_types && restricted_to_types.length == 1
        end

        # ensure we select the type column in addition to any columns for mapped
        # properties, so we know which class to instantiate for each row.
        #
        # If we're restricted to only one class, we don't need to select the
        # type column

        def aliases_by_property(properties)
          aliased_columns = super
          unless restricted_to_types && restricted_to_types.length == 1
            aliased_columns << aliased_type_column
          end
          aliased_columns
        end

        def tables_by_property(properties)
          tables = super
          unless restricted_to_types && restricted_to_types.length == 1
            type_column_table = self.class.type_column_table
            unless tables.include?(type_column_table)
              tables << type_column_table
            end
          end
          tables
        end

        # Where 'restricted_to_types' has been set, ensure we add a filter to
        # the where clause restricting to rows with the allowed class (or
        # classes).
        #
        # Except, where one of the tables used is specified in this repo's
        # config as :restricts_type => true, this is taken to mean that (inner)
        # joining to this table effectively acts as this repo's
        # restricted_to_types restriction. hence no additional where clause is
        # needed in order to do this. Helps with Class Table Inheritance.
        def dataset_to_select_tables(*tables)
          if restricted_to_types &&
             !tables_restricting_type.values_at(*tables).any?
            super.filter(qualified_type_column => restricted_to_types)
          else
            super
          end
        end

        private

        def insert_row_for_entity(entity, table, id = nil)
          row = super
          this_class = self.class
          entity_class = entity.class
          if table == this_class.type_column_table
            row[this_class.type_column] =
              this_class.class_to_type_mapping[entity_class] ||
              (fail "WithPolymorphicTypeColumn: class #{entity_class} not" \
                     ' found in mapping')
          end
          row
        end
      end
    end
  end
end
