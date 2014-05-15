module Hold::Sequel
  class PolymorphicRepository
    include Hold::IdentitySetRepository

    attr_reader :db, :table, :type_column, :id_column, :type_to_model_class_mapping,
                :repos_for_model_classes, :model_class_to_type_mapping

    def initialize(db, options={})
      @db = db
      @table = options[:table] || :base
      @type_column = options[:type_column] || :type
      @id_column = options[:id_column] || :id
      @type_to_model_class_mapping = options[:mapping]
      @model_class_to_type_mapping = @type_to_model_class_mapping.invert

      @repos_for_model_classes = options[:repos] || {}
      @dataset = @db[@table].select(Sequel.as(@type_column,:_type), Sequel.as(@id_column,:_id))
    end

    def can_get_class?(model_class)
      @model_class_to_type_mapping.has_key?(model_class)
    end

    def can_set_class?(model_class)
      @model_class_to_type_mapping.has_key?(model_class)
    end

    def get_repo_dependencies_from(repo_set)
      @type_to_model_class_mapping.each do |type,model_class|
        @repos_for_model_classes[model_class] ||= repo_set.repo_for_model_class(model_class)
      end
    end

    def type_to_repo_mapping
      @type_to_repo_mapping ||= begin
        result = {}
        @type_to_model_class_mapping.each {|t,m| result[t] = @repos_for_model_classes[m]}
        result
      end
    end

    def construct_entity(property_hash, row=nil)
      type = property_hash[:_type] or raise "missing _type in result row"
      @type_to_model_class_mapping[type].new(property_hash)
    end

    def transaction(*p, &b)
      @db.transaction(*p, &b)
    end

    # - Takes multiple result rows with type and id column
    # - Groups the IDs by type and does a separate get_many_by_ids query on the relevant repo
    # - Combines the results from the separate queries putting them into the order of the IDs from
    #   the original rows (or in the order of the ids given, where they are given)
    def load_from_rows(rows, options={}, ids=nil)
      ids ||= rows.map {|row| row[:_id]}
      ids_by_type = Hash.new {|h,k| h[k]=[]}
      rows.each {|row| ids_by_type[row[:_type]] << row[:_id]}
      results_by_id = {}
      ids_by_type.each do |type, type_ids|
        repo = type_to_repo_mapping[type] or raise "PolymorphicRepository: no repo found for type value #{type}"
        repo.get_many_by_ids(type_ids, options).each_with_index do |result, index|
          results_by_id[type_ids[index]] = result
        end
      end
      results_by_id.values_at(*ids)
    end

    def load_from_row(row, options={})
      repo = type_to_repo_mapping[row[:_type]] or raise "PolymorphicRepository: no repo found for type value #{row[:_type]}"
      repo.get_by_id(row[:_id], options)
    end

    def get_with_dataset(options={}, &b)
      dataset = @dataset
      dataset = yield @dataset if block_given?
      row = dataset.limit(1).first and load_from_row(row, options)
    end

    def get_by_id(id, options={})
      get_with_dataset(options) {|ds| ds.filter(@id_column => id)}
    end

    def get_many_by_ids(ids, options={})
      rows = @dataset.filter(@id_column => ids).all
      load_from_rows(rows, options, ids)
    end

    def contains_id?(id)
      @dataset.filter(@id_column => id).select(1).limit(1).single_value ? true : false
    end




    def store(object)
      repo = @repos_for_model_classes[object.class] or raise Error
      repo.store(id, object)
    end

    def store_new(object)
      repo = @repos_for_model_classes[object.class] or raise Error
      repo.store_new(id, object)
    end

    def update(entity, update_entity)
      repo = @repos_for_model_classes[entity.class] or raise Error
      repo.update(entity, update_entity)
    end

    def update_by_id(id, update_entity)
      repo = @repos_for_model_classes[update_entity.class] or raise Error
      repo.update_by_id(id, update_entity)
    end

    def delete(object)
      repo = @repos_for_model_classes[object.class] or raise Error
      repo.delete(object)
    end
  end
end
