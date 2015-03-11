module Hold
  # Error tag module
  module Error; end

  # Base error for Hold module
  class StdError < StandardError
    extend Error

    attr_reader :original

    def initialize(msg = nil, original = $ERROR_INFO)
      super(msg)
      @original = original
    end
  end

  # UnsupoortedOperation
  class UnsupportedOperation < StdError; end

  # EmptyConflict
  class EmptyConflict < StdError; end

  # IdentityConflict
  class IdentityConflict < StdError; end

  # MissingIdentity
  class MissingIdentity < StdError; end

  class ForeignKeyConflict < StdError
    def initialize(property, fk_property)
      @msg = 'OneToMany mapper: one of the values for mapped property '\
        "#{property} has an existing value for the corresponding "\
        "#{fk_property} property which is not equal to our good selves"
    end
  end

  class OrderPropertyConflict < StdError
    def initialize(property, order_property)
      @msg = 'OneToMany mapper: one of the new values for mapped '\
        "property #{property} has an existing value for the "\
        "order property #{order_property} property which is not "\
        'equal to its index in the array'
    end
  end

  class NoRepoFound < StdError
    def initialize(type)
      @msg = "PolymorphicRepository: no repo found for type #{type}"
    end
  end

  class ExpectedForeignKey < StdError
    def initialize(property)
      @msg = "OneToManyMapper: Expected ForeignKey mapper with name #{property}"
    end
  end

  class MismatchedTarget < StdError
    def initialize(target_repo, model)
      @msg = "OneToManyMapper: ForeignKey mapper's target repo "\
      "#{target_repo.inspect} can't get our repository's "\
      "model_class #{model}"
    end
  end

  class AlreadyPersisted < StdError
    def initialize
      @msg = 'OneToMany mapper: already-persisted values are only '\
        'allowed for property update where they were already a value '\
        'of the property beforehand'
    end
  end

  class NoID < StdError
    def initialize(property)
      @msg = "value for ManyToMany mapped property #{property} has no "\
        'id, and :auto_store_new not specified'
    end
  end
end
