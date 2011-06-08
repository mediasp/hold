# Persistence

A ruby library geared towards separating persistence concerns from data model classes. It contains a set of interfaces for and implementations of the Repository pattern (http://martinfowler.com/eaaCatalog/repository.html) in Ruby.

To summarize, the idea is that

* You have Repositories which are responsible for persisting objects in a data store
* Your data objects know nothing about persistence. They are just 'plain old' in-memory ruby objects can be created and manipulated independently of any particular repository.

This is a substantially different approach to the 'Active Record' pattern (http://martinfowler.com/eaaCatalog/activeRecord.html), which is the approach that most persistence libraries in the Ruby world use, including (surprise surprise) ActiveRecord, but also Datamapper and Sequel::Model.

Of course there are various trade-offs involved when choosing between these two approaches. ActiveRecord is a more lightweight approach which is often preferred for small-to-mid-sized database-backed web applications where the data model is tightly coupled to a database schema; whereas Repositories start to show benefits when it comes to, eg:

* Separation of concerns in a larger system; avoiding bloated model classes with too many responsibilities
* Ease of switching between alternative back-end data stores, eg database-backed vs persisted-in-a-config-file vs persisted in-memory. In particular, this can help avoid database dependencies when testing
* Systems which persist objects in multiple data stores -- eg in a relational database, serialized in a key-value cache, serialized in config files, ...
* Decoupling the structure of your data model from the schema of the data store used to persist it

## Interfaces

At the core of our approach is to define interfaces for the most common kinds of "things which persist stuff". It being Ruby, you could just implement them just via duck-typing, but we also define some modules which serve to illustrate the method signatures, and provide a handful of default implementations and conveniences around the core interface, and as a 'marker' for the interface (since in general, `duck.is_a?(Quacker)` is easier than `[:quack_loudly, :quack_quietly, ...].each {|m| duck.respond_to?(m)}`).

(We also have some shared test suites which are intended to validate that a particular implementation complies with the contract; a TODO is to make these reusable outside this gem).

On one level, you could just use these interfaces and nothing else -- we supply some implementations of them, but you may prefer to make your own, and in some cases this may be the simplest and most explicit way to proceed.

### Rationale

One approach which I've seen is to define one big 'store' interface which tries to subsume all sorts of different kinds of data store (key-value store, array-like collection, set, full-blown relational or semi-relational datastore), where you sort of pick and choose which bits of it to implement.

This is a bit clunky; here I've tried to break it up into some more fine-grained interfaces for particular kinds of data stores, starting at the simplest possible: a Cell, and working our way up to an IdentitySetRepository, which corresponds to the CRUD-style interface of a typical object store which stores objects indexed by their identity.

Nevertheless, it would be possible to go even further in terms of breaking up into more fine-grained interfaces, for example separating out the reading and writing portions of the interfaces. Tricky call where exactly to cut off with this stuff, especially in ruby which is duck-typed, meaning you don't have to give a formal name to some subset of an interface in order to use it in practise. It would also be possible to define even richer interfaces beyond that of IdentitySetRepository, eg adding an interface for querying the store based on critera other than just the id, but we've not formalised this yet.

One other thing which it might be worth adding interfaces for is transactionality. It's a tricky one though; while it'd be easy enough to add a 'transaction do ...' to the interface of individual repositories, often you'll have multiple repositories running off the same underlying database which you want to use inside the same transaction context. So for now transactional stuff isn't abstracted away from the underlying persistence mechanism; if you're using Sequel, you can just call .transaction on the underlying Sequel database for example. If you wanted more serious abstraction around transactions, it might be best done as part of adding support for the 'unit of work' pattern used by libraries like Hibernate, SQLAlchemy etc.

Would be worth doing a review of the interface design here once we have some more implementations going, to see what works and what doesn't, what needs adjusting etc.

### Persistence::Cell

This is pretty much the simplest persistence interface possible. It represents a 'cell' in which a single item of data can be stored; the cell responds to 'get' and 'set' which do the obvious with respect to the data stored in it.

#### Empty Cells

Cells may optionally support being in an 'empty' state, ie a state where no data is stored in them. They should then also respond to 'clear' to clear out the call, and 'empty?' to determine whether or not the cell has anything stored in it.

This allows distinctions to be drawn between eg "present in the hash but set to nil" and "not present in the hash", or "loaded and known to be nil" vs "not loaded", which are quite common distinctions to be found in data structures used for persistence.

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

Here follows a selection of the core features of Persistence::Sequel, with some usage examples in each case.

For this I'll use the following schema:

    create table authors (
      id int not null auto_increment primary key,
      title varchar(255) not null,
      fave_breakfast_cereal varchar(255)
    );
    create table books (
      id int not null auto_increment primary key,
      created_at datetime not null,
      updated_at datetime,
      title varchar(255) not null,
      author_id int not null,
      foreign key (author_id) references authors (id)
    );
    create table influenced_by (
      author_id int not null,
      book_id int not null,
      primary key (author_id, book_id),
      foreign key (author_id) references authors (id),
      foreign key (book_id) references books (id)
    );

### Creating a repository for a simple data model class

There is a class-based DSL which is used to configure a new repository class. The simplest example would be:

    Author = LazyData::StructWithIdentity(:title, :fave_breakfast_cereal)

    class AuthorRepository < Persistence::Sequel::IdentitySetRepository
      set_model_class Author
      use_table :authors, :id_sequence => true
      map_column :title
      map_column :fave_breakfast_cereal
    end

About the model class:

- There is a basic protocol which your model class needs to observe, in order to work here, so the repository can create, update and read the properties off model instances. For now, the only officially-supported model classes are subclasses of LazyData::Struct from the lazy_data gem, and it's best to look at this for reference. High on the TODO list though is to make it clear exactly what interface you need to support, and to test against some different model class implementations. There's certainly nothing in principle stopping it working with a very basic lightweight plain-old-ruby model class; in fact LazyData pretty much is just one of these, plus some small conveniences (including support for lazy property loading).

- The model class is also required to have an attribute called 'id', and to implement the :==/:eql/:hash contract based on this id property. LazyData::StructWithIdentity is the best way of achieving this at present.

About the table:

- The table must have a single-column primary key. By default it's assumed to be called 'id', but you can override this by specifying `use_table :foo, :id_column => :bar`
- There is support for tables whose primary key is autogenerated via a sequence/autoincrement, or equally for tables whose primary key is not autogenerated. If you have database-generated primary keys, you need to specify :id_sequence => true.

About `map_column`

- This maps a property on the model class, to a database column with (by default) the same name.
- For now you'll need to do this explicitly for any model class property which you want to be persisted to and from a database column.
- Any database columns which aren't mapped will just be silently ignored, as will any unmapped attributes on the model class.
- TODO: maybe either warn about unmapped properties on the model class, or supply default mappings for them

Note that a database connection is *not* required in order to declare one of these classes, only to instantiate one. This is most definitely intentional; we don't want to require that a database connection be present and active at code loading time.

### Basic CRUD

    db = Sequel.connect("foo://bar", :logger => Logger.new(STDOUT))
    author_repo = AuthorRepository.new(db)

    > author = Author.new(:title => 'Joe')
    > author_repo.store_new(author)
    INSERT INTO `authors` (`title`) VALUES ('Joe')
     => #<Author:0x1018f4b28 @values={:title=>"Joe", :id=>1}>

    > author_repo.get_by_id(1)
    SELECT `authors`.`title` AS `authors_title`, `authors`.`fave_breakfast_cereal` AS `authors_fave_breakfast_cereal`, `authors`.`id` AS `id` FROM `authors` WHERE (`authors`.`id` = 1) LIMIT 1
     => #<Author:0x1018d6bf0 lazy, @values={:title=>"foo", :fave_breakfast_cereal=>nil, :id=>1}>

    > author_repo.update(author, :title => 'Joe Bloggs')
    UPDATE `authors` SET `title` = 'Joe Bloggs' WHERE (`id` = 1)
     => #<Author:0x1018f4b28 @values={:title=>"Joe Bloggs", :id=>1}>

    > author_repo.delete(author)
    DELETE FROM `authors` WHERE (`id` = 1)
     => nil

IdentitySetRepositories also support the more general 'store' method from the SetRepository interface - which in the context means, if it's not already persisted, insert it, otherwise update it:

    > author = Author.new(:id => 123, :title => 'Test')
    > author_repo.store(author)
    SELECT 1 FROM `authors` WHERE (`id` = 123) LIMIT 1
    INSERT INTO `authors` (`title`, `id`) VALUES ('Test', 123)
     => #<Author:0x1018c8578 @values={:title=>"Test", :id=>123}>

    > author.title = "Changed"
     => "Changed"
    > author_repo.store(author)
    SELECT 1 FROM `authors` WHERE (`id` = 123) LIMIT 1
    UPDATE `authors` SET `title` = 'Changed' WHERE (`id` = 123)

Where it does an extra query first to figure out if the object is already persisted. (If you're wondering why it doesn't just do a `REPLACE INTO`, then the ruby code wouldn't know ahead of time if it's inserting or updating, which makes it harder to fire pre_insert/pre_update hooks and for the created_at/updated_at property mappers to work).

Note that this is not the preferred way to do things if you actually know what you want. If you want an insert, prefer `store_new`, if you want to update, prefer `update`.

With `store`, it doesn't keep a track of which properties have changed, so if the object is already in the database, it'll update all its defined properties. In general, this approach:

    @repo.update(object, :property => 'new_value')

is preferable to this one, which may be more familiar to ActiveRecord users:

    object.property = 'new_value'
    @repo.store(object)

The advantage being that in the former case, the new property will only get set on the in-memory object if the update succeeds, and the repo will only update the specified properties not all of them.

The other thing is the approach taken in the latter example may not scale up to more complex scenarios, where you expect to make a bunch of changes to an in-memory object graph and then persist them all in one go with 'store'. There is some support for this in the one_to_many, many_to_many etc mappers, but the general case is quite hard, and you really need a full-on Unit Of Work pattern to do a rigorous job of it where it guarantees to persist all changes to an object graph in the right order. So for now if you encounter problems along these lines, eg with callbacks not running in the right order, take it as a sign that you may just need to be more fine-grained and explicit in the way you're updating your subobjects. Better take on this deffo part of the longer-term TODO.

Note, you can also use a model object or other hash-like thing as an update, in which case it will update any properties which are defined and present (has_key?) on the update model:

    > update = Author.new(:fave_breakfast_cereal => 'Shreddies')
    > author_repo.update(author, update)
    UPDATE `authors` SET `fave_breakfast_cereal` = 'Shreddies' WHERE (`id` = 123)
     => #<Author:0x1018c8578 @values={:title=>"Changed", :fave_breakfast_cereal=>"Shreddies", :id=>123}>

Note: one case where `store` may be preferable is if you have `:id_sequence => false`, ie you generate the primary keys in your code, and you want to do an 'upsert' against a particular primary key.

### Property mappers

Persistence::Sequel::IdentitySetRepository is designed to be quite extensible in the way it maps different properties of the objects it persists. The property mapper used in the example above is Persistence::Sequel::PropertyMapper::Column (`map_column :foo` is just shorthand for `map_property :foo, Persistence::Sequel::PropertyMapper::Column`), but there are various other property mappers available as we'll see, and it's possible to write your own too.

To summarize the mechanics of it: a repository has a PropertyMapper instance for each property it maps, this is a single static instance which doesn't have any mutable state. The repository calls upon the property mapper at various points during CRUD operations, passing it the relevant model instance. This allows you to hook into the repository internals at various stages in order to implement different behaviours for how a property is CRUDed.

In particular, the property mapper has the opportunity to:

- Specify particular Sequel expressions (with aliases) to add into the SELECT clause of the main query being done to load an object, when this property is to be loaded
- Specify which tables which need to be added into the FROM clause of this query in order for the above SELECT clause to work (although they need to be tables which the repository knows about, and the repository takes care of JOINing them. See the section on using multiple tables for more info, and note that this doesn't at present work for adding arbitrary eager-association-loading joins into a query, only for when the object being loaded is spread across multiple tables in a one-to-one fashion)
- To load the value for this property for a particular object ID, given the sequel result row resulting from the above SELECT query (note it doesn't have to get the value from this query and its result row, it could for example do its own separate query if required eg to load associated objects).
- Given a list of IDs and a list of result rows, to do the above in an efficient batched fashion. This provides a basic way to avoid the classic 'n+1' problem, eg the foreign key mapper uses this to do a `WHERE id IN (1,2,3,...)`
- To do something relevant to this property {pre,post}_{insert,update,delete} of its parent object
- Make a Sequel filter expression which can be used to build a query querying for a particular value of this property

When creating property mappers via the `map_*` class methods, you can generally specify a bunch of options to customize exactly which database columns, tables etc they use. Some examples follow.

### map_column

### map_created_at and map_updated_at

### map_foreign_key

### map_one_to_many

### map_many_to_many

### map_custom_query and custom_query_single_value

### map_hash_property and map_array_property


### Lazy loading of properties using LazyData::Struct

One of the downsides of decoupling data model classes from persistence concerns is that, because the model objects have no connection with the data source they came from, you may have to go back to the repository if you want to load additional properties or associations on them. This means that you end up worrying too much about exactly which properties to fetch eagerly at which point in order to ensure the right things are loaded.

There's a solution to this though, which is if you use a model class which supports lazily-evaluated properties. THe model instance doesn't need to know anything about the details of the data store it's fetched from -- the repository just supplies properties to the constructor in the form of a block which can be called lazily to load them, rather than as an actual hash of values.

For comparison, this is somewhat analagous to how Hash works in the ruby stdlib. You can construct it with a block which lazily loads missing keys: `Hash.new {|hash, key| hash[key] = load(key)}`

As it stands, you need to make your model class a subclass of LazyData::Struct (from the lazy-data gem) in order to take advantage of this, and this is the main reason for the current somewhat-loose dependency on lazy-data. A TODO is to do the remaining work to properly remove the dependency on this so you can use your own model class whether or not it supports lazy-loaded properties -- or maybe even just use Hash if you prefer.

### Control over which properties get loaded eagerly

### Wiring up repositories so they can load associations

When you start decoupling things like repositories from the model classes, it becomes more of a challenge to wire up a graph of repositories for different classes, since they may need to know about eachother in order to load associations, and they can't just find eachother in the global scope as is the case with ActiveRecord classes.

You can wire them up yourself if you want, but Persistence::Sequel also supports the use of Wirer, a dependency injection library, to wire up repositories. It's recommended to use this if the data model you're persisting has more than a handful of inter-related object types, as it would be quite a pain to do it manually. If you choose to use Wirer you'll find that subclasses of Persistence::Sequel::IdentitySetRepository automatically expose the Wirer::Factory::Interface required for them to be added into a container and hooked up with their dependencies.

### Extensible PropertyMapper interface

### Using multiple tables / mapping different properties to different tables

### Class-table and single-table inheritance mapping

### Polymorphic loading

### Observing actions on a repository

### Some rough edges / TODOs

### Roadmap

In no particular order:

- Chaining repositories, so you can put a Serialized cache repository infront of a Sequel repository in order to cache certain serialized versions of objects before hitting the database, with options for whether to write_on_miss etc.
  - Formalising an interface which allows you to specify which 'version' of an object you want to fetch, eg you might fetch full or partial versions, just certain properties etc. Lazy loading makes this less necessary, *but* it is going to be more useful when it comes to storing and loading objects from a serialized cache.
- Overall tidyup of (and better test coverage for) the Sequel code
- Some performance optimisations for Sequel repositories, in particular to the way lazy loading works, and avoiding unnecessary queries when traversing an object graph.
- Formalising some concept of the schema of ruby objects which repositories are designed to persist
- Database-backed implementations of other simpler Persistence interfaces like HashRepository, SetRepository and ArrayCell
- Support for Identity Map and Unit of Work patterns (a biggie)
- Implementations of the Persistence interfaces for some NoSQL datastores (eg Redis would be nice)
- Porting across some more featureful and robust disk-backed implementations of the repository interfaces, making it a no-brainer to use config-file-backed persistence
- Proper support for the use of non-Sequel repositories together with foreign_key mappers, so eg you could have it load a licensor from a licensor config file based on a licensor_id column in the database. The property mappers were designed with this sort of capability in mind but a bit more work needs doing on it.
- Perhaps extend the property mapper concept to non-sequel-backed repositories too; in the process seeing if more could be done to unify the way property mappers work with the way repositories expose object cells, and object cells expose property cells.
- Better-thought-out support in the persistence interfaces for reflection to discover the types of objects which can be persisted in a particular cell/repository/etc. This has been done to an extent but was a bit of a rush job. Perhaps would be nice to implement this via optional support for some kind of schema library. A good approach to this might also help to pin down in a tidy precise way how repositories ought to behave in the presence of polymorphism and subclassing.
