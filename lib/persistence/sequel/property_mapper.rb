require 'persistence/sequel'
require 'set'

module Persistence::Sequel
  # Abstract superclass.
  # Responsibility of a PropertyMapper is to map data for a particular property of a model class, between the
  # instances of that model class, and the database
  class PropertyMapper
    attr_reader :repository, :property_name, :property

    # If you pass a block, it will be instance_evalled, allowing you to create one-off custom property mappers
    # by overriding bits of this implementation in the block.
    def initialize(repo, property_name, &block)
      @repository = repo
      @property_name = property_name
      instance_eval(&block) if block
    end

    # columns: column names to include in a SELECT in order to select this property. these should be
    # qualified with the relevant table name but not aliased
    #
    # aliases: the above columns, aliased for use in the SELECT clause. be alias should something unique
    # which the mapper can later use to retreive from a result row.
    #
    # Any tables which need to be present in the FROM clause in order to select the columns.
    # relevant joins will be constructed by the parent repo.
    #
    # a 'preferred_table' hint may be passed by the repo to indicate that it'd prefer you load the
    # column off a particular table; at present this is only used by the IdentityMapper
    def columns_aliases_and_tables_for_select(preferred_table=nil)
      return [], [], []
    end

    # Obtains the value of this property from a sequel result row and/or identity value.
    #
    # where the mapper has columns_aliases_and_tables_for_select, it will get passed a result row object here
    # which contains the sql values for these columns (amongst others potentially)
    #
    # Where the identity value is available it will also be passed.
    #
    # One or other of id, row must always be passed.
    def load_value(row=nil, id=nil, version=nil)
    end

    # called inside the INSERT transaction for insertion of the given entity.
    #
    # this is called first thing before insert rows are built (via build_insert_row) for each table of the
    # repo.
    def pre_insert(entity)
    end

    # called inside the UPDATE transaction for insertion of the given entity.
    #
    # this is called first thing before update rows are built (via build_update_row) for each table of the
    # repo.
    #
    # anything returned from pre_update will be passed to post_update's data_from_pre_update arg if the
    # update succeeds.
    def pre_update(entity, update_entity)
    end

    # called inside the DELETE transaction for a given entity.
    #
    # this is called first thing before rows are deleted for each table of the repo.
    def pre_delete(entity)
    end

    # called inside the DELETE transaction for a given entity.
    #
    # this is called last thing after rows are deleted for each table of the repo.
    def post_delete(entity)
    end

    # gets this property off the entity, and sets associated keys on a sequel row hash for insertion
    # into the given table. May be passed an ID if an last_insert_id id value for the entity was previously
    # obtained from an ID sequence on insertion into another table as part of the same combined entity
    # store_new.
    #
    # this is called inside the transaction which wraps the insert, so this is effectively your pre-insert
    # hook and you can safely do other things inside it in the knowledge they'll be rolled back in the
    # event of a subsequent problem.
    def build_insert_row(entity, table, row, id=nil)
    end

    # gets this property off the update_entity, and sets associated keys on a sequel row hash for update
    # of the given table for the given entity.
    #
    # as with build_update_row, this is done inside the update transaction, it's effectively your
    # pre-update hook.
    def build_update_row(update_entity, table, row)
    end

    # used to make a sequel filter condition setting relevant columns equal to values equivalent
    # to the given property value. May raise if mapper doesn't support this
    def make_filter(value, columns_mapped_to)
      raise Persistence::UnsupportedOperation
    end

    # As for make_filter but takes multiple possible values and does a column IN (1,2,3,4) type thing.
    def make_multi_filter(values, columns_mapped_to)
      raise Persistence::UnsupportedOperation
    end

    # like load_value, but works in a batched fashion, allowing a batched loading strategy to
    # be used for associated objects.
    # takes a block and yields the loaded values one at a time to it together with their index
    def load_values(rows=nil, ids=nil, version=nil)
      if rows
        rows.each_with_index {|row, i| yield load_value(row, ids && ids[i], version), i}
      else
        ids.each_with_index {|id, i| yield load_value(nil, id, version), i}
      end
    end

    # called after rows built via build_insert_row have successfully been used in a INSERT
    # for the entity passed. Should update the entity property, where appropriate, with any default
    # values which were supplied by the repository (via default_for) on insert, and should do
    # any additional work in order to save any values which are not mapped to columns on one of the repo's
    # own :tables
    #
    # Is also passed the last_insert_id resulting from any insert, to help fill out any autoincrement
    # primary key column.
    #
    # is executed inside the same transaction as the INSERT
    def post_insert(entity, rows, last_insert_id=nil)
    end

    # called after rows built via build_update_row have successfully been used in a UPDATE
    # for the id and update_entity passed. Should update the entity property, where appropriate, with any default
    # values which were supplied by the repository (via default_for) on update, and should do
    # any additional work in order to save any values which are not mapped to columns on one of the repo's
    # own :tables
    #
    # is executed inside the same transaction as the UPDATE
    def post_update(entity, update_entity, rows, data_from_pre_update)
    end


    # A helper for declaring a dependency on another repository for a particular model class.
    #
    # These dependencies don't have to be passed at initialization time; they can be resolved afterwards
    # from a repository_set, via a call to get_repo_dependencies_from which is done when constructing via
    # a repo_set.
    #
    # Todo: split off general dependency injection logic here and in repository_set
    def repo_dependency(model_class, options={})
      dep_name = options[:name] || :target_repo
      superclass_repo_allowed = options[:allow_superclass]
      initial_value = options[:initial_value]

      instance_eval "def #{dep_name}; @#{dep_name} or raise 'missing dependency #{dep_name}'; end", __FILE__, __LINE__
      class << self; self; end.send(:define_method, "#{dep_name}=") do |repo|
        unless (superclass_repo_allowed ? repo.can_get_class?(model_class) : repo.model_class == model_class)
          raise "model_class mismatch for repository dependency of property mapper #{@property_name}"
        end
        instance_variable_set("@#{dep_name}", repo)
      end
      if initial_value
        send("#{dep_name}=", initial_value)
      else
        @unresolved_repo_deps ||= []
        @unresolved_repo_deps << [dep_name, model_class, superclass_repo_allowed]
      end
    end

    def get_repo_dependencies_from(repo_set)
      (@unresolved_repo_deps || []).each do |dep_name, model_class, superclass_repo_allowed|
        repo = if superclass_repo_allowed
          repo_set.repo_for_model_class_or_superclass(model_class) or
            raise "Couldn't find repo of model_class (or superclass of model_class) #{model_class.inspect} for property mapper #{@property_name}"
        else
          repo_set.repo_for_model_class(model_class) or
            raise "Couldn't find repo of model_class #{model_class.inspect} for property mapper #{@property_name}"
        end
        send("#{dep_name}=", repo)
      end
    end
  end
end
