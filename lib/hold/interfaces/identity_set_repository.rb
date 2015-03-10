module Hold
  # A special kind of SetRepository which stores Objects whose identities are
  # determined by an identity property, and supports indexed lookup by their
  # id.
  #
  # May allocate the IDs itself, or not.
  #
  # Exposes a somewhat more familiar CRUD-style persistence interface as a
  # result.
  #
  # Comes with default implementations for most of the extra interface
  module IdentitySetRepository
    include SetRepository

    # Either the repository allocates IDs, and you don't (in which case any
    # entity with an ID may be assumed to be already persisted in the repo), or
    # the repository doesn't allocate IDs (in which case you must always supply
    # one when persisting a new object).
    #
    # If you allocates_ids?, you should deal with an object without an identity
    # as an argument to store and store_new, and you should set the id property
    # on it before returning it.
    #
    # If you don't, you may raise MissingIdentity if passed an object without
    # one.
    def allocates_ids?
      false
    end

    # deletes the object with the given identity where it exists in the repo
    def delete_id(id)
      delete(get_by_id(id))
    end

    # Loads a fresh instance of the given object by its id
    # Returns nil where the object is no longer present in the repository
    def reload(object)
      id = object.id || (fail MissingIdentity)
      get_by_id(id)
    end

    # Like reload, but updates the given instance in-place with the updated
    # data.
    # Returns nil where the object is no longer present in the repository
    def load(object)
      fail UnsupportedOperation unless object.respond_to?(:merge!)
      updated = reload(object) || (return)
      object.merge!(updated)
      object
    end

    # Applies an in-place update to the object, where it exists in the
    # repository
    def update(entity, update_entity)
      fail UnsupportedOperation unless entity.respond_to?(:merge!)
      load(entity) || return
      entity.merge!(update_entity)
      store(entity)
    end

    # Applies an in-place update to the object with the given identity, where
    # it exists in the repository
    def update_by_id(id, update_entity)
      entity = get_by_id(id) || (return)
      fail UnsupportedOperation unless entity.respond_to?(:merge!)
      entity.merge!(update_entity)
      store(entity)
    end

    def contains_id?(id)
      !get_by_id(id).nil?
    end

    def get_many_by_ids(ids)
      ids.map { |id| get_by_id(id) }
    end

    def id_cell(id)
      IdCell.new(self, id)
    end

    def cell(object)
      id = object.id || (fail MissingIdentity)
      id_cell(id)
    end

    class IdCell
      include ObjectCell

      def initialize(id_set_repo, id)
        @id_set_repo = id_set_repo
        @id = id
      end

      def get
        @id_set_repo.get_by_id(@id)
      end

      def set(value)
        @id_set_repo.update_by_id(@id, value)
      end

      def empty?
        !@id_set_repo.contains?(@id)
      end

      def clear
        @id_set_repo.delete_id(@id)
      end
    end
  end
end
