# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'hold/version'

spec = Gem::Specification.new do |s|
  s.name   = "hold"
  s.version = Hold::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson', 'Nick Griffiths']
  s.email = ["mark@mediasp.com", "tom@mediasp.com", "devs@mediasp.com"]
  s.summary = 'A library geared towards separating persistence concerns from data model classes'
  s.description = <<-DESC
  A persistence library based more closely on the repository model.
  Used in production for several years.
DESC
  s.homepage = 'https://github.com/mediasp/hold'
  s.license = 'MIT'

  s.add_development_dependency('rake')
  s.add_development_dependency('test-unit', '~> 1.2')
  s.add_development_dependency('test-spec')
  s.add_development_dependency('mocha', '~> 0.7')
  s.add_development_dependency('json')
  s.add_development_dependency('sqlite3')
  s.add_dependency('sequel', '~> 3')
  s.add_dependency('wirer', '>= 0.4.0')
  s.add_dependency('thin_models', '~> 0.1.4')

  s.files = Dir.glob("{lib}/**/*") + ['README.md']
end
