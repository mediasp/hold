require 'thin_models/lazy_array'

# A set of interfaces for persistence based around an object model.
#
# We're expected to use various implementations of these interfaces,
# including in-memory persistence, serialized persistence in a cache,
# persistence via mapping to a relational database, and combined database /
# cache lookup.
#
# They should also be quite easy to wrap in a restful resource layer, since
# the resource structure may often correspond closely to an object model
# persistence interface.

require 'hold/interfaces/cell'
require 'hold/interfaces/array_cell'
require 'hold/interfaces/object_cell'
require 'hold/interfaces/hash_repository'
require 'hold/interfaces/set_repository'
require 'hold/interfaces/identity_set_repository'
