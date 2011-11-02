# Quick Start Guide

I say quick-start, but by it's very nature and early stage of development, it ain't that quick.  This library is more verbose entirely because we wanted something that didn't tie us to a particular persistence mechanism and that meant more boilerplate.

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
    repo = AuthorRepository.new(db)

    # Lets put jane in the database.  Poor jane.
    repo.store(jane_austen) # does the insert
    db[:authors].all.first # {:title=>"Jane Austen", :fave_breakfast_cereal=>"Cornflakes", :id=>1}

See, it really went in there! Lets get her out again...

    author = repo.get_by_property(:title, 'Jane Austen') # Jane Austen likes Cornflakes

    # And we can change stuff, too
    author.fave_breakfast_cereal = 'porridge'
    repo.store(author)
    repo.get_by_property(:fave_breakfast_cereal, 'Cornflakes') # nil

Let's give her some company...

    chaz = Author.new(:title => 'Charles Dickens', :fave_breakfast_cereal => 'Eggs')
    repo.store(chaz)

    # And we can fetch them all out in title order using a sequel
    repo.get_many_with_dataset {|dataset, mapping| dataset.order(:title) }.each do |author|
      puts author
    end

Here we made use of the fantastic Sequel library to order the rows by title before printing them.  You can do whatever you want here, query wise, as long as the column names match with how the model class was mapped.

## That's all for now

More to come, hopefully.