module Hold::Sequel
  # A read-only mapper for properties which are a single instance of a model
  # class loaded from another repo.
  #
  # It allows you to fetch the item via an arbitrary custom query against the
  # target repository.
  #
  # You supply a block which takes the dataset and mapper arguments supplied by
  # the repository's query_for_version method, but also an additional ID
  # argument for the ID of the object for which the property is being fetched.
  #
  # example:
  #  map_custom_query_single_value('foo') do |id, dataset, mapping|
  #    dataset.join(:bar, ...).
  #      ...
  #      .filter(:boz_id => id)
  #  end
  class PropertyMapper::CustomQuerySingleValue < PropertyMapper
    def self.setter_dependencies_for(model_class:)
      features = [Array(model_class)].map { |klass| [:get_class, klass] }
      { target_repo: [IdentitySetRepository, *features] }
    end

    attr_reader :model_class
    attr_accessor :target_repo

    def initialize(repo, property_name, model_class:, &block)
      # re &nil: our &block is otherwise implicitly passed on to super it seems,
      # bit odd
      super(repo, property_name, &nil)
      @model_class = model_class
      @query_block = block
    end

    def load_value(_row = nil, id = nil, version = nil)
      target_repo.query(version) do |dataset, mapping|
        @query_block.call(id, dataset, mapping)
      end.single_result
    end
  end
end
