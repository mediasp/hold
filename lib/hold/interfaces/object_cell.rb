module Hold
  # Interface extending Cell which offers some object-property-specific
  # persistence methods for use only with Structs/Objects.
  # Default implementations are in terms of get and set, but it's expected that
  # you'd override with more efficient implementations.
  module ObjectCell
    include Cell

    # default implementation gets the entire object in order to get the
    # property in question.  you might want to override with something more
    # efficient
    def get_property(property_name)
      (value = get) && value[property_name]
    end

    # default implementation gets the entire object and replaces it with a
    # version with the property in question changed.
    # you might want to override with something more efficient.
    def set_property(property_name, value)
      object = get
      object[property_name] = value
      set(object)
    end

    def clear_property(property_name)
      value = get
      value.delete(property_name)
      set(value)
    end

    def property?(property_name)
      get_property(property_name)
    end
    alias_method :has_property?, :property?

    def get_properties(*properties)
      properties.map { |property| get_property(property) }
    end

    # May return a Cell which allows get / set / potentially other operations
    # on a particular property of this object in the context of its parent
    # object.
    #
    # Be careful about the semantics if exposing property cells which allow
    # partial write operations (like set_property) on the property value in the
    # context of the parent object.  If you do this it should only update the
    # property value in that context, not in all contexts.
    #
    # By analogy to normal ruby hashes, it should mean this:
    #   a[:foo] = a[:foo].merge(:bar => 3)
    # rather than this:
    #   a[:foo][:bar] = 3
    # which would have an effect visible to any other object holding a
    # reference to a[:foo].
    #
    # If you want the latter, you probably want to be updating a[:foo] in some
    # hold cell which is canonical for the identity of that object.
    #
    # If you don't want the former, don't return a PropertyCell which allows
    # partial updates. For simplicity's sake this is the stance taken by the
    # default PropertyCell implementation.
    def property_cell(property_name)
      PropertyCell.new(self, property_name)
    end

    # An implementation of the basic Cell interface designed to wrap a property
    # of an ObjectCell as a Cell itself.
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

    # These are here for you to use if you want to use them for Array
    # properties gotten via ObjectCells, although the default implementation of
    # property_cell doesn't do this
    class ArrayPropertyCell < PropertyCell
      include ArrayCell
    end

    # As above
    class ObjectPropertyCell < PropertyCell
      include ObjectCell
    end
  end
end
