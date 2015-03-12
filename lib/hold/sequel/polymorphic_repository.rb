module Hold
  module Sequel
    # Polymorphic repository
    class PolymorphicRepository
      include Hold::IdentitySetRepository

      attr_reader :db, :table, :type_column, :id_column,
                  :type_to_model_class_mapping, :repos_for_model_classes,
                  :model_class_to_type_mapping

      def initialize(db, options = {})
        @db = db
        @table = options[:table] || :base
        @type_column = options[:type_column] || :type
        @id_column = options[:id_column] || :id
        @type_to_model_class_mapping = options[:mapping]
        @model_class_to_type_mapping = @type_to_model_class_mapping.invert

        @repos_for_model_classes = options[:repos] || {}
        @dataset = @db[@table].select(Sequel.as(@type_column, :_type),
                                      Sequel.as(@id_column, :_id))
      end

      def can_get_class?(model_class)
        @model_class_to_type_mapping.key?(model_class)
      end

      def can_set_class?(model_class)
        @model_class_to_type_mapping.key?(model_class)
      end

      def get_repo_dependencies_from(repo_set)
        @type_to_model_class_mapping.each do |_, model_class|
          @repos_for_model_classes[model_class] ||=
            repo_set.repo_for_model_class(model_class)
        end
      end

      def type_to_repo_mapping
        @type_to_repo_mapping ||=
          begin
            @type_to_repo_mapping.each_with_obeject({}) do |(type, model), hash|
              hash[type] = @repos_for_model_classes[model]
            end
          end
      end

      def construct_entity(property_hash, _row = nil)
        type = property_hash[:_type] || (fail 'missing _type in result row')
        @type_to_model_class_mapping[type].new(property_hash)
      end

      def transaction(*args, &block)
        @db.transaction(*args, &block)
      end

      # - Takes multiple result rows with type and id column
      # - Groups the IDs by type and does a separate get_many_by_ids query on
      #   the relevant repo
      # - Combines the results from the separate queries putting them into the
      #   order of the IDs from the original rows (or in the order of the ids
      #   given, where they are given)
      def load_from_rows(rows, options = {}, ids = [])
        ids_by_type = rows.each_with_object(Hash.new([])) do |row, hash|
          id = row[:_id]
          ids << id
          hash[row[:_type]] << id
        end

        ids_by_type.each_with_object({}) do |(type, type_ids), hash|
          repo = type_to_repo_mapping[type] || (fail NoRepoFound type)
          repo.get_many_by_ids(type_ids, options)
            .each_with_index { |res, index| hash[type_ids[index]] = res }
        end
          .values_at(*ids)
      end

      def load_from_row(row, options = {})
        type = row[:_type]
        repo =
          type_to_repo_mapping[type] ||
          (fail "PolymorphicRepository: no repo found for type  #{type}")

        repo.get_by_id(row[:_id], options)
      end

      def get_with_dataset(options = {})
        dataset = @dataset
        dataset = yield @dataset if block_given?
        (row = dataset.limit(1).first) && load_from_row(row, options)
      end

      def get_by_id(id, options = {})
        get_with_dataset(options) { |ds| ds.filter(@id_column => id) }
      end

      def get_many_by_ids(ids, options = {})
        rows = @dataset.filter(@id_column => ids).all
        load_from_rows(rows, options, ids)
      end

      def contains_id?(id)
        !@dataset.filter(@id_column => id).select(1).limit(1).single_value.nil?
      end

      def store(object)
        repo = @repos_for_model_classes[object.class] || (fail StdError)
        repo.store(id, object)
      end

      def store_new(object)
        repo = @repos_for_model_classes[object.class] || (fail StdError)
        repo.store_new(id, object)
      end

      def update(entity, update_entity)
        repo = @repos_for_model_classes[entity.class] || (fail StdError)
        repo.update(entity, update_entity)
      end

      def update_by_id(id, update_entity)
        repo = @repos_for_model_classes[update_entity.class] || (fail StdError)
        repo.update_by_id(id, update_entity)
      end

      def delete(object)
        repo = @repos_for_model_classes[object.class] || (fail StdError)
        repo.delete(object)
      end
    end
  end
end
