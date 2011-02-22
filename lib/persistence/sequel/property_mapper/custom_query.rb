module Persistence::Sequel
  # A read-only mapper for array properties, which allows you to fetch the items via an arbitrary custom query
  # against a target repository. You supply a block which takes the dataset and mapper arguments supplied by
  # the repository's query_for_version method, but also an additional ID argument for the ID of the object
  # for which the property is being fetched.
  #
  # example:
  #  map_custom_query('foos') do |id, dataset, mapping|
  #    dataset.join(:bar, ...).
  #      ...
  #      .filter(:boz_id => id)
  #  end
  class PropertyMapper::CustomQuery < PropertyMapper
    attr_reader :model_class

    def initialize(repo, property_name, options={}, &block)
      super(repo, property_name, &nil) # re &nil: our &block is otherwise implicitly passed on to super it seems, bit odd

      @model_class = options[:model_class] or raise ArgumentError
      repo_dependency(@model_class, :initial_value => options[:repo])

      @query_block = options[:query] || block
    end

    def load_value(row=nil, id=nil, version=nil)
      target_repo.query(version) do |dataset, mapping|
        @query_block.call(id, dataset, mapping)
      end.to_a
    end
  end
end
