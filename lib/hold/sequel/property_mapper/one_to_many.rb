module Hold
  module Sequel
    class PropertyMapper
      # Maps to an array of associated objects stored in another repo, which has
      # a foreign_key-mapped property pointing at instances of our model class.
      #
      # By default these properties aren't writeable - when they are writeable,
      # the values are treated like wholy-owned sub-components of the parent
      # object.
      #
      # So, objects which are values of this property are:
      #   - Created after the parent object is created
      #   - Created/updated/deleted as appropriate after this property on the
      #     parent object is updated
      #   - Deleted before the parent object is deleted (unless
      #     :manual_cascade_delete => false is specified hinting that ON CASCADE
      #     DELETE is set on the foreign key so we needn't bother)
      #
      # On update:
      # We allow you to re-order and/or update the existing values while
      # maintaining their identities, remove some objects which were in the
      # collection before (which get deleted) and possibly throw in new objects
      # too (which get created), but you can't throw something in there which
      # was previously attached to some other object, for the same reason that
      # this doesn't fly on insert.
      #
      # If you specify a denormalized_count_column, this will be used to store
      # the count of associated objects on a column on the main table of the
      # parent object.
      class OneToMany < PropertyMapper
        attr_accessor :target_repo

        attr_reader :writeable, :manual_cascade_delete, :order_property,
                    :order_direction, :foreign_key_property_name,
                    :denormalized_count_column, :model_class

        def initialize(repo, property_name, options = {})
          super

          @foreign_key_property_name = options[:property]
          @model_class = options[:model_class]
          @writeable = options[:writeable] || false
          @order_property = options[:order_property]
          @order_direction = options[:order_direction] || :asc

          @manual_cascade_delete =
            (value = options[:manual_cascade_delete].nil?) ? true : value

          @denormalized_count_column = options[:denormalized_count_column]
        end

        def extra_properties
          @extra_properties ||=
            begin
              extra_properties = { @foreign_key_property_name => true }
              extra_properties[@order_property] = true if @order_property
              extra_properties
            end
        end

        def foreign_key_mapper
          @foreign_key_mapper ||=
            target_repo.mapper(@foreign_key_property_name).tap do |mapper|
              unless mapper.is_a?(PropertyMapper::ForeignKey)
                fail ExpectedForeignKey @foreign_key_property_name
              end
              model = @repository.model_class
              unless mapper.target_repo.can_get_class?(model)
                fail MismatchedTarget target_repo, model
              end
            end
        end

        def load_value(_row, id, properties = nil)
          properties = properties_to_load(properties)

          target_repo.query(properties) do |dataset, mapping|
            filter = id_filter(id, mapping)

            dataset.filter(filter).tap do |ds|
              if @order_property
                ds.order(Sequel.send(@order_direction, @order_property))
              end
            end
          end.to_a
        end

        def load_values(_rows, ids, properties = nil)
          properties = properties_to_load(properties)

          query = load_values_query(ids, properties)

          groups = ids.map { [] }
          id_to_group = Hash.new([])

          query.results_with_rows.each do |entity, row|
            id_to_group[row[:_one_to_many_id]] << entity
          end

          groups.each_with_index { |id, index| yield id, index }
        end

        def load_values_query(ids, properties)
          target_repo.query(properties) do |dataset, mapping|
            dataset.filter(ids_filter(ids, mapping))
              .select(foreign_key_mapper .column_qualified.as(:_one_to_many_id))
              .tap do |ds|
                if @order_property
                  ds.order(:_one_to_many_id, target_repo.mapper(@order_property)
                           .column_qualified.send(@order_direction))
                end
              end
          end
        end

        def id_filter(id, mapping)
          foreign_key_mapper
            .make_filter_by_id(id, mapping[@foreign_key_property_name])
        end

        def ids_filter(ids, mapping)
          foreign_key_mapper
            .make_filter_by_ids(ids, mapping[@foreign_key_property_name])
        end

        def properties_to_load(properties = nil)
          (properties || target_repo.default_properties).merge(extra_properties)
        end

        # adds a join to the target_repo's table, onto a dataset from the
        # mapper's repository.
        def add_join(dataset)
          # FIXME: doesn't take any care to pick a unique alias for the table
          # when joining to it
          # FIXME: doesn't use mapping to determine id_column

          dataset
            .join(target_repo.table_name,
                  foreign_key_mapper.column_name =>
            @repository.identity_mapper.column_name)
        end

        # help the parent repo find instances whose value for this property
        # contains a particular member. since we're one-to-many rather than
        # many-to-many, this is relatively simple. we just get the foreign key
        # property on the proposed member, see if it's set to anything, and if
        # so if that thing exists within our repo. if it does then it's the only
        # such object, because the member's foreign key can only point at one
        # thing.
        def get_many_by_member(member)
          if member.key?(@foreign_key_property_name)
            object = member[@foreign_key_property_name]
            # we might not actually contain it
            [object] if object && @repository.contains?(object)
          else
            object = target_repo
                     .get_property(member, @foreign_key_property_name)
            # we know we contain it since the target_repo's foreign_key_mapper
            # has us as its target_repo
            [object] if object
          end
        end

        def build_insert_row(entity, table, _id = nil)
          unless @denormalized_count_column && table == @repository.main_table
            return {}
          end
          values = entity[@property_name]
          { @denormalized_count_column => (values ? values.length : 0) }
        end

        def post_insert(entity, _rows, _insert_id)
          return unless @writeable

          values = entity[@property_name] || (return)

          # save the assocatied objects!
          values.each_with_index do |value, index|
            # if we allowed this you would potentially be detaching the object
            # from its previous parent, but then we'd have to apply hooks etc to
            # that object too, so rather avoid:
            fail "OneToMany mapper for #{@property_name}: already-persisted "\
              'values are not supported on insert' if value.id
            set_foreign_key_and_order_properties_on_value(entity, value, index)
            target_repo.store_new(value)
          end
        end

        def set_foreign_key_and_order_properties_on_value(entity, value, index)
          set_foreign_key(entity, value)
          set_order_property(value, index)
        end

        # ensure their corresponding foreign key mapped property points back at
        # us
        def set_foreign_key(entity, value)
          if (existing_value = value[@foreign_key_property_name])
            # the associated object has a foreign key mapped property pointing
            # at something else.
            #
            # we could have config to allow it to go and update the foreign key
            # in cases like this, but could be messy in the presence of order
            # columns etc.
            unless existing_value == entity
              fail ForeignKeyConflict @property_name, @foreign_key_property_name
            end
          else
            value[@foreign_key_property_name] = entity
          end
        end

        # ensure their order_property corresponds to their order in the array,
        # at least for new members. (in an update, existing members may change
        # order)
        def set_order_property(value, index)
          if !value.id && (existing_index = value[@order_property])
            unless existing_index == index
              fail OrderPropertyConflict @property_name, @order_property
            end
          else
            value[@order_property] = index
          end if @order_property == :position
        end

        def pre_update(entity, update_entity)
          # if an update is specified for this property, find out what the
          # existing values are first:
          load_value(nil, entity.id) if @writeable &&
                                        update_entity[@property_name]
        end

        def build_update_row(entity, table, row, _id = nil)
          unless @denormalized_count_column && table == @repository.main_table
            return {}
          end

          if (values = entity[@property_name])
            { @denormalized_count_column => values.length }
          else
            {}
          end
        end

        def post_update(entity, update_entity, _rows, values_before)
          return unless @writeable
          update_values = update_entity[@property_name] || (return)
          # delete any values which are no longer around:
          (values_before - update_values)
            .each { |value| target_repo.delete(value) }
          # insert any new ones / update any existing ones which remain:
          update_values.each_with_index do |value, index|
            fail AlreadyPersisted if value.id && !values_before.include?(value)

            set_foreign_key_and_order_properties_on_value(entity, value, index)
            # this will insert any new values, or update any existing ones.
            target_repo.store(value)
          end
        end

        def pre_delete(entity)
          return unless @manual_cascade_delete
          load_value(nil, entity.id).each { |value| target_repo.delete(value) }
        end
      end
    end
  end
end
