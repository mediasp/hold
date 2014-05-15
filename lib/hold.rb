require_relative 'hold/interfaces'
require_relative 'hold/file/hash_repository'
require_relative 'hold/sequel'

module Hold; end
Persistence = Hold

module Kernel
  def self.const_missing(const_name)
    super unless const_name == :Persistence
    warn "'Persistence' has been deprecated, please use 'Hold' instead"
    Hold
  end
end
