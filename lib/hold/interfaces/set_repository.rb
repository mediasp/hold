module Hold
  module SetRepository
    # like store, but should raise IdentityConflict if the object (or one equal
    # to it) already exists in the set
    def store_new(object)
      fail IdentityConflict if contains?(object)
      store(object)
    end

    def can_get_class?(_)
      true
    end

    def can_set_class?(_)
      true
    end
  end
end
