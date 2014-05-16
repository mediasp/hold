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

  To summarize, the idea is that

  * You have Repositories which are responsible for persisting objects in a data store
  * Your data objects know nothing about persistence. They are just 'plain old' in-memory ruby objects can be created and manipulated independently of any particular repository.

  This is a substantially different approach to the widely used ActiveRecord pattern.

  Of course there are various trade-offs involved when choosing between these two approaches. ActiveRecord is a more lightweight approach which is often preferred for small-to-mid-sized database-backed web applications where the data model is tightly coupled to a database schema; whereas Repositories start to show benefits when it comes to, e.g.:

  * Separation of concerns in a larger system; avoiding bloated model classes with too many responsibilities
  * Ease of switching between alternative back-end data stores, e.g. database-backed vs persisted-in-a-config-file vs persisted in-memory. In particular, this can help avoid database dependencies when testing
  * Systems which persist objects in multiple data stores -- e.g. in a relational database, serialized in a key-value cache, serialized in config files, ...
  * Decoupling the structure of your data model from the schema of the data store used to persist it
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
