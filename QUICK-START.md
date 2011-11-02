# Quick Start Guide

I say quick-start, but by it's very nature and early stage of development, it ain't that quick.  This library is more verbose entirely because we wanted something that didn't tie us to a particular persistence mechanism and that meant more boilerplate (At least now it does)

OK, First you have your model.  We (currently) rely on a library called thin_models to gives some conveniences when declaring your domain model classes.

    require 'rubygems'
    require 'thin_models/struct'

    # Represent the data, pojo style
    class Author < ThinModels::Struct
      identity_attribute
      attribute :title
      attribute :fave_breakfast_cereal

      def to_s
        "#{title} likes #{fave_breakfast_cereal}"
      end
    end

    # has nothing to do with a database at this point
    jane_austen = Author.new(:title => 'Jane Austen', :fave_breakfast_cereal => 'Cornflakes')
    puts jane_austen.title # Jane Austen
    puts jane_austen # Jane Austen likes Cornflakes


Next we want to store jane in a database.  We create a table and a repository instance.

    require 'sqlite3'
    require 'persistence'
    require 'persistence/sequel'

    db = Sequel.connect('sqlite://authors.db')

    # use sequel to declare an authors table
    db.create_table :authors do
      primary_key :id
      text        :title
      text        :fave_breakfast_cereal
    end

    # Repositories are where you put your data and where you can get it from later
    class AuthorRepository < Persistence::Sequel::IdentitySetRepository
      set_model_class Author
      use_table :authors, :id_sequence => true
      map_column :title
      map_column :fave_breakfast_cereal
    end

    # create one and hook it up to the sequel database
    author_repo = AuthorRepository.new(db)

    # Lets put jane in the database.  Poor jane.
    author_repo.store(jane_austen) # does the insert
    db[:authors].all.first # {:title=>"Jane Austen", :fave_breakfast_cereal=>"Cornflakes", :id=>1}

See, it really went in there! Lets get her out again...

    author = author_repo.get_by_property(:title, 'Jane Austen') # Jane Austen likes Cornflakes

    # And we can change stuff, too
    author.fave_breakfast_cereal = 'porridge'
    author_repo.store(author)
    author_repo.get_by_property(:fave_breakfast_cereal, 'Cornflakes') # nil

Let's give her some company...

    chaz = Author.new(:title => 'Charles Dickens', :fave_breakfast_cereal => 'Eggs')
    author_repo.store(chaz)

    # And we can fetch them all out in title order using a sequel
    author_repo.get_many_with_dataset {|dataset, mapping| dataset.order(:title) }.each do |author|
      puts author
    end

Here we made use of the fantastic Sequel library to order the rows by title before printing them.  You can do whatever you want here, query wise, as long as the column names match with how the model class was mapped.

Now we're going to add an association.  Let's throw some books in to the model.

    class Book < ThinModels::Struct
      identity_attribute
      attribute :title
      attribute :author
    end

    db.create_table :books do
      primary_key :id
      text        :title
      integer     :author_id
    end

    class BookRepository < Persistence::Sequel::IdentitySetRepository
      set_model_class Book
      use_table :books, :id_sequence => true
      map_column :title
      map_foreign_key :author, :model_class => Author
    end

    book_repo = BookRepository.new(db)
    # the book_repo doesn't know how to build or query authors, so we tell it
    # about the author_repo
    book_repo.mapper(:author).target_repo = author_repo
    pride_and_prej = Book.new(:title => 'Pride & Prejudice', :author => jane_austen)
    book_repo.store(pride_and_prej)

    # and lets fetch it out again to show the magic
    book = book_repo.get_by_id(pride_and_prej.id)
    puts book.author # Jane Austen likes...

You can also map in the other direction, mess about with polymorphism, and of course implement your own storage engines (think redis, file system, pictures of cats)
