require 'persistence/interfaces'
require 'fileutils'

# A simple HashRepository (ie key/value store implementation) which stores each
# key in a separate file.
#
# * Keys must be suitable pathnames
# * Values must be strings
# * base_path should end with a /, or keys should start with a /, one or the other
# * subdirectories will be created as required if the keys contain path separators
# * watch out for per-directory file limits.
#
# NB: Not threadsafe for writes
module Persistence
  module File; end

  class File::HashRepository
    include Persistence::HashRepository

    def can_get_class?(klass); klass == String; end
    def can_set_class?(klass); klass == String; end

    def initialize(base_path)
      @base_path = base_path
    end

    def path_to_key(key)
      "#{@base_path}#{key}"
    end

    def set_with_key(key, value)
      path = path_to_key(key)
      FileUtils.mkdir_p(::File.dirname(path))
      ::File.open(path, "wb") {|file| file.write(value.to_s)}
      value
    end

    def get_with_key(key)
      path = path_to_key(key)
      begin
        ::File.read(path)
      rescue Errno::ENOENT
      end
    end

    def clear_key(key)
      path = path_to_key(key)
      begin
        ::File.unlink(path)
      rescue Errno::ENOENT
      end
    end

    def has_key?(key)
      ::File.exist?(path_to_key(key))
    end
    alias_method :key?, :has_key?
  end
end
