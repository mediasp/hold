require_relative 'hold/interfaces'
require_relative 'hold/file/hash_repository'
require_relative 'hold/sequel'

module Hold; end

module Persistence
  def self.const_missing(const_name)
    warn "'Persistence' has been deprecated, please use 'Hold' instead"
    Hold.const_get(const_name)
  end
end
