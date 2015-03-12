module Hold
  module Sequel
    class PropertyMapper
      # Maps to an array of associated objects stored in another repo, where a
      # :join_table exists with columns for:
      #   - our id property (:left_key)
      #   - other repo's id property (:right_key)
      #   - order position within the list, starting from 0 (:order_column)
      #
      # By default these properties aren't writeable - when they are writeable:
      #
      # (for now at least) the rows of the join table are owned and managed
      # soley by the parent objects via this mapper. The associated objects
      # themselves, however, are free-floating and are not touched during
      # create/update/delete (except optionally to store_new any new ones on
      # create of the parent object, when :auto_store_new => true).
      #
      # If you supply a hash as :filter, this will be used to filter the join
      # table, and will also be merged into any rows inserted into the join
      # table. So if you use it on a writeable property, it needs to be map
      # columns just to values rather than to other sql conditions.
      #
      # NB: for now this does not assume (or do anything special with respect
      # to) the presence of a reciprocal many-to_many property on the target
      # repo. This functionality will need adding later to help figure out the
      # side-effects of changes to a many-to-many property when it comes to
      # cache invalidation, and to ensure that the order given by the
      # order_column is not upset by updates to the corresponding reciprocal
      # property.
      #
      # So:
      #   - Rows are inserted into the join table after the parent object is
      #     created
      #   - Rows in the join table are nuked and re-inserted after this
      #     property on the parent object is updated
      #   - Rows in the join table are deleted before the parent object is
      #     deleted (unless :manual_cascade_delete
      #     => false is specified hinting that ON CASCADE DELETE is set on the
      #     foreign key so we needn't bother)
      class ManyToMany < PropertyMapper
        attr_accessor :target_repo

        def initialize(repo, property, options = {})
          super(repo, property, &nil)
          @options = options
          # in case you want to override anything on the instance:
          yield self if block_given?
        end

        def join_table
          @join_table ||= @options.fetch(:join_table,
                                         :"#{repo.main_table}_#{property}")
        end

        def left_key
          @left_key ||=
            @options.fetch(:left_key, :"#{repo.main_table.to_s.singularize}_id")
        end

        def right_key
          @right_key ||=
            @options.fetch(:right_key, :"#{property.to_s.singularize}_id")
        end

        def filter
          @filter ||= @options[:filter]
        end

        def distinct
          @distinct.nil? ? @options.fetch(:distinct, false) : @distinct
        end

        def order_column
          if @order_column.nil? then @options.fetch(:order_column, false)
          else @order_column
          end
        end

        def writeable
          @writeable.nil? ? @options.fetch(:writeable, false) : @writeable
        end

        def manual_cascade_delete
          @manual_cascade_delete ||=
            @options.fetch(:manual_cascade_delete, true)
        end

        def auto_store_new
          if @auto_store_new.nil? then @options.fetch(:auto_store_new, false)
          else @auto_store_new
          end
        end

        def model_class
          @model_class ||= @options.fetch(:model_class)
        end

        def join_table_dataset
          @join_table_dataset ||= @repository.db[join_table]
        end

        def qualified_left_key
          @qualified_left_key ||=
            Sequel::SQL::QualifiedIdentifier.new(join_table, left_key)
        end

        def qualified_right_key
          @qualified_right_key ||=
            Sequel::SQL::QualifiedIdentifier.new(join_table, right_key)
        end

        def qualified_order_column
          @qualified_order_column ||=
            if order_column
              Sequel::SQL::QualifiedIdentifier.new(join_table, order_column)
            end
        end

        def load_value(_row, id, properties = nil)
          target_repo.query(properties) do |dataset, property_columns|
            id_column = property_columns[target_repo.identity_property].first
            load_value_dataset(dataset, id_column, id)
              .tap do |ds|
                ds.order(qualified_order_column) if qualified_order_column
              end
          end.to_a
        end

        # efficient batch load for the non-lazy case
        def load_values(_rows, ids = nil, properties = nil)
          query = load_values_query(properties)

          groups = []
          id_to_group = {}
          ids.each_with_index do |id, index|
            id_to_group[id] = groups[index] = []
          end
          query.results_with_rows.each do |entity, row|
            id_to_group[row[:_many_to_many_id]] << entity
          end
          groups.each_with_index(&b)
        end

        def load_values_query(properties)
          target_repo.query(properties) do |dataset, mapping|
            id_column = mapping[target_repo.identity_property]
            load_value_dataset(dataset, id_column, id)
              .tap do |ds|
                if qualified_order_column
                  ds.order(:_many_to_many_id, qualified_order_column)
                end
              end
          end
        end

        def load_value_dataset(dataset, id_column, id)
          dataset.join(join_table, qualified_right_key => id_column)
            .filter(qualified_left_key => id)
            .tap { |ds| ds.filter(filter) if filter }
            .tap { |ds| ds.distinct if distinct }
        end

        # find all instances in this repo whose value for this property contains
        # the given member instance
        def get_many_by_member(member)
          @repository.query do |dataset, property_columns|
            id_column = property_columns[@repository.identity_property].first
            dataset = dataset
                      .join(join_table, qualified_left_key => id_column)
                      .filter(qualified_right_key => member.id)
            dataset = dataset.filter(filter) if filter
            dataset = dataset.distinct if distinct
            dataset
          end.to_a
        end

        def insert_join_table_rows(entity, id, values)
          rows = values.each_with_object([]).with_index do |(v, a), i|
            value_id = id_for_value(v)
            a << { left_key => id, right_key => value_id }
                 .tap { |row| row[order_column] = i if order_column }
                 .tap { |row| row.merge!(filter) if filter }
                 .tap do |row|
                   add_denormalized_columns_to_join_table_row(entity, v, row)
                 end
          end
          join_table_dataset.multi_insert(rows)
        end

        def id_for_value(value)
          value.id ||
            if auto_store_new
              target_repo.store_new(value) && value
            else
              fail NoID @property_name
            end
        end

        # this is a hook for you to override
        def add_denormalized_columns_to_join_table_row(_entity, _value, _row)
        end

        def delete_join_table_rows(id)
          filters = { left_key => id }
          filters.merge!(filter) if filter
          join_table_dataset.filter(filters).delete
        end

        def post_insert(entity, _rows, insert_id)
          return unless writeable
          (values = entity[@property_name]) &&
            insert_join_table_rows(entity, insert_id, values)
        end

        def post_update(entity, update_entity, _rows, _res_pre_update = nil)
          return unless writeable
          update_values = update_entity[@property_name] || (return)
          id = entity.id
          delete_join_table_rows(id)
          insert_join_table_rows(entity, id, update_values)
        end

        def pre_delete(entity)
          delete_join_table_rows(entity.id) if manual_cascade_delete
        end
      end
    end
  end
end
