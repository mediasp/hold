require 'hold/interfaces'
require 'hold/file/hash_repository'
require 'hold/sequel'

require 'hold/error'

# Top level namespace
module Hold
end

unless defined?(Persistence)

  # Display a warning if the old gem name is used.
  module Persistence
    def self.const_missing(const_name)
      warn "'Persistence' has been deprecated, please use 'Hold' instead"
      Hold.const_get(const_name)
    end
  end
end
