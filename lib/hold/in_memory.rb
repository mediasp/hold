require 'hold/in_memory/cell'
require 'hold/in_memory/array_cell'
require 'hold/in_memory/object_cell'
require 'hold/in_memory/hash_repository'
require 'hold/in_memory/set_repository'
require 'hold/in_memory/identity_set_repository'

# namespace module
module Hold
  # These are a set of implementations of Hold interfaces based on in-memory
  # storage.  They're not threadsafe or for production use, but are here as
  # lightweight implementations to use in tests, and for illustrative purposes.
  module InMemory; end

  ARG_EMPTY = Object.new.freeze # something different to everything else
end
