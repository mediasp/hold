require_relative 'interfaces'
require_relative '../lib/hold/file/hash_repository'
require 'tmpdir'
require 'fileutils'

describe 'Hold::File::HashRepository' do
  behaves_like "Hold::HashRepository"

  def make_hash_repo
    @path = File.join(Dir.tmpdir, 'hold-file-repo-test', '')
    FileUtils.rm_rf(@path)
    FileUtils.mkdir(@path)
    Hold::File::HashRepository.new(@path)
  end
end
