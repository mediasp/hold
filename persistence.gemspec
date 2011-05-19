# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'persistence/version'

spec = Gem::Specification.new do |s|
  s.name   = "persistence"
  s.version = Persistence::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson']
  s.email = ["matthew@playlouder.com"]
  s.summary = "A library geared towards separating persistence concerns from data model classes"

  s.add_development_dependency('test-spec')
  s.add_development_dependency('mocha')
  s.add_development_dependency('json')
  s.add_development_dependency('sqlite3')
  s.add_dependency('sequel', '~> 3.11.0')
  s.add_dependency('wirer', '~> 0.4.0')
  s.add_dependency('lazy-data', '~> 0.1.0')

  s.files = Dir.glob("{lib}/**/*") + ['README.txt']
end
