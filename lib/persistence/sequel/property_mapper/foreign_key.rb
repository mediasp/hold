module Persistence::Sequel
  # Maps to an associated object which is fetched by id from a target repository using a foriegn key column
  class PropertyMapper::ForeignKey < PropertyMapper
    def self.setter_dependencies_for(options={})
      features = [*options[:model_class]].map {|klass| [:get_class, klass]}
      {:target_repo => [Persistence::IdentitySetRepository, *features]}
    end

    attr_accessor :target_repo

    attr_reader :columns_aliases_and_tables_for_select, :column_alias, :column_name, :table,
      :column_qualified, :auto_store_new, :model_class

    # auto_store_new: where the value for this property is an object without an ID,
    #  automatically store_new the object in the target_repo before trying to store
    #  the object in question with this foreign key property. In the absence of this
    #  setting, values without an ID will cause an exception
    def initialize(repo, property_name, options)
      super(repo, property_name)

      @table = options[:table] || @repository.main_table
      @column_name = options[:column_name] || :"#{property_name}_id"
      @column_alias = :"#{@table}_#{@column_name}"
      @column_qualified = Sequel::SQL::QualifiedIdentifier.new(@table, @column_name)
      @columns_aliases_and_tables_for_select = [
        [@column_qualified],
        [Sequel::SQL::AliasedExpression.new(@column_qualified, @column_alias)],
        [@table]
      ]

      @auto_store_new = options[:auto_store_new] || false
      @model_class = options[:model_class] or raise ArgumentError
    end

    def load_value(row, id=nil, properties=nil)
      fkey = row[@column_alias] and target_repo.get_by_id(fkey, :properties => properties)
    end

    def ensure_value_has_id_where_present(value)
      if value && !value.id
        if @auto_store_new
          target_repo.store_new(value)
        else
          raise "value for ForeignKey mapped property #{@property_name} has no id, and :auto_store_new not specified"
        end
      end
    end

    def pre_insert(entity)
      ensure_value_has_id_where_present(entity[@property_name])
    end

    def pre_update(entity, update_entity)
      ensure_value_has_id_where_present(update_entity[@property_name])
    end

    def build_insert_row(entity, table, row, id=nil)
      if @table == table && entity.has_key?(@property_name)
        value = entity[@property_name]
        row[@column_name] = value && value.id
      end
    end
    alias :build_update_row :build_insert_row

    # for now ignoring the columns_mapped_to, since Identity mapper is the only one
    # for which this matters at present

    def make_filter(value, columns_mapped_to=nil)
      {@column_qualified => value && value.id}
    end

    def make_multi_filter(values, columns_mapped_to=nil)
      {@column_qualified => values.map {|v| v.id}}
    end

    def make_filter_by_id(id, columns_mapped_to=nil)
      {@column_qualified => id}
    end

    def make_filter_by_ids(ids, columns_mapped_to=nil)
      {@column_qualified => ids}
    end

    # efficient batch load which takes advantage of get_many_by_ids on the target repo
    def load_values(rows, ids=nil, properties=nil, &b)
      fkeys = rows.map {|row| row[@column_alias]}
      non_nil_fkeys = fkeys.compact
      non_nil_fkey_results = if non_nil_fkeys.empty? then [] else
        target_repo.get_many_by_ids(non_nil_fkeys, :properties => properties)
      end
      fkeys.each_with_index do |fkey, index|
        yield(fkey ? non_nil_fkey_results.shift : nil, index)
      end
    end
  end
end
