module Hold
  module InMemory
    class IdentitySetRepository
      include Hold::IdentitySetRepository

      def initialize(allocates_ids = false)
        @by_id = {}
        @id_seq = 0 if allocates_ids
      end

      def allocates_ids?
        !@id_seq.nil?
      end

      def store(object)
        id = object.id
        object.send(:id=, id = @id_seq += 1) if @id_seq && !id
        fail MissingIdentity unless id
        @by_id[id] = object
      end

      def delete(object)
        id = object.id || (fail MissingIdentity)
        delete_id(id)
      end

      def contains?(object)
        id = object.id || (fail MissingIdentity)
        @by_id.include?(id)
      end

      def get_all
        @by_id.values
      end

      def get_by_id(id)
        (value = @by_id[id]) && value.dup
      end

      def delete_id(id)
        @by_id.delete(id)
      end

      def contains_id?(id)
        @by_id.include?(id)
      end
    end
  end
end
