module Hold
  module Sequel
    class PropertyMapper
      # Maps to an associated object which is fetched by id from a target
      # repository using a foriegn key column
      class ForeignKey < PropertyMapper
        attr_accessor :target_repo

        attr_reader :column_alias, :column_name, :table, :column_qualified,
                    :auto_store_new, :model_class

        # auto_store_new: where the value for this property is an object without
        # an ID, automatically store_new the object in the target_repo before
        # trying to store the object in question with this foreign key property.
        # In the absence of this setting, values without an ID will cause an
        # exception
        def initialize(repo, property_name, options = {})
          super(repo, property_name)

          @table = options.fetch(:table, @repository.main_table)
          @column_name = options.fetch(:column_name, :"#{property_name}_id")
          @column_alias = :"#{@table}_#{@column_name}"
          @column_qualified =
            ::Sequel::SQL::QualifiedIdentifier.new(@table, @column_name)

          @auto_store_new = options.fetch(:auto_store_new, false)
          @model_class = options.fetch(:model_class)
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

        def load_value(row, _id = nil, properties = nil)
          (fkey = row[@column_alias]) &&
            target_repo.get_by_id(fkey, properties: properties)
        end

        def ensure_value_has_id_where_present(value)
          if @auto_store_new
            target_repo.store_new(value)
          else
            fail "value for ForeignKey mapped property #{@property_name} "\
              'has no id, and :auto_store_new not specified'
          end if value && !value.id
        end

        def pre_insert(entity)
          ensure_value_has_id_where_present(entity[@property_name])
        end

        def pre_update(_entity, update_entity)
          ensure_value_has_id_where_present(update_entity[@property_name])
        end

        def build_insert_row(entity, table, _id = nil)
          if (value = entity[@property_name]) && @table == table
            { @column_name => value.id }
          else
            {}
          end
        end
        alias_method :build_update_row, :build_insert_row

        # for now ignoring the columns_mapped_to, since Identity mapper is the
        # only one for which this matters at present

        def make_filter(value, _columns_mapped_to = nil)
          { @column_qualified => value && value.id }
        end

        def make_multi_filter(values, _columns_mapped_to = nil)
          { @column_qualified => values.map(&:id) }
        end

        def make_filter_by_id(id, _columns_mapped_to = nil)
          { @column_qualified => id }
        end

        def make_filter_by_ids(ids, _columns_mapped_to = nil)
          { @column_qualified => ids }
        end

        # efficient batch load which takes advantage of get_many_by_ids on the
        # target repo
        def load_values(rows, _ids = nil, properties = nil)
          fkeys = rows.map { |row| row[@column_alias] }
          non_nil_fkeys = fkeys.compact
          non_nil_fkey_results =
            if non_nil_fkeys.empty? then []
            else
              target_repo.get_many_by_ids(non_nil_fkeys, properties: properties)
            end
          fkeys.each_with_index do |fkey, index|
            yield(fkey ? non_nil_fkey_results.shift : nil, index)
          end
        end
      end
    end
  end
end
