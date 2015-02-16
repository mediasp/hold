module Hold
  # The most fundamental persistence interface. Just offers a storage slot
  # which stores a single instance, supporting get/set
  module Cell
    def value
      raise UnsupportedOperation
    end

    def value=(value)
      raise UnsupportedOperation
    end

    # Cells may optionally be 'emptyable?', that is, admit a special state of
    # 'empty' which is different to the state of storing an instance.
    #
    # empty and nil are distinct states.
    #
    # empty: undefined / uninitialized / unknown / not persisted / key not
    # present in hash / missing nil:   null / known to be nil / persisted
    # explicitly as being nil / key present in hash with value of nil
    #
    # Annoying as this may seem this is useful in a bunch of contexts with the
    # data models we're constrained to be using. Eg "row exists but value of
    # column is NULL" vs "row doesn't exist" in SQL, or "property missing" vs
    # "property present and equal to null" for JSON objects

    def empty?
      false
    end

    def clear
      raise UnsupportedOperation
    end

    def set_if_empty(value)
      raise EmptyConflict unless empty?
      set(value)
    end

    def set_unless_empty(value)
      raise EmptyConflict if empty?
      set(value)
    end

    def get_unless_empty
      raise EmptyConflict if empty?
      get
    end
    alias :get! :get_unless_empty

    # Can override to indicate if you only support getting/setting a particular
    # class or classes:
    def can_get_class?(_class)
      true
    end

    def can_set_class?(_class)
      true
    end
  end
end
