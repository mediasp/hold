# If you want to observe events on a Persistence::Sequel::IdentitySetRepository
# you need to implement this interface. Stubs supplied here to save you some
# boilerplate in case you only care about certain events.
#
# The callback methods correspond to their counterparts on
# Persistence::Sequel::IdentityHashRepository but with an added argument
# passing the repository instance.
#
# TODO: generalise this to SetRepositories in general
module Persistence::Sequel::RepositoryObserver
  def pre_insert(repo, entity)
  end

  def post_insert(repo, entity, insert_rows, insert_id)
  end

  def pre_update(repo, entity, update_entity)
  end

  def post_update(repo, entity, update_entity, update_rows)
  end

  def pre_delete(repo, entity)
  end

  def post_delete(repo, entity)
  end
end
