module Hold
  module Sequel
    # If you want to observe events on a Hold::Sequel::IdentitySetRepository
    # you need to implement this interface. Stubs supplied here to save you some
    # boilerplate in case you only care about certain events.
    #
    # The callback methods correspond to their counterparts on
    # Hold::Sequel::IdentityHashRepository but with an added argument
    # passing the repository instance.
    #
    # TODO: generalise this to SetRepositories in general
    module RepositoryObserver
      def pre_insert(_repo, _entity)
      end

      def post_insert(_repo, _entity, _insert_rows, _insert_id)
      end

      def pre_update(_repo, _entity, _update_entity)
      end

      def post_update(_repo, _entity, _update_entity, _update_rows)
      end

      def pre_delete(_repo, _entity)
      end

      def post_delete(_repo, _entity)
      end
    end
  end
end
