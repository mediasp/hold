require 'test/interfaces'
require 'persistence/file/hash_repository'
require 'tmpdir'
require 'fileutils'

describe "Persistence::File::HashRepository" do
  behaves_like "Persistence::HashRepository"

  def make_hash_repo
    @path = File.join(Dir.tmpdir, 'msp-repo-disk-cache-test', '')
    FileUtils.rm_rf(@path)
    FileUtils.mkdir(@path)
    Persistence::File::HashRepository.new(@path)
  end
end
