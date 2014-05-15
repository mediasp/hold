#require_relative 'interfaces'
#require_relative '../lib/hold/in_memory'
#require_relative '../lib/hold/serialized'
#require_relative '../lib/hold/serialized/json_serializer'

#describe 'Hold::Serialized::HashRepository' do
  #behaves_like 'Hold::HashRepository'

  #def make_hash_repo
    #cache = Hold::InMemory::HashRepository.new
    #serializer = Hold::Serialized::JSONSerializer.new
    #Hold::Serialized::HashRepository.new(cache, serializer)
  #end
#end

#describe "Hold::Serialized::IdentitySetRepository" do
  #behaves_like "Hold::IdentitySetRepository"

  #def make_id_set_repo
    #cache = Hold::InMemory::HashRepository.new
    #serializer = Hold::Serialized::JSONSerializer.new
    #Hold::Serialized::IdentitySetRepository.new(cache, serializer)
  #end
#end
