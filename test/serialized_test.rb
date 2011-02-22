require 'test/interfaces'
require 'persistence/in_memory'
require 'persistence/serialized'
require 'persistence/serialized/json_serializer'

describe "Persistence::Serialized::HashRepository" do
  behaves_like "Persistence::HashRepository"

  def make_hash_repo
    cache = Persistence::InMemory::HashRepository.new
    serializer = Persistence::Serialized::JSONSerializer.new
    Persistence::Serialized::HashRepository.new(cache, serializer)
  end
end

describe "Persistence::Serialized::IdentitySetRepository" do
  behaves_like "Persistence::IdentitySetRepository"

  def make_id_set_repo
    cache = Persistence::InMemory::HashRepository.new
    serializer = Persistence::Serialized::JSONSerializer.new
    Persistence::Serialized::IdentitySetRepository.new(cache, serializer)
  end
end
