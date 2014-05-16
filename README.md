[![Build Status](https://travis-ci.org/mediasp/hold.svg?branch=master)](https://travis-ci.org/mediasp/hold)
[![Gem Version](https://badge.fury.io/rb/hold.svg)](http://badge.fury.io/rb/hold)
# Hold

A ruby library geared towards separating persistence concerns from data model classes.

## TL;DR

If you want to dive in and write some code to get a feel for the library, take a look at [QUICK-START.md](QUICK-START.md).

## An Introduction

The hold library contains a set of interfaces for, and implementations of, the [http://martinfowler.com/eaaCatalog/repository.html](Repository pattern) in Ruby.

To summarize, the idea is that

* You have Repositories which are responsible for persisting objects in a data store
* Your data objects know nothing about persistence. They are just 'plain old' in-memory ruby objects can be created and manipulated independently of any particular repository.

This is a substantially different approach to the [http://martinfowler.com/eaaCatalog/activeRecord.html]('Active Record') pattern, which is the approach that most persistence libraries in the Ruby world use, including (surprise surprise) ActiveRecord, but also Datamapper and Sequel::Model.

Of course there are various trade-offs involved when choosing between these two approaches. ActiveRecord is a more lightweight approach which is often preferred for small-to-mid-sized database-backed web applications where the data model is tightly coupled to a database schema; whereas Repositories start to show benefits when it comes to, e.g.:

* Separation of concerns in a larger system; avoiding bloated model classes with too many responsibilities
* Ease of switching between alternative back-end data stores, e.g. database-backed vs persisted-in-a-config-file vs persisted in-memory. In particular, this can help avoid database dependencies when testing
* Systems which persist objects in multiple data stores -- e.g. in a relational database, serialized in a key-value cache, serialized in config files, ...
* Decoupling the structure of your data model from the schema of the data store used to persist it

## Interfaces

At the core of our approach is to define interfaces for the most common kinds of "things which persist stuff". It being Ruby, you could just implement them just via duck-typing, but we also define some modules which serve to illustrate the method signatures, and provide a handful of default implementations and conveniences around the core interface, and as a 'marker' for the interface (since in general, `duck.is_a?(Quacker)` is easier than `[:quack_loudly, :quack_quietly, ...].each {|m| duck.respond_to?(m)}`).

(We also have some shared test suites which are intended to validate that a particular implementation complies with the contract; a TODO is to make these reusable outside this gem).

On one level, you could just use these interfaces and nothing else -- we supply some implementations of them, but you may prefer to make your own, and in some cases this may be the simplest and most explicit way to proceed.

### Rationale

One approach which I've seen is to define one big 'store' interface which tries to subsume all sorts of different kinds of data store (key-value store, array-like collection, set, full-blown relational or semi-relational datastore), where you sort of pick and choose which bits of it to implement.

This is a bit clunky; here I've tried to break it up into some more fine-grained interfaces for particular kinds of data stores, starting at the simplest possible: a Cell, and working our way up to an IdentitySetRepository, which corresponds to the CRUD-style interface of a typical object store which stores objects indexed by their identity.

Nevertheless, it would be possible to go even further in terms of breaking up into more fine-grained interfaces, for example separating out the reading and writing portions of the interfaces. Tricky call where exactly to cut off with this stuff, especially in ruby which is duck-typed, meaning you don't have to give a formal name to some subset of an interface in order to use it in practise. It would also be possible to define even richer interfaces beyond that of IdentitySetRepository, e.g. adding an interface for querying the store based on critera other than just the id, but we've not formalised this yet.

One other thing which it might be worth adding interfaces for is transactionality. It's a tricky one though; while it'd be easy enough to add a 'transaction do ...' to the interface of individual repositories, often you'll have multiple repositories running off the same underlying database which you want to use inside the same transaction context. So for now transactional stuff isn't abstracted away from the underlying persistence mechanism; if you're using Sequel, you can just call .transaction on the underlying Sequel database for example. If you wanted more serious abstraction around transactions, it might be best done as part of adding support for the 'unit of work' pattern used by libraries like Hibernate, SQLAlchemy etc.

Would be worth doing a review of the interface design here once we have some more implementations going, to see what works and what doesn't, what needs adjusting etc.

### Hold::Cell

This is pretty much the simplest hold interface possible. It represents a 'cell' in which a single item of data can be stored; the cell responds to 'get' and 'set' which do the obvious with respect to the data stored in it.

#### Empty Cells

Cells may optionally support being in an 'empty' state, ie a state where no data is stored in them. They should then also respond to 'clear' to clear out the call, and 'empty?' to determine whether or not the cell has anything stored in it.

This allows distinctions to be drawn between e.g. "present in the hash but set to nil" and "not present in the hash", or "loaded and known to be nil" vs "not loaded", which are quite common distinctions to be found in data structures used for persistence.

### Hold::ObjectCell

An ObjectCell is a Cell which stores Objects with named properties. Ontop of the Cell interface, it also supports getting and setting the values of individual properties of the object contained with it, via get_property and set_property. (It can also support properties being empty/missing, via clear_property and has_property?)

You can ask it for a property_cell, which will return you a Cell wrapping a particular property of the object contained within it.

### Hold::ArrayCell

A Cell which stores an ordered collection of values, and also supports random access to them via get_slice, and getting of the length of the collection via get_length.

### Hold::HashRepository

A Hash-like interface for a simple key-value store, which can get and set objects by a key. get_with_key / set_with_key / has_key? / clear_key. May also support an optimised get_many_with_keys to get multiple keys at once, for which a default implementation is supplied.

### Hold::SetRepository

Interface for a store which contains a set of values. Supports adding (store) and removing (delete) them, membership test (contains?) and potentially iteration over all the values in the store (get_all). But doesn't necessarily support any kind of indexed lookup.

### Hold::IdentitySetRepository

A SetRepository which stores objects with identity (so Entities rather than just Value objects). In addition to the SetRepository interface it supports lookup of objects by their ID. Given that objects have identities which are independent of their values, it then makes sense to talk about 'updating' an object in the store, i.e. replacing it with an updated version with the same identity. This corresponds well to the common "database table with a primary key" type model.

IdentitySetRepository implementations may well add support for various other kinds of indexed lookup, although we haven't fully formalised interfaces for these, maybe look at how Hold::Sequel::IdentitySetRepository does it for now.

## In-memory implementations

For each of the above interfaces, there's a corresponding in-memory implementation in Hold::InMemory.

These are intended to illustrate how the interface is intended to work, and to be useful for testing purposes if you want an alternative in-memory mock implementation of some repository in order to avoid a dependency on a database.

They're quite simple, not really intended for production use, and not designed to be threadsafe (although wouldn't be too hard to make them so).

## Serialized persistence

A common way of persisting objects is to serialize them into a string, and then persist that string somewhere (in a key-value store, as a file on disk...).

Hold::Serialized::HashRepository and Hold::Serialized::IdentitySetRepository provide implementations of these interfaces which serialize and deserialize the object to/from a string, before/after persisting them in an underlying string-based HashRepository. You need to pass it this underlying store, and a serializer, e.g. Hold::Serialized::JSONSerializer.

## Sequel-backed persistence

This is the biggest implementation of Hold::IdentitySetRepository, and is done ontop of the database connection facilities and SQL-building DSL of the excellent Sequel library.

It's essentially a mini ORM, but, unlike other Ruby ORMs, is based on the Repository pattern instead of an ActiveRecord-style approach; meaning you will have separate repository classes and data model classes. The nearest things you might compare it with might be Hibernate in the Java world, or SQLAlchemy in the Python, although it's not trying to be quite as fully-featured as these. In particular it doesn't have the concept of a "session" or "unit of work", and it's not quite so clever about persisting changes to large object graphs all in one go. (These might be useful additions at some point, but would take some care to do well).

Here follows a selection of the core features of Hold::Sequel, with some usage examples in each case.

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
      position int not null,
      foreign key (author_id) references authors (id)
    );
    create table influenced_by (
      author_id int not null,
      book_id int not null,
      position int not null,
      primary key (author_id, book_id),
      foreign key (author_id) references authors (id),
      foreign key (book_id) references books (id)
    );

### Creating a repository for a simple data model class

There is a class-based DSL which is used to configure a new repository class. The simplest example would be:
``` ruby
    Author = ThinModels::StructWithIdentity(:title, :fave_breakfast_cereal)

    class AuthorRepository < Hold::Sequel::IdentitySetRepository
      set_model_class Author
      use_table :authors, :id_sequence => true
      map_column :title
      map_column :fave_breakfast_cereal
    end
```
About the model class:

- There is a basic protocol which your model class needs to observe, in order to work here, so the repository can create, update and read the properties off model instances. For now, the only officially-supported model classes are subclasses of ThinModels::Struct from the thin_models gem, and it's best to look at this for reference. High on the TODO list though is to make it clear exactly what interface you need to support, and to test against some different model class implementations. There's certainly nothing in principle stopping it working with a very basic lightweight plain-old-ruby model class; in fact LazyData pretty much is just one of these, plus some small conveniences (including support for lazy property loading).

- The model class is also required to have an attribute called 'id', and to implement the :==/:eql/:hash contract based on this id property. ThinModels::StructWithIdentity is the best way of achieving this at present.

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

The other thing is the approach taken in the latter example may not scale up to more complex scenarios, where you expect to make a bunch of changes to an in-memory object graph and then persist them all in one go with 'store'. There is some support for this in the one_to_many, many_to_many etc mappers, but the general case is quite hard, and you really need a full-on Unit Of Work pattern to do a rigorous job of it where it guarantees to persist all changes to an object graph in the right order. So for now if you encounter problems along these lines, e.g. with callbacks not running in the right order, take it as a sign that you may just need to be more fine-grained and explicit in the way you're updating your subobjects. Better take on this deffo part of the longer-term TODO.

Note, you can also use a model object or other hash-like thing as an update, in which case it will update any properties which are defined and present (has_key?) on the update model:

    > update = Author.new(:fave_breakfast_cereal => 'Shreddies')
    > author_repo.update(author, update)
    UPDATE `authors` SET `fave_breakfast_cereal` = 'Shreddies' WHERE (`id` = 123)
     => #<Author:0x1018c8578 @values={:title=>"Changed", :fave_breakfast_cereal=>"Shreddies", :id=>123}>

Note: one case where `store` may be preferable is if you have `:id_sequence => false`, ie you generate the primary keys in your code, and you want to do an 'upsert' against a particular primary key.

### Property mappers

Hold::Sequel::IdentitySetRepository is designed to be quite extensible in the way it maps different properties of the objects it persists. The property mapper used in the example above is Hold::Sequel::PropertyMapper::Column (`map_column :foo` is just shorthand for `map_property :foo, Hold::Sequel::PropertyMapper::Column`), but there are various other property mappers available as we'll see, and it's possible to write your own too.

To summarize the mechanics of it: a repository has a PropertyMapper instance for each property it maps, this is a single static instance which doesn't have any mutable state. The repository calls upon the property mapper at various points during CRUD operations, passing it the relevant model instance. This allows you to hook into the repository internals at various stages in order to implement different behaviours for how a property is CRUDed.

In particular, the property mapper has the opportunity to:

- Specify particular Sequel expressions (with aliases) to add into the SELECT clause of the main query being done to load an object, when this property is to be loaded
- Specify which tables which need to be added into the FROM clause of this query in order for the above SELECT clause to work (although they need to be tables which the repository knows about, and the repository takes care of JOINing them. See the section on using multiple tables for more info, and note that this doesn't at present work for adding arbitrary eager-association-loading joins into a query, only for when the object being loaded is spread across multiple tables in a one-to-one fashion)
- To load the value for this property for a particular object ID, given the sequel result row resulting from the above SELECT query (note it doesn't have to get the value from this query and its result row, it could for example do its own separate query if required e.g. to load associated objects).
- Given a list of IDs and a list of result rows, to do the above in an efficient batched fashion. This provides a basic way to avoid the classic 'n+1' problem, e.g. the foreign key mapper uses this to do a `WHERE id IN (1,2,3,...)`
- To do something relevant to this property `{pre,post}_{insert,update,delete}` of its parent object
- Make a Sequel filter expression which can be used to build a query querying for a particular value of this property

When creating property mappers via the `map_*` class methods, you can generally specify a bunch of options to customize exactly which database columns, tables etc they use. Some examples follow.

### map_column

This one's fairly self-explanatory and we mentioned it already above.

Note that all the `map_*` have the property name on the model class as their first argument, and then a hash of options.

With `map_column`, you can specify an overridden :column_name, if you don't want to use the default which is the same as the property name.

    map_column :foo, :column_name => :something_other_than_foo

If using multiple tables, you can also specify the table this property gets loaded from:

    use_table :some_table
    use_table :other_table
    map_column :foo, :column_name => :some_column_on, :table => :some_table

See the section on using multiple tables for more info about this; if you only use one table you needn't specify :table.

### map_created_at and map_updated_at

These are like `map_column`, except:

- `map_created_at` will automatically populate the column with the current time when storing for the first time
- `map_updated_at` will automatically update the column with the current time when storing or updating

### map_foreign_key

This is an important property mapper. It expects a foreign key column to be present on the table, and it uses another repository to load the value by ID using the foreign key.

You need to specify the :model_class with this and other association mappers -- this is what tells it what sort of repository it's going to need in order to load the values pointed at by the foreign keys.

The actual associated repository only needs to be passed in at initialization time -- or more precisely, it gets passed in during a post-initialization phase, since you need a way to handle cyclic dependencies between repositories when they have associations pointing at eachother.

An example is in order (continuing on from our examples the AuthorRepository above):

    Book = ThinModels::StructWithIdentity(:title, :author)

    class BookRepository < Hold::Sequel::IdentitySetRepository
      set_model_class Book
      use_table :books, :id_sequence => true
      map_column :title
      map_foreign_key :author, :model_class => Author
    end

    book_repo = BookRepository.new(db)
    book_repo.mapper(:author).target_repo = author_repo

Then we can e.g.:

    > book = Book.new(:title => 'War and peace', :author => author)
    > book_repo.store_new(book)
    INSERT INTO `books` (`title`, `author_id`) VALUES ('War and peace', 1)
     => #<Book:0x1018f8598 @values={:title=>"War and peace", :id=>1, :author=>#<Author:0x101903c18 @values={:title=>"foo", :fave_breakfast_cereal=>nil, :id=>1}>}>

    > book = book_repo.get_by_id(1)
     => #<Book:0x1018df0e8 lazy, @values={:title=>"War and peace", :id=>1}>
    > book.author
     => #<Author:0x1018d6f10 lazy, @values={:title=>"foo", :fave_breakfast_cereal=>nil, :id=>1}>

Note: with this approach, you have to set the target_repo on the BookRepository's author property mapper, so that it knows how to load authors. Doing this wiring up gets a bit clunky if you have more than a handful of interconnected repositories; the good news is that Hold::IdentitySetRepository supports the use of the Wirer dependency injection library to do all the wiring-up in these cases, see the section later on.

There are some options: as with map_column you can override the name of the database column used for the foreign key:

    map_foreign_key :author, :model_class => Author # :column_name defaults to :author_id
    map_foreign_key :author, :model_class => Author, :column_name => :the_id_of_the_author

You can also specify :auto_store_new:

    map_foreign_key :author, :model_class => Author, :auto_store_new => true

Where this is enabled and the value for this property is a 'new' object without an ID allocated to it, it will automatically go and store_new the referenced object in its repository beforehand. This means you can do stuff like:

    > book = Book.new(:title => 'War and peace', :author => Author.new(:title => 'Tolstoy'))
    > book_repo.store_new(book)
    INSERT INTO `authors` (`title`) VALUES ('Tolstoy')
    INSERT INTO `books` (`title`, `author_id`) VALUES ('War and peace', 124)
     => #<Book:0x101879720 @values={:title=>"War and peace", :id=>2, :author=>#<Author:0x101879748 @values={:title=>"Tolstoy", :id=>124}>}>

It's implemented via a pre_insert hook on the property mapper, and I made it so you have to explicitly turn this behaviour on if you want it, partly to make you aware that this is all you're getting - this isn't (yet) part of some magical generalised mechanism for persisting arbitrary object graphs all in one go, and it won't necessarily cope well with cycles etc. But it is still quite handy.

In particular though, note that there isn't any analagous functionality for updates - ie something like this won't necessarily have the effect you might hope for:

    > book.author.title = 'Changed author'
    > book_repo.store(book)

The foreign-key-mapped property is just a reference to another object, you can update the reference via

    > book_repo.update(book, :author => some_other_author)

But the referenced object isn't treated as some kind of aggregate sub-object which can be updated as part of its parent object. For rationale, in this case consider that it's by no means guaranteed that we're the only book with this author; semantics are ambiguous as to whether you mean to update the author across all their books, or just replace the author on this particular book only with an updated author. For contrast, see map_one_to_many, which *does* allow for treating them, to an extent, as wholly-owned aggregate subobjects.

### map_one_to_many

This is for classic one to many associations, like one Author has many Books. To demo this, let's revisit the AuthorRepository:
``` ruby
    Author = ThinModels::StructWithIdentity(:title, :fave_breakfast_cereal, :books)

    class AuthorRepository < Hold::Sequel::IdentitySetRepository
      # ...
      map_one_to_many :books, :model_class => Book, :property => :author
    end

    # ...

    author_repo = AuthorRepository.new(db)
    book_repo = BookRepository.new(db)
    book_repo.mapper(:author).target_repo = author_repo
    author_repo.mapper(:books).target_repo = book_repo
```
For this to work, we're relying on Book having the specified corresponding propery `:author`, and this property being mapped via map_foreign_key. The value for the books property for author x is then defined to be an array of those books for whom the author property is author x. Or equivalently on the database side, those whose `:author_id` column matches our `:id`.

Also, see what I meant earlier about cyclic references between repositories? This is why they have to be wired up after being instantiated, and why using Wirer makes it more pleasant if you're doing a lot of it.

You can then use it like so to:

``` ruby
    > author = author_repo.get_by_id(1)
    > author.books
    ...
    SELECT `books`.`title` AS `books_title`, `books`.`author_id` AS `books_author_id`, `books`.`id` AS `id` FROM `books` WHERE (`books`.`author_id` = 1)
    ...
     => [#<Book:0x101892b58 lazy, @values={:title=>"War and peace", :id=>1, ...}>, #<Book:0x1018929c8 lazy, @values={:title=>"xyz", :id=>3}>]
```

By default this property mapper is read-only, which is a common way to use it. For example in this case, if you wanted to make changes to the associations between books and authors, you'd probably do this by updating the author on the books, rather than updating the entire books collection on some author.

However sometimes you *do* want to be able to treat the associated objects (books in this case) as aggregate subobjects which are effectively a wholly-owned part of their parent object (the author in this case), and to update them as part of the parent object. A better example for us might be the Tracks within a Release.

If you want this kind of behaviour, you need to explicitly buy into it by specifying `:writeable => true`:

``` ruby
    map_one_to_many :books, :model_class => Book, :property => :author, :writeable => true
```
Now you are now able to create and update the entire collection of books all in one go:

    > author = Author.new(
      :title => 'Example',
      :books => [
        Book.new(:title => 'foo'),
        Book.new(:title => 'bar'),
        Book.new(:title => 'baz')
      ]
    )
    > author_repo.store_new(author)
    INSERT INTO `authors` (`title`) VALUES ('Example')
    INSERT INTO `books` (`title`, `author_id`) VALUES ('foo', 125)
    INSERT INTO `books` (`title`, `author_id`) VALUES ('bar', 125)
    INSERT INTO `books` (`title`, `author_id`) VALUES ('baz', 125)
     => #<Author:0x1018e3558 @values={:title=>"Example", :books=>[#<Book:0x1018e3670 @values={:title=>"foo", :id=>4, :author=>#<Author:0x1018e3558 ...>}>, #<Book:0x1018e3620 @values={:title=>"bar", :id=>5, :author=>#<Author:0x1018e3558 ...>}>, #<Book:0x1018e35a8 @values={:title=>"baz", :id=>6, :author=>#<Author:0x1018e3558 ...>}>], :id=>125}>

You can also update the list of books:

    > author.books[0] = Book.new(:title => 'Replaced with a new child object')
    > author.books[1].title = 'Updated an existing child object'
    > author.books.delete_at(2) # Removed a child object
    > author_repo.store(author)
    ...
    DELETE FROM `books` WHERE (`id` = 4)
    DELETE FROM `books` WHERE (`id` = 6)
    INSERT INTO `books` (`title`, `author_id`) VALUES ('Replaced with a new child object', 125)
    UPDATE `books` SET `title` = 'Updated an existing child object', `author_id` = 125 WHERE (`id` = 5)
    ...

Note what happened here:

- Books which were in the author's list of books prior to the update, but aren't in the new list, get deleted
- New books which weren't in the author's list of books prior to the update, but are in the new list, get inserted with the relevant author set on them
- Books which were present in the old list, and are also present in the new list potentially with updated properties, get updated. This is based on their identity, ie their having the same ID as before, and ensures that we don't gratuitiously delete and re-create child objects when updating the list en masse like this. Which in turn is desireable so as to avoid a bunch of ON DELETE CASCADE happening unnecessarily.

One thing which *won't* work, is trying to add a book by one author into the books collection of another author. It doesn't support 'stealing' a child object off some other parent object in this way, the desired semantics there are slightly murky and to do so raises some fiddly issues about what callbacks might need to run on the other author from which a book has been stolen, how does the ordering get updated if the books are in an ordered list, and so on, which I was keen to avoid.

Note that this approach very much treats the books as wholly-owned subobjects of the author. Only one author can own a particular book, and if that book is removed from the author's books list, it's removed full stop.

`map_one_to_many` also supports an ordering on these collections via an :order_property argument. At present you need to have this 'order property' on the model class of the child objects; it's an integer representing the position of that child object in the array. If you're only using map_one_to_many in a read-only fashion, then you can use pretty much whichever values you like for the order column, it will just get added in an ORDER BY clause. For a writeable map_one_to_many though, the order property should be an integer index, starting at zero and with no gaps; it is managed for you though when writing. An example:

``` ruby
    Book = ThinModels::StructWithIdentity(:title, :author, :position)

    # in AuthorRepository:
    map_one_to_many :books, :model_class => Book, :property => :author, :order_property => :position, :writeable => true

    # in BookRepository:
    map_foreign_key :author, :model_class => Author
    map_column :position
```
If you try the example above, you'll see it automatically populates this order property when saving the new book objects:

``` sql
    INSERT INTO `books` (`title`, `author_id`, `position`) VALUES ('foo', 126, 0)
    INSERT INTO `books` (`title`, `author_id`, `position`) VALUES ('bar', 126, 1)
    INSERT INTO `books` (`title`, `author_id`, `position`) VALUES ('baz', 126, 2)
```
If you *do* pre-populate the values for the order property though, then it will be expected to match the ordering that the objects are given in.

When selecting the property it'll add an ORDER BY, so you'll get them back in the same order:
``` sql
    SELECT `books`.`title` AS `books_title`, `books`.`position` AS `books_position`, `books`.`author_id` AS `books_author_id`, `books`.`id` AS `id` FROM `books` WHERE (`books`.`author_id` = 126) ORDER BY (`books`.`position`)
```
### map_many_to_many

This is the classic many_to_many which uses rows in a 'join table' with two foreign keys, to store the relationships in a many-to-many association.

In our example (which is now growing slightly contrived) I'm going to have a many-to-many relationship where Authors can be 'influenced by' a set of Books:

``` ruby
    Author = ThinModels::StructWithIdentity(:title, :fave_breakfast_cereal, :books, :influenced_by_books)
    Book = ThinModels::StructWithIdentity(:title, :author, :position, :influenced_authors)

    # in AuthorRepository
    map_many_to_many(:influenced_by_books,
      :model_class => Book,
      :join_table  => :influenced_by,
      :left_key    => :author_id,
      :right_key   => :book_id,
      :writeable   => true
    )

    # in BookRepository
    map_many_to_many(:influenced_authors,
      :model_class => Author,
      :join_table  => :influenced_by,
      :left_key    => :book_id,
      :right_key   => :author_id
    )

    # after construction these will need wiring up too
    author_repo.mapper(:influenced_by_books).target_repo = book_repo
    book_repo.mapper(:influenced_authors).target_repo = author_repo
```

The options here are:

- `:join_table`, the table which stores the foreign key association pairs. Defaults to :"#{repo.main_table}_#{property_name}"
- `:left_key`, the foreign key column on this table pointing at the object on which the property lives. Defaults to :"#{repo.main_table.to_s.singularize}_id"
- `:right_key`, the foreign key column on this table pointing at the associated object. Defaults to :"#{property_name.to_s.singularize}_id"
- `:writeable`, as with the one_to_many mapper, if you want to be able to write to these mapped properties you need to explicitly turn this on

If you now use this:

    > all_books = book_repo.get_all
    > author = Author.new(:title => 'Widely read', :influenced_by_books => all_books)
    > author_repo.store_new(author)
    INSERT INTO `authors` (`title`) VALUES ('Widely read')
    INSERT INTO `influenced_by` (`author_id`, `book_id`) VALUES (128, 1), (128, 2), (128, 3), (128, 5), (128, 7), (128, 8), (128, 9), (128, 10)

    > author_repo.update(author, :influenced_by_books => all_books[0..2])
    DELETE FROM `influenced_by` WHERE (`author_id` = 128)
    INSERT INTO `influenced_by` (`author_id`, `book_id`) VALUES (128, 1), (128, 2), (128, 3)

Some notes:

If you use this in a read-only fashion, you can use pretty much any table you like as a join table, even potentially tables that are also used for other purposes.

If you make it writeable, though, the rows in the join table are then treated as wholly owned part of the parent object on which the writeable many_to_many property lives. They will be deleted and re-inserted whenever you update the property, as you can see above.

If you have a corresponding many_to_many property on the other ends of the association, note that these updates may affect the values of the corresponding property on objects on the other end of the association. At present, there's no support for notifying these affected objects that they were affected by the change, via post_update callbacks or anything.

Normally you would only make one of the two corresponding many_to_many associations writeable, although you can make both of them writeable, if you have an order column on the join table, updating it from the other end can disturb the sequence of the order column values, so this isn't recommended.

If you specify an :order_column, you can make it an ordered list, although note that if you're mapping the association via many_to_many properties on both ends, this order can obviously only apply on one end. In our case we'll make it the order of books within the 'influenced_by_books' list for an author:

``` ruby
    map_many_to_many(:influenced_by_books,
      :model_class  => Book,
      :join_table   => :influenced_by,
      :left_key     => :author_id,
      :right_key    => :book_id,
      :order_column => :position,
      :writeable    => true
    )
```

Then you'll find the example above does, e.g.:

``` sql
    INSERT INTO `influenced_by` (`author_id`, `book_id`, `position`) VALUES (129, 1, 0), (129, 2, 1), (129, 3, 2), (129, 5, 3), (129, 7, 4), (129, 8, 5), (129, 9, 6), (129, 10, 7)
```
and

``` sql
    SELECT `books`.`title` AS `books_title`, `books`.`id` AS `id`, `books`.`position` AS `books_position` FROM `books` INNER JOIN `influenced_by` ON (`influenced_by`.`book_id` = `books`.`id`) WHERE (`influenced_by`.`author_id` = 129) ORDER BY `influenced_by`.`position`
```

### map_custom_query and custom_query_single_value

### map_hash_property and map_array_property


### Lazy loading of properties using ThinModels::Struct

One of the downsides of decoupling data model classes from persistence concerns is that, because the model objects have no connection with the data source they came from, you may have to go back to the repository if you want to load additional properties or associations on them. This means that you end up worrying too much about exactly which properties to fetch eagerly at which point in order to ensure the right things are loaded.

There's a solution to this though, which is if you use a model class which supports lazily-evaluated properties. THe model instance doesn't need to know anything about the details of the data store it's fetched from -- the repository just supplies properties to the constructor in the form of a block which can be called lazily to load them, rather than as an actual hash of values.

For comparison, this is somewhat analagous to how Hash works in the ruby stdlib. You can construct it with a block which lazily loads missing keys: `Hash.new {|hash, key| hash[key] = load(key)}`

As it stands, you need to make your model class a subclass of ThinModels::Struct (from the thin_models gem) in order to take advantage of this, and this is the main reason for the current somewhat-loose dependency on thin_models. A TODO is to do the remaining work to properly remove the dependency on this so you can use your own model class whether or not it supports lazy-loaded properties -- or maybe even just use Hash if you prefer.

### Control over which properties get loaded eagerly

### Wiring up repositories so they can load associations

When you start decoupling things like repositories from the model classes, it becomes more of a challenge to wire up a graph of repositories for different classes, since they may need to know about eachother in order to load associations, and they can't just find eachother in the global scope as is the case with ActiveRecord classes.

You can wire them up yourself if you want, but Hold::Sequel also supports the use of Wirer, a dependency injection library, to wire up repositories. It's recommended to use this if the data model you're persisting has more than a handful of inter-related object types, as it would be quite a pain to do it manually. If you choose to use Wirer you'll find that subclasses of Hold::Sequel::IdentitySetRepository automatically expose the Wirer::Factory::Interface required for them to be added into a container and hooked up with their dependencies.

### Extensible PropertyMapper interface

### Using multiple tables / mapping different properties to different tables

### Class-table and single-table inheritance mapping

### Polymorphic loading

### Observing actions on a repository

### Some rough edges / TODOs

### Roadmap

In no particular order:

- Chaining repositories, so you can put a Serialized cache repository infront of a Sequel repository in order to cache certain serialized versions of objects before hitting the database, with options for whether to write_on_miss etc.
  - Formalising an interface which allows you to specify which 'version' of an object you want to fetch, e.g. you might fetch full or partial versions, just certain properties etc. Lazy loading makes this less necessary, *but* it is going to be more useful when it comes to storing and loading objects from a serialized cache.
- Overall tidyup of (and better test coverage for) the Sequel code
- Some performance optimisations for Sequel repositories, in particular to the way lazy loading works, and avoiding unnecessary queries when traversing an object graph.
- Formalising some concept of the schema of ruby objects which repositories are designed to persist
- Database-backed implementations of other simpler Hold interfaces like HashRepository, SetRepository and ArrayCell
- Support for Identity Map and Unit of Work patterns (a biggie)
- Implementations of the Hold interfaces for some NoSQL datastores (e.g. Redis would be nice)
- Porting across some more featureful and robust disk-backed implementations of the repository interfaces, making it a no-brainer to use config-file-backed persistence
- Proper support for the use of non-Sequel repositories together with foreign_key mappers, so e.g. you could have it load a licensor from a licensor config file based on a licensor_id column in the database. The property mappers were designed with this sort of capability in mind but a bit more work needs doing on it.
- Perhaps extend the property mapper concept to non-sequel-backed repositories too; in the process seeing if more could be done to unify the way property mappers work with the way repositories expose object cells, and object cells expose property cells.
- Better-thought-out support in the hold interfaces for reflection to discover the types of objects which can be persisted in a particular cell/repository/etc. This has been done to an extent but was a bit of a rush job. Perhaps would be nice to implement this via optional support for some kind of schema library. A good approach to this might also help to pin down in a tidy precise way how repositories ought to behave in the presence of polymorphism and subclassing.
