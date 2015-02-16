module Hold
  module SetRepository
    # Store the object in the persisted set. If the object is already in the
    # set, it may stay there untouched (in the case where the object's identity
    # is based on its entire contents), or get replaced by the newer version
    # (where the object's identity is only based on, say, some identity
    # property), but will never be duplicated (since this is a set)
    def store(object)
      raise UnsupportedOperation
    end

    # like store, but should raise IdentityConflict if the object (or one equal
    # to it) already exists in the set
    def store_new(object)
      raise IdentityConflict if contains?(object)
      store(object)
    end

    # Removes the object with this identity from the persisted set
    def delete(object)
      raise UnsupportedOperation
    end

    # Is this object in the persisted set?
    def contains?(object)
      raise UnsupportedOperation
    end

    # Returns an array of all persisted items in the set
    def get_all
      raise UnsupportedOperation
    end

    def can_get_class?(klass); true; end
    def can_set_class?(klass); true; end
  end
end
