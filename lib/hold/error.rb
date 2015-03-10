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
end
