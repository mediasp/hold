module Hold
  module Sequel
    # A read-only mapper for array properties, which allows you to fetch the items
    # via an arbitrary custom query against a target repository. You supply a
    # block which takes the dataset and mapper arguments supplied by the
    # repository's query_for_version method, but also an additional ID argument
    # for the ID of the object for which the property is being fetched.
    #
    # example:
    #  map_custom_query('foos') do |id, dataset, mapping|
    #    dataset.join(:bar, ...).
    #      ...
    #      .filter(:boz_id => id)
    #  end
    class PropertyMapper
      class CustomQuery < PropertyMapper
        def self.setter_dependencies_for(options = {})
          features = [*options[:model_class]].map { |klass| [:get_class, klass] }
          { target_repo: [IdentitySetRepository, *features] }
        end

        attr_reader :model_class
        attr_accessor :target_repo

        def initialize(repo, property_name, model_class:, query: nil, &block)
          # re &nil: our &block is otherwise implicitly passed on to super it
          # seems, bit odd
          super(repo, property_name, &nil)
          @model_class = model_class
          @query_block = query || block
        end

        def load_value(_row = nil, id = nil, version = nil)
          target_repo.query(version) do |dataset, mapping|
            @query_block.call(id, dataset, mapping)
          end.to_a
        end
      end
    end
  end
end
