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

=begin
describe "Persistence::Serialized::IdentityHashRepository with a key_prefix" do
  behaves_like "Persistence::IdentityHashRepository"

  def make_id_hash_repo(schema)
    Persistence::Serialized::IdentityHashRepository.new(schema, {}, 'foo/')
  end

  it "should store keys in the underlying cache under the key_prefix" do
    cache = {}
    @schema = id_hash_repo_test_schema
    @repository = Persistence::Serialized::IdentityHashRepository.new(@schema, cache, 'foo/')
    entity = make_entity('id' => 1, 'abc' => 'foo', 'def' => 'bar')
    @repository.store(entity)
    assert cache.has_key?('foo/1')
  end
end

describe "Persistence::Serialized::IdentityHashRepository backed by MSP::Cache::Disk" do
  behaves_like "Persistence::IdentityHashRepository"

  def make_id_hash_repo(schema)
    require 'tmpdir'
    require 'fileutils'
    @path = File.join(Dir.tmpdir, 'msp-repo-disk-cache-test', '')
    FileUtils.rm_rf(@path)
    FileUtils.mkdir(@path)
    cache = MSP::Cache::Disk.new(@path)
    Persistence::Serialized::IdentityHashRepository.new(schema, cache)
  end

  def teardown
    super
    FileUtils.rm_rf(@path)
  end
end
=end
