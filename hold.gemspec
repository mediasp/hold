# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'hold/version'

Gem::Specification.new do |s|
  s.name   = "hold"
  s.version = Hold::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['MSP Devs']
  s.email = ['devs@mediasp.com']
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
  s.add_development_dependency('mocha', '~> 0.13.0')
  s.add_development_dependency('json')
  s.add_development_dependency('sqlite3')
  s.add_development_dependency('pry')

  s.add_development_dependency('pronto')
  s.add_development_dependency('pronto-rubocop')
  s.add_development_dependency('pronto-flay')
  s.add_development_dependency('pronto-reek')

  s.add_dependency('sequel', '~> 3')
  s.add_dependency('wirer', '>= 0.4.0')
  s.add_dependency('thin_models', '~> 0.2.1')

  s.files = Dir.glob("{lib}/**/*") + ['README.md']
end
