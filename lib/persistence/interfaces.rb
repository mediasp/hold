require 'lazy_data/array'

module Persistence
  class Error < ::RuntimeError; end
  class UnsupportedOperation < Error; end
  class EmptyConflict < Error; end
  class IdentityConflict < Error; end
  class MissingIdentity < Error; end

  # A set of interfaces for persistence based around an object model.
  #
  # We're expected to use various implementations of these interfaces, including in-memory persistence,
  # serialized persistence in a cache, persistence via mapping to a relational database,
  # and combined database / cache lookup.
  #
  # They should also be quite easy to wrap in a restful resource layer, since the resource structure may
  # often correspond closely to an object model persistence interface.

  # The most fundamental persistence interface. Just offers a storage slot which stores a single instance,
  # supporting get/set
  module Cell
    def get
      raise UnsupportedOperation
    end

    def set(value)
      raise UnsupportedOperation
    end

    # Cells may optionally be 'emptyable?', that is, admit a special state of 'empty'
    # which is different to the state of storing an instance.
    #
    # empty and nil are distinct states.
    #
    # empty: undefined / uninitialized / unknown / not persisted / key not present in hash / missing
    # nil:   null / known to be nil / persisted explicitly as being nil / key present in hash with value of nil
    #
    # Annoying as this may seem this is useful in a bunch of contexts with the data models we're constrained to
    # be using. Eg "row exists but value of column is NULL" vs "row doesn't exist" in SQL, or "property missing"
    # vs "property present and equal to null" for JSON objects

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

    # Can override to indicate if you only support getting/setting a particular class or classes:
    def can_get_class?(klass); true; end
    def can_set_class?(klass); true; end
  end

  # Interface extending Cell which offers some array-specific persistence methods for use only
  # with Arrays.
  # Default implementations are in terms of get, but it's expected that you'd override with
  # more efficient implementations.
  module ArrayCell
    include Cell

    def get_slice(start, length)
      value = get() and value[start, length]
    end

    def get_length
      value = get() and value.length
    end

    # returns an instance of LazyData::Array which lazily computes slices and length
    # based on the get_length and get_slice methods you define.
    def get_lazy_array
      LazyArray.new(self)
    end

    def can_get_class?(klass); klass == Array; end
    def can_set_class?(klass); klass <= Array; end

    # Can override to indicate if you only support getting/setting arrays with items of a particular class or classes:
    def can_get_item_class?(klass); true; end
    def can_set_item_class?(klass); true; end

    class LazyArray < LazyData::Array::Memoized
      def initialize(array_cell)
        @array_cell = array_cell
      end

      def _each(&b)
        @array_cell.get.each(&b)
      end

      def slice_from_start_and_length(start, length)
        @array_cell.get_slice(start, length)
      end

      def _length
        @array_cell.get_length
      end
    end
  end

  # Interface extending Cell which offers some object-property-specific persistence methods for use only
  # with Structs/Objects.
  # Default implementations are in terms of get and set, but it's expected that you'd override with
  # more efficient implementations.
  module ObjectCell
    include Cell

    # default implementation gets the entire object in order to get the property in question.
    # you might want to override with something more efficient
    def get_property(property_name)
      value = get() and value[property_name]
    end

    # default implementation gets the entire object and replaces it with a version with the property
    # in question changed.
    # you might want to override with something more efficient.
    def set_property(property_name, value)
      object = get()
      object[property_name] = value
      set(object)
    end

    def clear_property(property_name)
      value = get()
      value.delete(property_name)
      set(value)
    end

    def has_property?(property_name)
      !get_property(property_name).nil?
    end

    def get_properties(*properties)
      properties.map {|p| get_property(p)}
    end

    # May return a Cell which allows get / set / potentially other operations on a particular property of
    # this object in the context of its parent object.
    #
    # Be careful about the semantics if exposing property cells which allow partial write operations
    # (like set_property) on the property value in the context of the parent object.
    # If you do this it should only update the property value in that context, not in all contexts.
    #
    # By analogy to normal ruby hashes, it should mean this:
    #   a[:foo] = a[:foo].merge(:bar => 3)
    # rather than this:
    #   a[:foo][:bar] = 3
    # which would have an effect visible to any other object holding a reference to a[:foo].
    #
    # If you want the latter, you probably want to be updating a[:foo] in some persistence cell which is
    # canonical for the identity of that object.
    #
    # If you don't want the former, don't return a PropertyCell which allows partial updates. For simplicity's
    # sake this is the stance taken by the default PropertyCell implementation.
    def property_cell(property_name)
      PropertyCell.new(self, property_name)
    end

    # An implementation of the basic Cell interface designed to wrap a property of an ObjectCell
    # as a Cell itself.
    class PropertyCell
      include Cell

      def initialize(object_cell, property_name)
        @object_cell = object_cell
        @property_name = property_name
      end

      def get
        @object_cell.get_property(@property_name)
      end

      def set(value)
        @object_cell.set_property(@property_name, value)
      end

      def empty?
        !@object_cell.has_property?(@property_name)
      end

      def clear
        @object_cell.clear_property(@property_name)
      end
    end

    # These are here for you to use if you want to use them for Array properties gotten via ObjectCells,
    # although the default implementation of property_cell doesn't do this
    class ArrayPropertyCell < PropertyCell
      include ArrayCell
    end

    class ObjectPropertyCell < PropertyCell
      include ObjectCell
    end
  end


  # Persists values in a key/value store
  module HashRepository
    def set_with_key(key, value)
      raise UnsupportedOperation
    end

    def get_with_key(key)
      raise UnsupportedOperation
    end

    # Gets multiple entities at a time by a list of keys.
    # May override with an efficient multi-get implementation.
    def get_many_with_keys(keys)
      keys.map {|key| get_with_key(key)}
    end

    def clear_key(key)
      raise UnsupportedOperation
    end

    def has_key?(key)
      raise UnsupportedOperation
    end

    def key_cell(key)
      KeyCell.new(self, key)
    end

    # Can override to indicate if you only support getting/setting values of a particular class or classes:
    def can_get_class?(klass); true; end
    def can_set_class?(klass); true; end

    class KeyCell
      include Cell

      def initialize(hash_repository, key)
        @hash_repository, @key = hash_repository, key
      end

      def get
        @hash_repository.get_with_key(@key)
      end

      def set(value)
        @hash_repository.set_with_key(@key, value)
      end

      def clear
        @hash_repository.clear_key(@key)
      end

      def empty?
        @hash_repository.has_key?(@key)
      end

      def can_get_class?(klass); @hash_repository.can_get_class?(klass); end
      def can_set_class?(klass); @hash_repository.can_set_class?(klass); end
    end
  end

  # A special kind of HashRepository which stores Objects with an identity property, indexed by their id.
  # Exposes a somewhat more familiar CRUD-style persistence interface as a result.
  #
  # Comes with default implementations for most of the extra interface; you need to override #get_with_key, #store,
  # #clear_key and #has_key?
  module IdentityHashRepository
    include HashRepository

    # alias for get_with_key; you override get_with_key
    def get_by_id(id)
      get_with_key(id)
    end

    # set_with_key implementation enforces the required constraint that key == value.id (where value.id is non-null)
    # you're expected to override #store to do that actual work.
    def set_with_key(key, value)
      raise IdentityConflict if value.id && key != value.id
      super
    end

    # You override this.
    #
    # You may be passed an object without an ID, and you may issue an identity to it prior to / during storage where
    # supported (eg an autoincrement primary key), or raise MissingIdentity where this isn't supported.
    def store(object)
      raise MissingIdentity unless object.id
      set_with_key(object.id, object)
    end

    # like store, but only works where no object already exists in the repository under this id (or where the
    # object lacks an id, although note that not all #store implementations support this)
    def store_new(object)
      id = object.id
      raise IdentityConflict if id && has_key?(id)
      store(object)
    end

    # You override clear_key; this just wraps it with a pass-the-actual-object style interface,
    # making sure the object has an ID beforehand
    def delete(object)
      id = object.id or raise MissingIdentity
      clear_key(id)
    end

    # Alias wrapper for clear_key; you override clear_key
    def delete_id(id)
      clear_key(id)
    end

    # Loads a fresh instance of the given object by its id
    # Returns nil where the object is no longer present in the repository
    def reload(object)
      id = object.id or raise MissingIdentity
      get_with_key(id)
    end

    # Like reload, but updates the given instance in-place with the updated data.
    # Returns nil where the object is no longer present in the repository
    def load(object)
      raise UnsupportedOperation unless object.respond_to?(:merge!)
      updated = reload(object) or return
      object.merge!(updated)
      object
    end

    # Applies an in-place update to the object, where it exists in the repository
    def update(entity, update_entity)
      raise UnsupportedOperation unless entity.respond_to?(:merge!)
      load(entity) or return
      id = entity.id
      entity.merge!(update_entity)
      set_with_key(id, entity)
      entity
    end

    # Applies an in-place update to the object with the given identity, where it exists in the repository
    def update_by_id(id, update_entity)
      entity = get_by_id(id) or return
      raise UnsupportedOperation unless entity.respond_to?(:merge!)
      entity.merge!(update_entity)
      set_with_key(id, entity)
      entity
    end

    def contains?(object)
      id = object.id or raise MissingIdentity
      has_key?(id)
    end

    def contains_id?(id)
      has_key?(id)
    end


    def get_many_by_ids(ids)
      get_many_with_keys(ids)
    end

    # Uses get_many_by_ids
    def reload_many(entities)
      ids = entities.map {|entity| entity.id or raise MissingIdentity}
      get_many_by_ids(ids)
    end


    # Basic query API based on properties.
    # May not be supported on all properties or by all repos.
    def get_many_by_property(property, value)
      raise UnsupportedOperation
    end

    def get_by_property(property, value)
      raise UnsupportedOperation
    end




    def key_cell(key)
      KeyCell.new(self, key)
    end

    def id_cell(id)
      key_cell(id)
    end

    def cell(object)
      id = object.id or raise MissingIdentity
      key_cell(id)
    end

    class KeyCell < HashRepository::KeyCell
      include ObjectCell
    end
  end
end
