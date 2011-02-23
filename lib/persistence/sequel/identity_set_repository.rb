module Persistence::Sequel
  class IdentitySetRepository
    include Persistence::IdentitySetRepository

    attr_reader :db, :model_class, :main_table, :property_mappers, :identity_property,
                :identity_mapper, :id_sequence_table, :default_properties

    def initialize(db, model_class, main_table, &mapper_config)
      @db = db
      @tables = []
      @tables_id_columns = {}
      @main_table = main_table.to_sym

      @model_class = model_class

      @property_mappers = {}
      instance_eval(&mapper_config) if mapper_config

      # make a default use_table declaration with id_column of :id if none is given
      unless @tables_id_columns[@main_table]
        use_table(@main_table, :id_column => :id, :id_sequence => true)
      end

      # map the identity_property
      @identity_property = :id # todo make this configurable
      @identity_mapper = @property_mappers[@identity_property] = PropertyMapper::Identity.new(self, @identity_property)

      @default_properties = {}
      @property_mappers.each do |name, mapper|
        @default_properties[name] = true if mapper.is_a?(PropertyMapper::Column)
      end

      @property_mappers.freeze
    end

    def inspect
      "<##{self.class}: #{@model_class}>"
    end

    def allocates_ids?
      !!@id_sequence_table
    end

    # is this repository capable of loading instances of the given model class?
    # repositories which support polymorhpic loading may override this.
    def can_get_class?(model_class)
      model_class == @model_class
    end

    # is this repository capable of storing instances of the given model class?
    # repositories which support polymorhpic writes may override this.
    def can_set_class?(model_class)
      model_class == @model_class
    end

    # convenience to get a particular property mapper of this repo:
    def mapper(name)
      @property_mappers[name] or raise "#{self.class}: no such property mapper #{name.inspect}"
    end

    # if you want to avoid the need to manually pass in target_repo parameters for each property
    # mapped by a foreign key mapper etc - this will have the mappers go find the dependency themselves.
    def get_repo_dependencies_from(repo_set)
      @property_mappers.each_value {|mapper| mapper.get_repo_dependencies_from(repo_set)}
    end

    def table_id_column(table)
      @tables_id_columns[table]
    end

    private

    # mini DSL for use in mapper_config block passed to constructor, which is instance_evalled:

    def map_property(property_name, mapper_class=PropertyMapper, *p, &b)
      raise unless mapper_class <= PropertyMapper
      @property_mappers[property_name] = mapper_class.new(self, property_name, *p, &b)
    end

    # Some convenience mapper DSL methods for each of the mapper subclasses:
    { :column        => 'Column',      :foreign_key      => 'ForeignKey',
      :one_to_many   => 'OneToMany',   :many_to_many     => 'ManyToMany',
      :created_at    => 'CreatedAt',   :updated_at       => 'UpdatedAt',
      :hash_property => 'Hash',        :array_property   => 'Array',
      :custom_query  => 'CustomQuery', :custom_query_single_value => 'CustomQuerySingleValue'
    }.each do |name, mapper_class|
      class_eval <<-EOS, __FILE__, __LINE__+1
        def map_#{name}(property_name, options={}, &block)
          map_property(property_name, PropertyMapper::#{mapper_class}, options, &block)
        end
      EOS
    end

    def use_table(name, options={})
      @tables << name
      @tables_id_columns[name] = options[:id_column] || :id
      @id_sequence_table = name if options[:id_sequence]
    end



    # Some helpers

    def translate_exceptions(&b)
      Persistence::Sequel.translate_exceptions(&b)
    end

    def insert_row_for_entity(entity, table, id=nil)
      row = {}
      @property_mappers.each_value do |mapper|
        mapper.build_insert_row(entity, table, row, id)
      end
      row
    end

    def update_row_for_entity(id, update_entity, table)
      row = {}
      @property_mappers.each_value do |mapper|
        mapper.build_update_row(update_entity, table, row)
      end
      row
    end

    public

    def construct_entity(property_hash, row=nil)
      @model_class.new(property_hash) do |model, property|
        get_property(model, property)
      end
    end

    def dataset_to_select_tables(*tables)
      main_table, *other_tables = tables
      main_id = @identity_mapper.qualified_column_name(main_table)
      other_tables.inject(@db[main_table]) do |dataset, table|
        dataset.join(table, @identity_mapper.qualified_column_name(table) => main_id)
      end
    end

    def columns_aliases_and_tables_for_properties(properties)
      columns_by_property = {}; aliased_columns = []; tables = []
      properties.each do |p|
        next if p == @identity_property # this gets special handling
        cs, as, ts = mapper(p).columns_aliases_and_tables_for_select
        columns_by_property[p] = cs
        aliased_columns.concat(as)
        tables.concat(ts)
      end
      tables.unshift(@main_table) if tables.delete(@main_table)

      # the identity mapper gets called last, so that it can get a hint about what
      # tables are already required for the other columns. (seeing as how an identity column
      # needs to be present on every table used for a given repo, it should never need to
      # add an extra table just in order to select the ID)
      id_cols, id_aliases, id_tables = @identity_mapper.columns_aliases_and_tables_for_select(tables.first || @main_table)
      columns_by_property[@identity_property] = id_cols
      aliased_columns.concat(id_aliases)
      tables.concat(id_tables)
      aliased_columns.uniq!; tables.uniq!
      return columns_by_property, aliased_columns, tables
    end

    def transaction(*p, &b)
      @db.transaction(*p, &b)
    end

    # This is the main mechanism to retrieve stuff from the repo via custom queries.

    def query(properties=nil, &b)
      properties = @default_properties if properties == true || properties.nil?
      Query.new(self, properties, &b)
    end


    def load_from_rows(rows, properties)
      return [] if rows.empty?

      property_hashes = []; ids = []
      @identity_mapper.load_values(rows) do |id,i|
        property_hashes << {@identity_property => id}
        ids << id
      end

      non_id_property_mappings_for_properties(properties).each do |prop_name, mapper, prop_properties|
        mapper.load_values(rows, ids, prop_properties) {|value, i| property_hashes[i][prop_name] = value}
      end

      entities = []
      property_hashes.each_with_index {|h,i| entities << construct_entity(h, rows[i])}
      entities
    end

    # Can take a block which may add extra conditions, joins, order etc onto the relevant query.
    def get_many_with_dataset(properties=nil, &b)
      query(properties, &b).to_a
    end

    def get_all(properties=nil)
      query(properties).to_a
    end

    # like get_many_with_dataset but just gets a single row, or nil if not found. adds limit(1) to the dataset for you.
    def get_with_dataset(properties=nil, &b)
      query(properties, &b).single_result
    end

    def get_property(entity, property, properties_to_fetch_on_property=nil)
      result = query(property => properties_to_fetch_on_property) do |dataset, property_columns|
        filter = @identity_mapper.make_filter(entity.id, property_columns[@identity_property])
        dataset.filter(filter)
      end.single_result
      result && result[property]
    end

    def get_by_id(id, properties=nil)
      query(properties) do |dataset, property_columns|
        filter = @identity_mapper.make_filter(id, property_columns[@identity_property])
        dataset.filter(filter)
      end.single_result
    end

    # multi-get via a single SELECT... WHERE id IN (1,2,3,4)
    def get_many_by_ids(ids, properties=nil)
      results_by_id = {}
      results = query(properties) do |ds,mapping|
        id_filter = @identity_mapper.make_multi_filter(ids.uniq, mapping[@identity_property])
        ds.filter(id_filter)
      end.to_a
      results.each {|object| results_by_id[object.id] = object}
      ids.map {|id| results_by_id[id]}
    end

    def get_many_by_property(property, value, properties_to_fetch=nil)
      properties_to_fetch ||= @default_properties.dup
      properties_to_fetch[property] = true
      query(properties_to_fetch) do |dataset, property_columns|
        filter = mapper(property).make_filter(value, property_columns[property])
        dataset.filter(filter)
      end.to_a
    end

    def get_by_property(property, value, properties_to_fetch=nil)
      properties_to_fetch ||= @default_properties.dup
      properties_to_fetch[property] = true
      query(properties_to_fetch) do |dataset, property_columns|
        filter = mapper(property).make_filter(value, property_columns[property])
        dataset.filter(filter)
      end.single_result
    end



    def contains_id?(id)
      dataset = dataset_to_select_tables(@main_table)
      id_filter = @identity_mapper.make_filter(id, [@tables_id_columns[@main_table]])
      dataset.filter(id_filter).select(1).limit(1).single_value ? true : false
    end

    def contains?(entity)
      id = entity.id and contains_id?(id)
    end


    # CUD

    # Calls one of store_new (insert) or update as appropriate.
    #
    # Where the repo allocates_ids, you can supply an entity without an ID and store_new will be called.
    #
    # If the entity has an ID, it will check whether it's currently contained in the repository
    # before calling store_new or update as appropriate.
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
          raise Persistence::MissingIdentity
        end
      end
      entity
    end

    # inserts rows into all relevant tables for the given entity.
    # ensures that where one of the tables is used for an id sequence,
    # that this row is inserted first and the resulting insert_id
    # obtained is passed when building subsequent rows.
    #
    # note: order of inserts is important here if you have foreign key dependencies between
    # the ID columns of the different tables; if so you'll need to order your use_table
    # declarations accordingly.
    def store_new(entity)
      transaction do
        rows = {}; insert_id = nil
        pre_insert(entity)
        @property_mappers.each_value {|mapper| mapper.pre_insert(entity)}
        if @id_sequence_table
          row = insert_row_for_entity(entity, @id_sequence_table)
          insert_id = translate_exceptions {@db[@id_sequence_table].insert(row)}
          rows[@id_sequence_table] = row
        end
        # note: order is important here if you have foreign key dependencies, order
        # your use_table declarations appropriately:
        @tables.each do |table|
          next if table == @id_sequence_table # done that already
          row = insert_row_for_entity(entity, table, insert_id)
          translate_exceptions {@db[table].insert(row)}
          rows[table] = row
        end
        # identity_mapper should be called first, so that other mappers have the new ID
        # available on the entity when called.
        @identity_mapper.post_insert(entity, rows, insert_id)
        @property_mappers.each_value do |mapper|
          next if mapper == @identity_mapper
          mapper.post_insert(entity, rows, insert_id)
        end
        post_insert(entity, rows, insert_id)
        entity
      end
    end

    # hooks to override
    def pre_insert(entity)
    end

    def post_insert(entity, rows, insert_id)
    end

    def update(entity, update_entity=entity)
      id = entity.id or raise Persistence::MissingIdentity
      transaction do
        rows = {}; data_from_mappers = {}
        pre_update(entity, update_entity)
        @property_mappers.each do |name, mapper|
          data_from_mappers[name] = mapper.pre_update(entity, update_entity)
        end
        @tables.each do |table|
          row = update_row_for_entity(id, update_entity, table)
          unless row.empty?
            id_filter = @identity_mapper.make_filter(id, [@tables_id_columns[table]])
            translate_exceptions {@db[table].filter(id_filter).update(row)}
          end
          rows[table] = row
        end
        @property_mappers.each do |name, mapper|
          mapper.post_update(entity, update_entity, rows, data_from_mappers[name])
        end
        post_update(entity, update_entity, rows)
        entity.merge!(update_entity) if entity.respond_to?(:merge!)
        entity
      end
    end

    # hooks to override
    def pre_update(entity, update_entity)
    end

    def post_update(entity, update_entity, rows)
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
    # to that used for inserts by store_new, which in turn is determined by the
    # order of your use_table declarations
    def delete(entity)
      id = entity.id or raise Persistence::MissingIdentity
      transaction do
        pre_delete(entity)
        @property_mappers.each do |name, mapper|
          mapper.pre_delete(entity)
        end
        @tables.reverse_each do |table|
          id_filter = @identity_mapper.make_filter(id, [@tables_id_columns[table]])
          @db[table].filter(id_filter).delete
        end
        @property_mappers.each do |name, mapper|
          mapper.post_delete(entity)
        end
        post_delete(entity)
      end
    end

    # hooks to override
    def pre_delete(entity)
    end

    def post_delete(entity)
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
