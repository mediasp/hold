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
end
