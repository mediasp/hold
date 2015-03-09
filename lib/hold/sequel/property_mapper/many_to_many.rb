module Hold
  module Sequel
    # Maps to an array of associated objects stored in another repo, where a
    # :join_table exists with columns for:
    #   - our id property (:left_key)
    #   - other repo's id property (:right_key)
    #   - order position within the list, starting from 0 (:order_column)
    #
    # By default these properties aren't writeable - when they are writeable:
    #
    # (for now at least) the rows of the join table are owned and managed soley by
    # the parent objects via this mapper. The associated objects themselves,
    # however, are free-floating and are not touched during create/update/delete
    # (except optionally to store_new any new ones on create of the parent object,
    # when :auto_store_new => true).
    #
    # If you supply a hash as :filter, this will be used to filter the join table,
    # and will also be merged into any rows inserted into the join table. So if
    # you use it on a writeable property, it needs to be map columns just to
    # values rather than to other sql conditions.
    #
    # NB: for now this does not assume (or do anything special with respect to)
    # the presence of a reciprocal many-to_many property on the target repo. This
    # functionality will need adding later to help figure out the side-effects of
    # changes to a many-to-many property when it comes to cache invalidation, and
    # to ensure that the order given by the order_column is not upset by updates
    # to the corresponding reciprocal property.
    #
    # So:
    #   - Rows are inserted into the join table after the parent object is created
    #   - Rows in the join table are nuked and re-inserted after this property on
    #     the parent object is updated
    #   - Rows in the join table are deleted before the parent object is deleted
    #     (unless :manual_cascade_delete
    #     => false is specified hinting that ON CASCADE DELETE is set on the
    #     foreign key so we needn't bother)
    class PropertyMapper
      class ManyToMany < PropertyMapper
        def self.setter_dependencies_for(options = {})
          features = [*options[:model_class]].map { |klass| [:get_class, klass] }
          { target_repo: [IdentitySetRepository, *features] }
        end

        attr_accessor :target_repo

        attr_reader :join_table, :left_key, :right_key, :order_column, :writeable,
                    :manual_cascade_delete, :auto_store_new, :distinct, :filter,
                    :model_class

        def initialize(repo, property_name,
                       join_table: :"#{repo.main_table}_#{property_name}",
                       left_key: :"#{repo.main_table.to_s.singularize}_id",
                       right_key: :"#{property_name.to_s.singularize}_id",
                       filter: nil, distinct: false, order_column: nil,
                       writeable: false, manual_cascade_delete: true,
                       auto_store_new: false, model_class:)

          super(repo, property_name, &nil)

          @join_table = join_table
          @left_key   = left_key
          @right_key  = right_key
          @qualified_left_key =
            Sequel::SQL::QualifiedIdentifier.new(@join_table, @left_key)
          @qualified_right_key =
            Sequel::SQL::QualifiedIdentifier.new(@join_table, @right_key)

          @filter = filter
          @join_table_dataset = @repository.db[@join_table]
          @distinct = distinct

          if (@order_column = order_column)
            @qualified_order_column =
              Sequel::SQL::QualifiedIdentifier.new(@join_table, @order_column)
          end

          @writeable = writeable
          @manual_cascade_delete = manual_cascade_delete
          @auto_store_new = auto_store_new

          @model_class = model_class

          # in case you want to override anything on the instance:
          yield self if block_given?
        end

        def load_value(_row, id, properties = nil)
          target_repo.query(properties) do |dataset, property_columns|
            id_column = property_columns[target_repo.identity_property].first
            dataset = dataset
                      .join(@join_table, @qualified_right_key => id_column)
                      .filter(@qualified_left_key => id)
            dataset = dataset.filter(@filter) if @filter
            dataset = dataset.distinct if @distinct
            if @qualified_order_column
              dataset.order(@qualified_order_column)
            else
              dataset
            end
          end.to_a
        end

        # efficient batch load for the non-lazy case
        def load_values(_rows, ids = nil, properties = nil, &b)
          query = target_repo.query(properties) do |dataset, mapping|
            id_column = mapping[target_repo.identity_property]
            dataset = dataset
                      .join(@join_table, @qualified_right_key => id_column)
                      .filter(@qualified_left_key => ids)
                      .select(Sequel.as(@qualified_left_key, :_many_to_many_id))
            dataset = dataset.filter(@filter) if @filter
            dataset = dataset.distinct if @distinct
            if @qualified_order_column
              dataset = dataset.order(:_many_to_many_id, @qualified_order_column)
            end
            dataset
          end

          groups = []; id_to_group = {}
          ids.each_with_index { |id, index| id_to_group[id] = groups[index] = [] }
          query.results_with_rows.each do |entity, row|
            id_to_group[row[:_many_to_many_id]] << entity
          end
          groups.each_with_index(&b)
        end

        # find all instances in this repo whose value for this property contains the
        # given member instance
        def get_many_by_member(member)
          @repository.query do |dataset, property_columns|
            id_column = property_columns[@repository.identity_property].first
            dataset = dataset
                      .join(@join_table, @qualified_left_key => id_column)
                      .filter(@qualified_right_key => member.id)
            dataset = dataset.filter(@filter) if @filter
            dataset = dataset.distinct if @distinct
            dataset
          end.to_a
        end

        def insert_join_table_rows(entity, id, values)
          rows = []
          values.each_with_index do |value, index|
            value_id = value.id || if @auto_store_new
                                     target_repo.store_new(value); value.id
                                   else
                                     fail 'value for ManyToMany mapped property'\
                                       "#{@property_name} has no id, and "\
                                       ':auto_store_new not specified'
                                   end
            row = { @left_key => id, @right_key => value_id }
            row[@order_column] = index if @order_column
            row.merge!(@filter) if @filter
            add_denormalized_columns_to_join_table_row(entity, value, row)
            rows << row
          end
          @join_table_dataset.multi_insert(rows)
        end

        # this is a hook for you to override
        def add_denormalized_columns_to_join_table_row(_entity, _value, _row)
        end

        def delete_join_table_rows(id)
          filters = { @left_key => id }
          filters.merge!(@filter) if @filter
          @join_table_dataset.filter(filters).delete
        end

        def post_insert(entity, _rows, insert_id)
          return unless @writeable
          if (values = entity[@property_name])
            insert_join_table_rows(entity, insert_id, values)
          end
        end

        def post_update(entity, update_entity, _rows, _result_from_pre_update = nil)
          return unless @writeable
          update_values = update_entity[@property_name] || (return)
          delete_join_table_rows(entity.id)
          insert_join_table_rows(entity, entity.id, update_values)
        end

        def pre_delete(entity)
          delete_join_table_rows(entity.id) if @manual_cascade_delete
        end
      end
    end
  end
end
