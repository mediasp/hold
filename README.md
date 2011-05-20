# Persistence

A ruby library geared towards separating persistence concerns from data model classes. It contains a set of interfaces for and implementations of the Repository pattern (http://martinfowler.com/eaaCatalog/repository.html) in Ruby.

To summarize, the idea is that

* You have Repositories which are responsible for persisting objects in a data store
* Your data objects know nothing about persistence. They are just 'plain old' in-memory ruby objects can be created and manipulated independently of any particular repository.

This is a substantially different approach to the 'Active Record' pattern (http://martinfowler.com/eaaCatalog/activeRecord.html), which is the approach that most persistence libraries in the Ruby world use, including (surprise surprise) ActiveRecord, but also Datamapper and Sequel::Model.

Of course there are various trade-offs involved when choosing between these two approaches. ActiveRecord is a more lightweight approach which is often preferred for small-to-mid-sized database-backed web applications where the data model is tightly coupled to a database schema; whereas Repositories start to show benefits when it comes to, eg:

* Separation of concerns in a larger system; avoiding bloated model classes with too many responsibilities
* Ease of switching between alternative back-end data stores, eg database-backed vs in-memory; in particular, in order to avoid database dependencies when testing
* Systems which persist objects in multiple data stores -- eg in a relational database, serialized in a key-value cache, serialized in config files, ...
* Decoupling the structure of your data model from the schema of the data store used to persist it

## Interfaces

At the core of our approach is to define interfaces for the most common kinds of persistence objects. It being Ruby, you could just implement them just via duck-typing, but we also define some modules which serve to illustrate the method signatures, and provide a handful of default implementations and conveniences around the core interface.

(We also have some shared test suites which are intended to validate that a particular implementation complies with the contract; a TODO is to make these reusable outside this gem).

On one level, you could just use these interfaces and nothing else -- we supply some implementations of them, but you may prefer to make your own, and in some cases this may be the simplest and most explicit way to proceed.

### Rationale

When trying to capture the concept of a repository, a common approach seems to be to define one big interface which tries to subsume all sorts of different kinds of data store (key-value store, array-like collection, set, full-blown relational or semi-relational datastore), where you sort of pick and choose which bits of it to implement.

This is a bit clunky; here we've tried to break it up into some more fine-grained interfaces for particular kinds of data stores, starting at the simplest possible: a Cell, and working our way up to an IdentitySetRepository, which corresponds to the CRUD-style interface of a typical object store which stores objects indexed by their identity.

Nevertheless, it would be possible to go even further in terms of breaking up into more fine-grained interfaces, for example separating out the reading and writing portions of the interfaces. Tricky call where exactly to cut off with this stuff, especially in ruby which is duck-typed, meaning you don't have to give a formal name to some subset of an interface in order to use it in practise. It would also be possible to define even richer interfaces beyond that of IdentitySetRepository, eg adding an interface for querying the store based on critera other than just the id, but we've not formalised this yet.

### Persistence::Cell

This is pretty much the simplest persistence interface possible. It represents a 'cell' in which a single item of data can be stored; the cell responds to 'get' and 'set' which do the obvious with respect to the data stored in it.

#### Empty Cells

Cells may optionally support being in an 'empty' state, ie a state where no data is stored in them. They should then also respond to 'clear' to clear out the call, and 'empty?' to determine whether or not the cell has anything stored in it.

Where desired, this may be used to draw a distinction between "set to nil" / "known to be nil" and "not defined" / "not known".

### Persistence::ObjectCell

An ObjectCell is a Cell which stores Objects with named properties. Ontop of the Cell interface, it also supports getting and setting the values of individual properties of the object contained with it, via get_property and set_property. (It can also support properties being empty/missing, via clear_property and has_property?)

You can ask it for a property_cell, which will return you a Cell wrapping a particular property of the object contained within it.

### Persistence::ArrayCell

A Cell which stores an ordered collection of values, and also supports random access to them via get_slice, and getting of the length of the collection via get_length.

### Persistence::HashRepository

A Hash-like interface for a simple key-value store, which can get and set objects by a key. get_with_key / set_with_key / has_key? / clear_key. May also support an optimised get_many_with_keys to get multiple keys at once, for which a default implementation is supplied.

### Persistence::SetRepository

Interface for a store which contains a set of values. Supports adding (store) and removing (delete) them, membership test (contains?) and potentially iteration over all the values in the store (get_all). But doesn't necessarily support any kind of indexed lookup.

### Persistence::IdentitySetRepository

A SetRepository which stores objects with identity (so Entities rather than just Value objects). In addition to the SetRepository interface it supports lookup of objects by their ID. Given that objects have identities which are independent of their values, it then makes sense to talk about 'updating' an object in the store, i.e. replacing it with an updated version with the same identity. This corresponds well to the common "database table with a primary key" type model.

IdentitySetRepository implementations may well add support for various other kinds of indexed lookup, although we haven't fully formalised interfaces for these, maybe look at how Persistence::Sequel::IdentitySetRepository does it for now.

## In-memory implementations

For each of the above interfaces, there's a corresponding in-memory implementation in Persistence::InMemory.

These are intended to illustrate how the interface is intended to work, and to be useful for testing purposes if you want an alternative in-memory mock implementation of some repository in order to avoid a dependency on a database.

They're quite simple, not really intended for production use, and not designed to be threadsafe (although wouldn't be too hard to make them so).

## Serialized persistence

A common way of persisting objects is to serialize them into a string, and then persist that string somewhere (in a key-value store, as a file on disk...).

Persistence::Serialized::HashRepository and Persistence::Serialized::IdentitySetRepository provide implementations of these interfaces which serialize and deserialize the object to/from a string, before/after persisting them in an underlying string-based HashRepository. You need to pass it this underlying store, and a serializer, eg Persistence::Serialized::JSONSerializer.

## Sequel-backed persistence

This is the biggest implementation of Persistence::IdentitySetRepository, and is done ontop of the database connection facilities and SQL-building DSL of the excellent Sequel library.

It's essentially a mini ORM, but, unlike other Ruby ORMs, is based on the Repository pattern instead of an ActiveRecord-style approach; meaning you will have separate repository classes and data model classes. The nearest things you might compare it with might be Hibernate in the Java world, or SQLAlchemy in the Python, although it's not trying to be quite as fully-featured as these. In particular it doesn't have the concept of a "session" or "unit of work", and it's not quite so clever about persisting changes to large object graphs all in one go. (These might be useful additions at some point, but would take some care to do well).

Here follows a selection of the core features of Persistence::Sequel, with some usage examples in each case:

### Creating a repository for a simple data model class

### Basic CRUD

### Database-supplied ID sequences

### Lazy loading with LazyData::Struct model classes

One of the downsides of decoupling data model classes from persistence concerns is that, because the model objects have no connection with the data source they came from, you may have to go back to the repository if you want to load additional properties or associations on them. This means that you end up worrying too much about exactly which properties to fetch eagerly at which point in order to ensure the right things are loaded.

There's a solution to this though, which is if you use a model class which supports lazily-evaluated properties. THe model instance doesn't need to know anything about the details of the data store it's fetched from -- the repository just supplies properties to the constructor in the form of a block which can be called lazily to load them, rather than as an actual hash of values.

As it stands, you'll need to make your model class a subclass of LazyData::Struct (from the lazy-data gem) in order to take advantage of this. In fact, at present we kinda assume that you're using LazyData::Struct in general; a TODO is to remove the dependency on this, which shouldn't be too hard to do but hasn't been a priority yet.

### Control over which properties get loaded eagerly

### Mapping associations between different persisted model classes

### Wiring up repositories so they can load associations

When you start decoupling things like repositories from the model classes, it becomes more of a challenge to wire up a graph of repositories for different classes, since they may need to know about eachother in order to load associations, and they can't just find eachother in the global scope as is the case with ActiveRecord classes.

You can wire them up yourself if you want, but Persistence::Sequel also supports the use of Wirer, a dependency injection library, to wire up repositories. It's recommended to use this if the data model you're persisting has more than a handful of inter-related object types, as it would be quite a pain to do it manually. If you choose to use Wirer you'll find that subclasses of Persistence::Sequel::IdentitySetRepository automatically expose the Wirer::Factory::Interface required for them to be added into a container and hooked up with their dependencies.

### Extensible PropertyMapper interface

### Class-table and single-table inheritance mapping

### Polymorphic loading

### Observing actions on a repository

### Some rough edges / TODOs

### Roadmap

In no particular order:

- Chaining repositories, so you can put a Serialized cache repository infront of a Sequel repository in order to cache certain serialized versions of objects before hitting the database, with options for whether to write_on_miss etc.
  - Formalising an interface which allows you to specify which 'version' of an object you want to fetch, eg you might fetch full or partial versions. Lazy loading makes this less necessary, *but* it is going to be more useful when it comes to loading objects from a serialized cache
- Overall tidyup of (and better test coverage for) the Sequel code
- Some performance optimisations for Sequel repositories, in particular to the way lazy loading works
- Formalising some concept of the schema of ruby objects which repositories are designed to persist
- Database-backed implementations of other simpler Persistence interfaces like HashRepository, SetRepository and ArrayCell
- Support for Identity Map and Unit of Work patterns (a biggie)
- Implementations of the Persistence interfaces for some NoSQL datastores (eg Redis would be nice)
