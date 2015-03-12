module Hold
  module Sequel
    # A query has a dataset and mappings constructed to select a particular
    # set of properties on a particular Sequel::IdentitySetRepository
    class Query
      attr_reader :dataset, :count_dataset, :property_versions

      # Repo: repository to query
      # properties: mapping or array of properties to fetch.
      # properties ::=
      #   nil or true = fetch the default set of properties for the given
      #   repository
      #   array of property names = fetch just these properties, each in their
      #   default version
      #   hash of property names = fetch just these properties, each in the
      #   version given in the hash
      #
      # can pass a block: do |dataset, property_columns|
      #                     return dataset.messed_with
      #                   end
      def initialize(repo, properties)
        @repository = repo
        @properties = properties

        @dataset = @repository.dataset_to_select_tables(*tables)
        @dataset = yield @dataset, property_columns if block_given?

        @dataset = @dataset.select(*aliased_columns)
      end

      def property_columns
        @property_columns ||=
          @repository.columns_by_property(property_versions.keys)
      end

      def aliased_columns
        @aliased_columns ||=
          @repository.aliases_by_property(property_versions.keys)
      end

      def tables
        @tables ||=
          @repository.tables_by_property(property_versions.keys)
      end

      def property_versions
        @property_versions ||=
          if @properties.is_a?(::Array)
            @properties.each_with_object({}) do |(p, v), hash|
              hash[p] = v
            end
          else
            @properties
          end
      end

      private

      def load_from_rows(rows, return_the_row_alongside_each_result = false)
        ids = load_ids_from_rows(rows)
        property_hashes = load_property_hashes_from_rows(rows, ids)

        index = -1
        property_hashes.each_with_object([]) do |h, arr|
          row = rows[index += 1]
          entity = @repository.construct_entity(h, row)
          arr <<
            (return_the_row_alongside_each_result ? [entity, row] : entity)
        end
      end

      public

      def load_ids_from_rows(rows)
        ids = []

        @repository.identity_mapper.load_values(rows) do |id, _|
          ids << id
        end

        ids
      end

      def load_property_hashes_from_rows(rows, ids)
        property_hashes = ids.each_with_object([]) do |id, a|
          a << { @repository.identity_property => id }
        end

        property_versions.each do |prop_name, prop_version|
          @repository.mapper(prop_name)
            .load_values(rows, ids, prop_version) do |value, i|
            property_hashes[i][prop_name] = value
          end
        end

        property_hashes
      end

      def results(lazy = false)
        lazy_array = DatasetLazyArray.new(dataset) do |rows|
          load_from_rows(rows)
        end
        lazy ? lazy_array : lazy_array.to_a
      end

      alias_method :to_a, :results

      # this one is useful if you add extra selected columns onto the dataset,
      # and you want to get at those extra values on the underlying rows
      # alongside the loaded entities.
      def results_with_rows
        load_from_rows(dataset.all, true)
      end

      def single_result
        row = Hold::Sequel.translate_exceptions { dataset.first } || (return)

        id = @repository.identity_mapper.load_value(row)
        property_hash = { @repository.identity_property => id }

        property_versions.each do |prop_name, prop_version|
          property_hash[prop_name] = @repository.mapper(prop_name)
                                     .load_value(row, id, prop_version)
        end

        @repository.construct_entity(property_hash, row)
      end
    end
  end
end
