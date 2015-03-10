require 'wirer'

module Hold
  module Sequel
    def self.IdentitySetRepository(model_class, main_table = nil)
      Class.new(IdentitySetRepository) do
        set_model_class model_class

        use_table(main_table, id_column: :id, id_sequence: true) if main_table

        yield self if block_given?
      end
    end

    class IdentitySetRepository
      include Hold::IdentitySetRepository

      class << self
        def model_class
          @model_class ||=
            (superclass.model_class if superclass < IdentitySetRepository)
        end

        def tables
          @tables ||=
            (superclass < IdentitySetRepository ? superclass.tables.dup : [])
        end

        def property_mapper_args
          @property_mapper_args ||= if superclass < IdentitySetRepository
                                      superclass.property_mapper_args.dup
                                    else
                                      []
                                    end
        end

        include Wirer::Factory::Interface

        def constructor_dependencies
          { database: Wirer::Dependency.new_from_args(Sequel::Database) }
        end

        def new_from_dependencies(deps, *p)
          new(deps[:database], *p)
        end

        def provides_class
          self
        end

        def provides_features
          [[:get_class, model_class]]
        end

        def setter_dependencies
          dependencies = { observers: Wirer::Dependency.new(
            module: Hold::Sequel::RepositoryObserver,
            features: [[:observes_repo_for_class, model_class]],
            multiple: true,
            optional: true
          ) }
          property_mapper_args
            .each do |property_name, mapper_class, options, block|
              mapper_class.setter_dependencies_for(options, &block)
                .each do |dep_name, dep_args|
                  mapper_dep_name = :"#{property_name}__#{dep_name}"
                  dependencies[mapper_dep_name] =
                    Wirer::Dependency.new_from_arg_or_args_list(dep_args)
                end
            end
          dependencies
        end

        def inject_dependency(instance, dep_name, value)
          if dep_name == :observers
            value.each { |observer| instance.add_observer(observer) }
          else
            mapper_name, dep_name = dep_name.to_s.split('__', 2)
            instance.mapper(mapper_name.to_sym).send("#{dep_name}=", value)
          end
        end

        def set_model_class(model_class)
          @model_class = model_class
        end

        def use_table(name, options = {})
          options[:id_column] ||= :id
          tables << [name.to_sym, options.freeze]
        end

        def map_property(property_name, mapper_class, options = {}, &block)
          fail unless mapper_class <= PropertyMapper
          property_mapper_args << [property_name, mapper_class, options, block]
        end

        # Some convenience mapper DSL methods for each of the mapper subclasses:
        { column: 'Column',      foreign_key: 'ForeignKey',
          one_to_many: 'OneToMany',   many_to_many: 'ManyToMany',
          created_at: 'CreatedAt',   updated_at: 'UpdatedAt',
          hash_property: 'Hash',        array_property: 'Array',
          transformed_column: 'TransformedColumn',
          custom_query: 'CustomQuery',
          custom_query_single_value: 'CustomQuerySingleValue'
        }.each do |name, mapper_class|
          class_eval <<-EOS, __FILE__, __LINE__ + 1
