module Hold::Sequel
  # A query has a dataset and mappings constructed to select a particular
  # set of properties on a particular Sequel::IdentitySetRepository
  class Query
    attr_reader :dataset, :count_dataset, :property_versions, :property_columns, :aliased_columns, :tables

    # Repo: repository to query
    # properties: mapping or array of properties to fetch.
    # properties ::=
    #   nil or true = fetch the default set of properties for the given repository
    #   array of property names = fetch just these properties, each in their default version
    #   hash of property names = fetch just these properties, each in the version given in the hash
    #
    # can pass a block: {|dataset, property_columns| return dataset.messed_with}
    def initialize(repo, properties)
      @repository = repo

      if properties.is_a?(::Array)
        @property_versions = {}
        properties.each {|p,v| @property_versions[p] = v}
      else
        @property_versions = properties
      end

      @property_columns, @aliased_columns, @tables =
        @repository.columns_aliases_and_tables_for_properties(@property_versions.keys)

      @dataset = @repository.dataset_to_select_tables(*@tables)
      @dataset = yield @dataset, @property_columns if block_given?

      id_cols = @property_columns[@repository.identity_property]
      @count_dataset = @dataset.select(*id_cols)

      @dataset = @dataset.select(*@aliased_columns)
    end

    private

    def load_from_rows(rows, return_the_row_alongside_each_result=false)
      return [] if rows.empty?

      property_hashes = []; ids = []
      @repository.identity_mapper.load_values(rows) do |id,i|
        property_hashes << {@repository.identity_property => id}
        ids << id
      end

      @property_versions.each do |prop_name, prop_version|
        @repository.mapper(prop_name).load_values(rows, ids, prop_version) do |value, i|
          property_hashes[i][prop_name] = value
        end
      end

      result = []
      property_hashes.each_with_index do |h,i|
        row = rows[i]
        entity = @repository.construct_entity(h, row)
        result << (return_the_row_alongside_each_result ? [entity, row] : entity)
      end
      result
    end


    public

    def results(lazy=false)
      lazy_array = DatasetLazyArray.new(@dataset, @count_dataset) {|rows| load_from_rows(rows)}
      lazy ? lazy_array : lazy_array.to_a
    end

    alias :to_a :results

    # this one is useful if you add extra selected columns onto the dataset, and you want to get
    # at those extra values on the underlying rows alongside the loaded entities.
    def results_with_rows
      load_from_rows(@dataset.all, true)
    end

    def single_result
      row = Hold::Sequel.translate_exceptions {@dataset.first} or return

      id = @repository.identity_mapper.load_value(row)
      property_hash = {@repository.identity_property => id}

      @property_versions.each do |prop_name, prop_version|
        property_hash[prop_name] = @repository.mapper(prop_name).load_value(row, id, prop_version)
      end

      @repository.construct_entity(property_hash, row)
    end
  end
end
