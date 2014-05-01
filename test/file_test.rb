require_relative 'interfaces'
require_relative '../lib/persistence/file/hash_repository'
require 'tmpdir'
require 'fileutils'

describe 'Persistence::File::HashRepository' do
  behaves_like "Persistence::HashRepository"

  def make_hash_repo
    @path = File.join(Dir.tmpdir, 'persistence-file-repo-test', '')
    FileUtils.rm_rf(@path)
    FileUtils.mkdir(@path)
    Persistence::File::HashRepository.new(@path)
  end
end