def map_#{name}(property_name, options={}, &block)
  map_property(property_name, PropertyMapper::#{mapper_class}, options, &block)
end
          EOS
        end
      end

      def model_class
        self.class.model_class
      end

      attr_reader :db, :main_table, :property_mappers, :identity_property,
                  :identity_mapper, :id_sequence_table, :default_properties

      def initialize(db)
        fail 'abstract superclass' if instance_of?(IdentitySetRepository)
        @db = db

        @tables = []
        @tables_id_columns = {}
        self.class.tables.each do |name, options|
          @tables << name
          @tables_id_columns[name] = options[:id_column]
          @id_sequence_table = name if options[:id_sequence]
          @main_table = name if options[:default]
        end
        @main_table ||= @tables.first

        @property_mappers = {}
        @default_properties = {}

        # map the identity_property
        @identity_property = :id # TODO: make this configurable
        @identity_mapper = @property_mappers[@identity_property] =
          PropertyMapper::Identity.new(self, @identity_property)

        self.class.property_mapper_args
          .each do |property_name, mapper_class, options, block|
            @property_mappers[property_name] =
              mapper_class.new(self, property_name, options, &block)

            case
            when mapper_class <= PropertyMapper::Column
              @default_properties[property_name] = true
            when mapper_class <= PropertyMapper::ForeignKey
              # for foreign key properties, by default we only load the ID
              # (which is already present on the parent result row):
              @default_properties[property_name] = JUST_ID
            end
          end

        @property_mappers.freeze
      end

      JUST_ID = [:id].freeze

      def inspect
        "<##{self.class}: #{model_class}>"
      end

      def allocates_ids?
        !!@id_sequence_table
      end

      # is this repository capable of loading instances of the given model
      # class?
      # repositories which support polymorhpic loading may override this.
      def can_get_class?(model_class)
        model_class == self.model_class
      end

      # is this repository capable of storing instances of the given model
      # class?
      # repositories which support polymorhpic writes may override this.
      def can_set_class?(model_class)
        model_class == self.model_class
      end

      # see Hold::Sequel::RepositoryObserver for the interface you need to
      # expose to be an observer here.
      #
      # If you're using Wirer to construct the repository, a better way to hook
      # the repo up with observers is to add RepositoryObservers to the
      # Wirer::Container and have them provide feature
      # [:observes_repo_for_class, model_class].
      #
      # They'll then get picked up by our multiple setter_dependency and added
      # as an observer just after construction.
      def add_observer(observer)
        @observers ||= []
        @observers << observer
      end

      # convenience to get a particular property mapper of this repo:
      def mapper(name)
        fail ArgumentError unless name.is_a?(Symbol)
        @property_mappers[name] ||
          (fail "#{self.class}: no such property mapper #{name.inspect}")
      end

      # if you want to avoid the need to manually pass in target_repo parameters
      # for each property mapped by a foreign key mapper etc - this will have
      # the mappers go find the dependency themselves.
      def get_repo_dependencies_from(repo_set)
        @property_mappers.each_value do |mapper|
          mapper.get_repo_dependencies_from(repo_set)
        end
      end

      def table_id_column(table)
        @tables_id_columns[table]
      end

      private

      # mini DSL for use in mapper_config block passed to constructor, which is
      # instance_evalled:

      def map_property(property_name, mapper_class = PropertyMapper, *p, &b)
        fail unless mapper_class <= PropertyMapper
        @property_mappers[property_name] =
          mapper_class.new(self, property_name, *p, &b)
      end

      # Some convenience mapper DSL methods for each of the mapper subclasses:
      { column: 'Column',      foreign_key: 'ForeignKey',
        one_to_many: 'OneToMany',   many_to_many: 'ManyToMany',
        created_at: 'CreatedAt',   updated_at: 'UpdatedAt',
        hash_property: 'Hash',        array_property: 'Array',
        custom_query: 'CustomQuery',
        custom_query_single_value: 'CustomQuerySingleValue'
      }.each do |name, mapper_class|
        class_eval <<-EOS, __FILE__, __LINE__ + 1
def map_#{name}(property_name, options={}, &block)
  map_property(property_name, PropertyMapper::#{mapper_class}, options, &block)
end
        EOS
      end

      def use_table(name, options = {})
        @tables << name
        @tables_id_columns[name] = options[:id_column] || :id
        @id_sequence_table = name if options[:id_sequence]
      end

      # Some helpers

      def translate_exceptions(&b)
        Hold::Sequel.translate_exceptions(&b)
      end

      def insert_row_for_entity(entity, table, id = nil)
        row = {}
        @property_mappers.each_value do |mapper|
          mapper.build_insert_row(entity, table, row, id)
        end
        row
      end

      def update_row_for_entity(update_entity, table)
        row = {}
        @property_mappers.each_value do |mapper|
          mapper.build_update_row(update_entity, table, row)
        end
        row
      end

      public

      def construct_entity(property_hash, _ = nil)
        # new_skipping_checks is supported by ThinModels::Struct(::Typed) and
        # skips any type checks or attribute name checks on the supplied
        # attributes.
        @model_class_new_method ||=
          if model_class.respond_to?(:new_skipping_checks)
            :new_skipping_checks
          else
            :new
          end

        model_class
          .send(@model_class_new_method, property_hash) do |model, property|
          get_property(model, property)
        end
      end

      def construct_entity_from_id(id)
        model_class.new(@identity_property => id) do |model, property|
          get_property(model, property)
        end
      end

      # this determines if an optimisation can be done whereby if only the ID
      # property is requested to be loaded, the object(s) can be constructed
      # directly from their ids without needing to be fetched from the database.
      def can_construct_from_id_alone?(properties)
        properties == JUST_ID
      end

      def dataset_to_select_tables(*tables)
        main_table, *other_tables = tables
        main_id = @identity_mapper.qualified_column_name(main_table)
        other_tables.inject(@db[main_table]) do |dataset, table|
          dataset.join(table,
                       @identity_mapper.qualified_column_name(table) => main_id)
        end
      end

      def columns_aliases_and_tables_for_properties(properties)
        columns_by_property = {}
        aliased_columns = []
        tables = []
        properties.each do |p|
          next if p == @identity_property # this gets special handling
          cs, as, ts = mapper(p).columns_aliases_and_tables_for_select
          columns_by_property[p] = cs
          aliased_columns.concat(as)
          tables.concat(ts)
        end
        tables.unshift(@main_table) if tables.delete(@main_table)

        # the identity mapper gets called last, so that it can get a hint about
        # what tables are already required for the other columns. (seeing as how
        # an identity column needs to be present on every table used for a given
        # repo, it should never need to add an extra table just in order to
        # select the ID)
        id_cols, id_aliases, id_tables =
          @identity_mapper
          .columns_aliases_and_tables_for_select(tables.first || @main_table)

        columns_by_property[@identity_property] = id_cols
        aliased_columns.concat(id_aliases)
        tables.concat(id_tables)
        aliased_columns.uniq!
        tables.uniq!
        [columns_by_property, aliased_columns, tables]
      end

      def transaction(*p, &b)
        @db.transaction(*p, &b)
      end

      # This is the main mechanism to retrieve stuff from the repo via custom
      # queries.

      def query(properties = nil, &b)
        if properties == true || properties.nil?
          properties = @default_properties
        end
        Query.new(self, properties, &b)
      end

      # Can take a block which may add extra conditions, joins, order etc onto
      # the relevant query.
      def get_many_with_dataset(options = {}, &b)
        query(options[:properties], &b).to_a(options[:lazy])
      end

      def get_all(options = {})
        query(options[:properties]).to_a(options[:lazy])
      end

      # like get_many_with_dataset but just gets a single row, or nil if not
      # found. adds limit(1) to the dataset for you.
      def get_with_dataset(options = {}, &b)
        query(options[:properties], &b).single_result
      end

      def get_property(entity, property, options = {})
        unless property.is_a? Symbol
          fail ArgumentError, 'get_property must suppy a symbol'
        end
        begin
          result =
            query(property =>
                  options[:properties]) do |dataset, property_columns|
                    filter = @identity_mapper
                             .make_filter(entity.id,
                                          property_columns[@identity_property])
                    dataset.filter(filter)
                  end.single_result
        rescue TypeError
          # catches test errors caught by []ing a string post 1.8
          raise ArgumentError, 'get_property caught a type error, check options'
        end
        result && result[property]
      end

      def get_by_id(id, options = {})
        properties = options[:properties]

        if can_construct_from_id_alone?(properties)
          return construct_entity_from_id(id)
        end

        query(properties) do |dataset, property_columns|
          filter = @identity_mapper
                   .make_filter(id, property_columns[@identity_property])
          dataset.filter(filter)
        end.single_result
      end

      # multi-get via a single SELECT... WHERE id IN (1,2,3,4)
      def get_many_by_ids(ids, options = {})
        properties = options[:properties]

        if can_construct_from_id_alone?(properties)
          return ids.map { |id| construct_entity_from_id(id) }
        end

        results = query(options[:properties]) do |ds, mapping|
          id_filter = @identity_mapper
                      .make_multi_filter(ids.uniq, mapping[@identity_property])
          ds.filter(id_filter)
        end.to_a(options[:lazy])

        results_by_id = results.each_with_object({}) do |object, hash|
          hash[object.id] = object
        end
        ids.map { |id| results_by_id[id] }
      end

      def get_many_by_property(property, value, options = {})
        properties_to_fetch ||= @default_properties.dup
        properties_to_fetch[property] = true
        query(options[:properties]) do |dataset, property_columns|
          filter = mapper(property)
                   .make_filter(value, property_columns[property])

          dataset.filter(filter)
        end.to_a(options[:lazy])
      end

      def get_by_property(property, value, options = {})
        get_many_by_property(property, value, options).first
      end

      def contains_id?(id)
        dataset = dataset_to_select_tables(@main_table)
        id_filter = @identity_mapper
                    .make_filter(id, [@tables_id_columns[@main_table]])
        dataset.filter(id_filter).select(1).limit(1).single_value ? true : false
      end

      def contains?(entity)
        (id = entity.id) && contains_id?(id)
      end

      # CUD

      # Calls one of store_new (insert) or update as appropriate.
      #
      # Where the repo allocates_ids, you can supply an entity without an ID and
      # store_new will be called.
      #
      # If the entity has an ID, it will check whether it's currently contained
      # in the repository before calling store_new or update as appropriate.
      def store(entity)
        id = entity.id
        if id
          transaction do
            if contains_id?(id)
              update(entity)
            else
              store_new(entity)
            end
          end
        else
          if allocates_ids?
            store_new(entity)
          else
            fail Hold::MissingIdentity
          end
        end
        entity
      end

      # inserts rows into all relevant tables for the given entity.
      # ensures that where one of the tables is used for an id sequence,
      # that this row is inserted first and the resulting insert_id
      # obtained is passed when building subsequent rows.
      #
      # note: order of inserts is important here if you have foreign key
      # dependencies between the ID columns of the different tables; if so
      # you'll need to order your use_table declarations accordingly.
      def store_new(entity)
        transaction do
          rows = {}
          insert_id = nil
          pre_insert(entity)
          @property_mappers.each_value { |mapper| mapper.pre_insert(entity) }
          if @id_sequence_table
            row = insert_row_for_entity(entity, @id_sequence_table)
            insert_id = translate_exceptions do
              @db[@id_sequence_table].insert(row)
            end
            rows[@id_sequence_table] = row
          end
          # note: order is important here if you have foreign key dependencies,
          # order your use_table declarations appropriately:
          @tables.each do |table|
            next if table == @id_sequence_table # done that already
            row = insert_row_for_entity(entity, table, insert_id)
            translate_exceptions { @db[table].insert(row) }
            rows[table] = row
          end
          # identity_mapper should be called first, so that other mappers have
          # the new ID available on the entity when called.
          @identity_mapper.post_insert(entity, rows, insert_id)
          @property_mappers.each_value do |mapper|
            next if mapper == @identity_mapper
            mapper.post_insert(entity, rows, insert_id)
          end
          post_insert(entity, rows, insert_id)
          entity
        end
      end

      # Remember to call super if you override this.
      # If you do any extra inserting in an overridden pre_insert, call super
      # beforehand
      def pre_insert(entity)
        Array(@observers).each { |observer| observer.pre_insert(self, entity) }
      end

      # Remember to call super if you override this.
      # If you do any extra inserting in an overridden post_insert, call super
      # afterwards
      def post_insert(entity, rows, insert_id)
        Array(@observers).each do |observer|
          observer.post_insert(self, entity, rows, insert_id)
        end
      end

      def update(entity, update_entity = entity)
        id = entity.id || (fail Hold::MissingIdentity)
        transaction do
          pre_update(entity, update_entity)

          data_from_mappers = @property_mappers
                              .each_with_object({}) do |(name, mapper), hash|
            hash[name] = mapper.pre_update(entity, update_entity)
          end

          rows = @tables.each_with_object({}) do |table, hash|
            hash[table] = row = update_row_for_entity(update_entity, table)
            next if row.empty?
            id_filter = @identity_mapper
                        .make_filter(id, [@tables_id_columns[table]])

            translate_exceptions { @db[table].filter(id_filter).update(row) }
          end
          @property_mappers.each do |name, mapper|
            mapper
              .post_update(entity, update_entity, rows, data_from_mappers[name])
          end
          post_update(entity, update_entity, rows)
          entity.merge!(update_entity) if entity.respond_to?(:merge!)
          entity
        end
      end

      # Remember to call super if you override this.
      # If you do any extra updating in an overridden pre_update, call super
      # beforehand
      def pre_update(entity, update_entity)
        Array(@observers).each do |observer|
          observer.pre_update(self, entity, update_entity)
        end
      end

      # Remember to call super if you override this.
      # If you do any extra updating in an overridden post_update, call super
      # afterwards
      def post_update(entity, update_entity, rows)
        Array(@observers).each do |observer|
          observer.post_update(self, entity, update_entity, rows)
        end
      end

      def update_by_id(id, update_entity)
        entity = construct_entity(@identity_property => id)
        update(entity, update_entity)
      end

      # deletes rows for this id in all tables of the repo.
      #
      # note: order of
      # deletes is important here if you have foreign key dependencies between
      # the ID columns of the different tables; this goes in the reverse order
      # to that used for inserts by store_new, which in turn is determined by
      # the order of your use_table declarations
      def delete(entity)
        id = entity.id || (fail Hold::MissingIdentity)
        transaction do
          pre_delete(entity)
          @property_mappers.each do |_name, mapper|
            mapper.pre_delete(entity)
          end
          @tables.reverse_each do |table|
            id_filter = @identity_mapper
                        .make_filter(id, [@tables_id_columns[table]])
            @db[table].filter(id_filter).delete
          end
          @property_mappers.each do |_name, mapper|
            mapper.post_delete(entity)
          end
          post_delete(entity)
        end
      end

      # Remember to call super if you override this.
      # If you do any extra deleting in an overridden pre_delete, call super
      # beforehand
      def pre_delete(entity)
        Array(@observers).each { |observer| observer.pre_delete(self, entity) }
      end

      # Remember to call super if you override this.
      # If you do any extra deleting in an overridden post_delete, call super
      # afterwards
      def post_delete(entity)
        Array(@observers).each { |observer| observer.post_delete(self, entity) }
      end

      def delete_id(id)
        entity = construct_entity(@identity_property => id)
        delete(entity)
      end

      # ArrayCells for top-level collections

      def array_cell_for_dataset(&b)
        QueryArrayCell.new(self, &b)
      end

      def count_dataset
        dataset = dataset_to_select_tables(@main_table)
        dataset = yield dataset if block_given?
        dataset.count
      end
    end
  end
end
