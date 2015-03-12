module Hold
  # Error tag module
  module Error; end

  # Base error for Hold module
  class StdError < StandardError
    extend Error

    def initialize(msg = nil, original = $ERROR_INFO)
      super(msg)
      @original = original
    end
  end

  # Unsupoorted Operation
  class UnsupportedOperation < StdError; end

  # Empty Conflict
  class EmptyConflict < StdError; end

  # Identity Conflict
  class IdentityConflict < StdError; end

  # Missing Identity
  class MissingIdentity < StdError; end

  # Foreign Key Conflict
  class ForeignKeyConflict < StdError
    def initialize(property, fk_property)
      @msg = 'OneToMany mapper: one of the values for mapped property '\
        "#{property} has an existing value for the corresponding "\
        "#{fk_property} property which is not equal to our good selves"
    end
  end

  # Order Property Conflict
  class OrderPropertyConflict < StdError
    def initialize(property, order_property)
      super('OneToMany mapper: one of the new values for mapped '\
        "property #{property} has an existing value for the "\
        "order property #{order_property} property which is not "\
        'equal to its index in the array')
    end
  end

  # No Repository Found
  class NoRepoFound < StdError
    def initialize(type)
      super("PolymorphicRepository: no repo found for type #{type}")
    end
  end

  # Expected Foreign Key
  class ExpectedForeignKey < StdError
    def initialize(property)
      super("OneToManyMapper: Expected ForeignKey mapper with name #{property}")
    end
  end

  # Mismatched Target
  class MismatchedTarget < StdError
    def initialize(target_repo, model)
      super("OneToManyMapper: ForeignKey mapper's target repo "\
      "#{target_repo.inspect} can't get our repository's "\
      "model_class #{model}")
    end
  end

  # Already Persisted
  class AlreadyPersisted < StdError
    def initialize
      super('OneToMany mapper: already-persisted values are only '\
        'allowed for property update where they were already a value '\
        'of the property beforehand')
    end
  end

  # No ID
  class NoID < StdError
    def initialize(property)
      super("value for ManyToMany mapped property #{property} has no "\
        'id, and :auto_store_new not specified')
    end
  end
end
