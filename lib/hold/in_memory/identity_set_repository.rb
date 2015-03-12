module Hold
  module InMemory
    # in memory identity set repository
    class IdentitySetRepository
      include Hold::IdentitySetRepository

      def initialize(allocates_ids = false)
        @by_id = {}
        @allocates_ids = allocates_ids
      end

      def next_id
        @id_seq ||= -1
        @id_seq += 1
      end

      attr_reader :allocates_ids
      alias_method :allocates_ids?, :allocates_ids

      def assign_id(object)
        if @allocates_ids
          object.send(:id=, next_id)
        else
          fail MissingIdentity
        end
      end

      def store(object)
        id = object.id || assign_id(object)
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

      def all
        @by_id.values
      end
      alias_method :get_all, :all

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
