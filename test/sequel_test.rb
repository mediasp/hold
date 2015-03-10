require_relative 'interfaces'
require_relative '../lib/hold/sequel'

describe 'Hold::Sequel::IdentitySetRepository' do
  behaves_like 'Hold::IdentitySetRepository'

  # We create a fresh in-memory Sqlite database for each test.
  # If this proves too slow maybe re-use the database but wrap the run method
  # with a begin-ensure which rolls back the transaction and/or drops any
  # tables created
  def setup
    @repository = make_id_set_repo
  end

  def make_id_set_repo
    @db = Sequel.sqlite
    @db.create_table(:test_table) do
      primary_key :id
      varchar :abc
      varchar :def
    end
    Hold::Sequel::IdentitySetRepository(AbcDef, :test_table) do |repo|
      repo.map_column :abc
      repo.map_column :def
    end.new(@db)
  end

  it "allocates an id when storing something which doesn't have one, where there's an id property mapped to an auto_increment/serial primary key" do
    entity = make_entity(abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert entity.key?(:id)
    assert_kind_of Integer, entity.id
    assert @repository.contains_id?(entity.id)
  end

  it 'allows get_with_dataset and get_many_with_dataset to use arbitrary sequel conditions when fetching from the repo' do
    @repository.store_new(make_entity(abc: 'x', def: 'x'))
    @repository.store_new(make_entity(abc: 'x', def: 'y'))
    @repository.store_new(make_entity(abc: 'y', def: 'x'))
    @repository.store_new(make_entity(abc: 'y', def: 'y'))
    yy = @repository.get_with_dataset do |ds, mapping |
      ds.filter(abc: 'y', def: 'y')
    end
    assert_equal 'y', yy.abc
    assert_equal 'y', yy.def
    xxyy = @repository.get_many_with_dataset do |ds, mapping|
      ds.filter(abc: :def).order(Sequel.desc(:abc))
    end
    assert_equal ['y', 'y'], [xxyy[0].abc, xxyy[0].def]
    assert_equal ['x', 'x'], [xxyy[1].abc, xxyy[1].def]
  end

  it 'allows you to specify which properties to load eagerly, with the model returned able to lazily fetch the rest on demand (when ThinModels::Struct subclass used for the model)' do
    entity = make_entity(abc: 'abc', def: 'def')
    @repository.store_new(entity)
    id = entity.id

    entity = @repository.get_by_id(id, properties: [:id])
    assert entity.attribute_loaded?(:id)
    assert !entity.attribute_loaded?(:abc)
    assert !entity.attribute_loaded?(:def)
    assert_equal 'abc', entity.abc
    assert entity.attribute_loaded?(:abc)
    assert_equal 'def', entity[:def]
    assert entity.attribute_loaded?(:def)

    entity = @repository.get_by_id(id, properties: [:abc])
    assert entity.attribute_loaded?(:abc)
    assert !entity.attribute_loaded?(:def)
  end

  it 'raises an ArgumentError when property name passed as a string to  get_by_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_raise ArgumentError do
      @repository.get_by_property('abc', 'foo')
    end
  end

  it 'accepts a property name passed as a symbol to get_by_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_equal entity, @repository.get_by_property(:abc, 'foo')
  end

  it 'raises an ArgumentError when property name passed as a string to get_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_raise ArgumentError do
      @repository.get_property(entity, 'abc', {})
    end
  end
  it 'accepts a property name passed as a symbol to get_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_equal 'foo', @repository.get_property(entity, :abc, {})
  end

  it 'raises an ArgumentError when property name passed as a string to get_many_by_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_raise ArgumentError do
      @repository.get_many_by_property('abc', 'foo')
    end
  end

  it 'accepts a property name passed as a symbol to get_many_by_property' do
    entity = make_entity(id: 1, abc: 'foo', def: 'bar')
    @repository.store_new(entity)
    assert_equal [entity], @repository.get_many_by_property(:abc, 'foo')
  end

  describe '#map_column', self do
    it 'maps a schema property to a database column of the same name' do
      @db = Sequel.sqlite
      @db.create_table(:test_table) do
        primary_key :id
        varchar :string, null: false
      end
      @model_class = ThinModels::StructWithIdentity(:string)
      repo = Hold::Sequel::IdentitySetRepository(@model_class, :test_table) do |r|
        r.map_column :string
      end.new(@db)
      entity = @model_class.new(string: 'foo')
      repo.store(entity)
      assert_equal 'foo', @db[:test_table].select(:string).filter(id: entity.id).single_value
      assert_equal 'foo', repo.get_by_id(entity.id).string
    end

    it 'maps a schema property to a database column with a particular name, via explicit use of map_column' do
      @db = Sequel.sqlite
      @db.create_table(:test_table) do
        primary_key :id
        varchar :string_column_with_particular_name, null: false
      end
      @model_class = ThinModels::StructWithIdentity(:string)
      repo = Hold::Sequel::IdentitySetRepository(@model_class, :test_table) do |r|
        r.map_column :string, column_name: :string_column_with_particular_name
      end.new(@db)
      entity = @model_class.new(string: 'foo')
      repo.store(entity)
      assert_equal 'foo', @db[:test_table].select(:string_column_with_particular_name).filter(id: entity.id).single_value
      assert_equal 'foo', repo.get_by_id(entity.id).string
    end

    it 'roundtrips various value types correctly to and from sql columns, loading the relevant properties eagerly' do
      @db = Sequel.sqlite
      @db.create_table(:test_table) do
        primary_key :id
        integer :integer
        datetime :datetime
        float :float
      end
      @model_class = ThinModels::StructWithIdentity(:integer, :datetime, :float)
      repo = Hold::Sequel::IdentitySetRepository(@model_class, :test_table) do |r|
        r.map_column :integer
        r.map_column :datetime
        r.map_column :float
      end.new(@db)
      entity = @model_class.new(
        integer: 123,
        datetime: Time.utc(2000, 1, 2, 12, 30),
        float: -123e-5
      )
      repo.store(entity)
      entity = repo.get_by_id(entity.id)
      assert entity.key?(:integer)
      assert entity.key?(:datetime)
      assert entity.key?(:float)
      assert_equal 123, entity.integer
      assert_instance_of Time, entity.datetime
      assert_equal Time.utc(2000, 1, 2, 12, 30), entity.datetime
      assert_in_delta -123e-5, entity.float, 1e-10
    end
  end

  describe '#map_transformed_column', self do
    it 'works like map_column but apply custom to_sequel and from_sequel transformations when translating values to and from something which can be put in a db column via sequel' do
      @db = Sequel.sqlite
      @db.create_table(:test_table) do
        primary_key :id
        varchar :foo, null: false
      end
      @model_class = ThinModels::StructWithIdentity(:foo)
      repo = Hold::Sequel::IdentitySetRepository(@model_class, :test_table) do |r|
        r.map_transformed_column :foo,
          to_sequel: proc { |v| v.join(',') },
          from_sequel: proc { |v| v.split(',') }
      end.new(@db)
      entity = @model_class.new(foo: ['a', 'b', 'c'])
      repo.store(entity)
      assert_equal 'a,b,c', @db[:test_table].select(:foo).filter(id: entity.id).single_value
      assert_equal ['a', 'b', 'c'], repo.get_by_id(entity.id).foo
    end
  end

  describe 'map_created_at / map_updated_at', self do
    def setup
      @db = Sequel.sqlite
      @db.create_table(:test_table) do
        primary_key :id
        datetime :created_at, null: false
        datetime :updated_at, null: false
      end
      @model_class = ThinModels::StructWithIdentity(:created_at, :updated_at)
      @repo = Hold::Sequel::IdentitySetRepository(@model_class, :test_table) do |repo|
        # the args here can all actually be left out as they're the defaults, but to demonstrate:
        repo.map_created_at :created_at
        repo.map_updated_at :updated_at, column_name: :updated_at
      end.new(@db)
    end

    it 'sets created_at and updated_at to the current time when first storing an object, also setting the values on the entity instance used' do
      now = Time.local(2010, 10, 11, 12, 13, 14); Time.stubs(:now).returns(now)
      entity = @model_class.new
      @repo.store(entity)
      assert_equal now, entity.created_at
      assert_equal now, entity.updated_at
      entity = @repo.reload(entity)
      assert_equal now, entity.created_at
      assert_equal now, entity.updated_at
    end

    it 'on a subsequent store which updates an already-stored entity, should update updated_at but not update created_at' do
      entity = @model_class.new
      @repo.store(entity)
      initial_created_at = entity.created_at
      initial_updated_at = entity.updated_at

      sleep 1 # just in case
      @repo.store(entity)
      assert_equal initial_created_at, entity.created_at
      assert entity.updated_at > initial_updated_at

      entity = @repo.reload(entity)
      assert entity.updated_at > initial_updated_at
    end

  end

  describe '#map_foreign_key', self do
    def setup
      @db = Sequel.sqlite
      @db.create_table(:bar) do
        primary_key :id
        varchar :string
      end
      @db.create_table(:foo) do
        primary_key :id
        integer :bar_id
      end
      bar_model_class = @bar_model_class = ThinModels::StructWithIdentity(:string)
      @foo_model_class = ThinModels::StructWithIdentity(:bar)
      bar_repo = @bar_repo = Hold::Sequel::IdentitySetRepository(@bar_model_class, :bar) do |repo|
        repo.map_column :string
      end.new(@db)
      @foo_repo = Hold::Sequel::IdentitySetRepository(@foo_model_class, :foo) do |repo|
        repo.map_foreign_key :bar, model_class: bar_model_class
      end.new(@db)
      @foo_repo.mapper(:bar).target_repo = @bar_repo
    end

    it 'maps a property whose schema refers to another Object schema with identity, to a foreign key column using those identity values, and using a repo for that schema to look up the instances' do
      bar = @bar_model_class.new(string: 'bar')
      @bar_repo.store(bar)
      assert_not_nil bar.id

      foo = @foo_model_class.new(bar: bar)
      @foo_repo.store(foo)

      assert_equal bar.id, @db[:foo].select(:bar_id).filter(id: foo.id).single_value

      foo = @foo_repo.get_by_id(foo.id)
      assert_equal bar.id, foo.bar.id
      assert_equal 'bar', foo.bar.string
    end

    it 'when multiple rows are fetched, should get multiple referenced items in a batched fashion too using get_many_by_ids on the target repo with their foreign keys' do
      bars = ['0', '1', '2'].map { |n|
        b = @bar_model_class.new(string: n)
        @bar_repo.store(b)
        b
      }
      foos = bars.map { |bar|
        f = @foo_model_class.new(bar: bar)
        @foo_repo.store(f)
        f
      }
      bar_ids = bars.map { |b| b.id }
      foo_ids = foos.map { |f| f.id }

      @bar_repo.expects(:get_many_by_ids).with(bar_ids, anything).returns(bars)
      @foo_repo.get_many_by_ids(foo_ids, properties: { bar: true })
    end

    it 'maps nil ok' do
      foo = @foo_model_class.new(bar: nil)
      @foo_repo.store(foo)
      foo_again = @foo_repo.reload(foo)
      assert_nil foo_again.bar
    end

    it 'updates ok' do
      bar0, bar1 = ['0', '1'].map { |n|
        b = @bar_model_class.new(string: n)
        @bar_repo.store(b)
        b
      }
      foo = @foo_model_class.new(bar: bar0)
      @foo_repo.store(foo)
      @foo_repo.cell(foo).set_property(:bar, bar1)
      foo_again = @foo_repo.reload(foo)
      assert_equal bar1.id, foo_again.bar.id
    end

    it 'gets appropriate version of associated objects taking into account a property version specifying which properties to fetch on it' do
      bar = @bar_model_class.new(string: 'bar')
      @bar_repo.store(bar)
      foo = @foo_model_class.new(bar: bar)
      @foo_repo.store(foo)
      foo1 = @foo_repo.get_by_id(foo.id, properties: [:id])
      assert !foo1.key?(:bar)
      foo2 = @foo_repo.get_by_id(foo.id, properties: { bar: [:id] })
      assert foo2.key?(:bar)
      assert_equal bar.id, foo2.bar.id
      assert !foo2.bar.key?(:string)
      foo3 = @foo_repo.get_by_id(foo.id, properties: { bar: [:id, :string] })
      assert foo3.key?(:bar)
      assert_equal bar.id, foo3.bar.id
      assert_equal 'bar', foo3.bar.string
    end

    it 'is eagerly loaded by default, but only a version consisting of the ID, which is already present on the original result row as a foreign key' do
      bar = @bar_model_class.new(string: 'bar'); @bar_repo.store(bar)
      foo = @foo_model_class.new(bar: bar); @foo_repo.store(foo)

      # quick if slightly brittle way of checking that no separate sql query is
      # done for 'bar'
      @bar_repo.expects(:query).never

      foo = @foo_repo.get_by_id(foo.id)
      assert foo.key?(:bar)
      assert foo.bar.key?(:id)
      assert !foo.bar.key?(:string)
    end
  end

  describe '#map_one_to_many', self do
    Bar = ThinModels::StructWithIdentity(:foos)
    Foo = ThinModels::StructWithIdentity(:bar)

    def setup
      @db = Sequel.sqlite
      @db.create_table(:bar) do
        primary_key :id
      end
      @db.create_table(:foo) do
        primary_key :id
        integer :bar_id
      end
      bar_model_class = @bar_model_class = Bar #ThinModels::StructWithIdentity(:foos)
      foo_model_class = @foo_model_class = Foo #ThinModels::StructWithIdentity(:bar)
      # foo_repo = 123
      bar_repo = @bar_repo = Hold::Sequel::IdentitySetRepository(@bar_model_class, :bar) do |repo|
        repo.map_one_to_many :foos, model_class: foo_model_class, property: :bar
      end.new(@db)
      foo_repo = @foo_repo = Hold::Sequel::IdentitySetRepository(@foo_model_class, :foo) do |repo|
        repo.map_foreign_key :bar, model_class: bar_model_class
      end.new(@db)

      bar_repo.mapper(:foos).target_repo = foo_repo
      foo_repo.mapper(:bar).target_repo = bar_repo

      assert_same bar_repo.mapper(:foos).target_repo, foo_repo
      assert_same foo_repo.mapper(:bar).target_repo, bar_repo
      assert_same bar_repo.mapper(:foos).model_class, foo_model_class
      assert_same foo_repo.mapper(:bar).model_class, bar_model_class

      assert_not_same bar_repo, foo_repo
      assert_not_same bar_model_class, foo_model_class
    end

    it 'maps to an array of associated items drawn from get_many_with_dataset on a suitable repository' do
      bar = @bar_model_class.new
      @bar_repo.store(bar)
      foos = (1..3).map { |n|
        f = @foo_model_class.new(bar: bar)
        @foo_repo.store(f)
        f
      }

      bar = @bar_repo.reload(bar)
      assert_equal(foos.map { |f| f.id }, bar.foos.map { |f| f.id })
    end

    it 'works when getting multiple items' do
      bars = (0...2).map { |n|
        b = @bar_model_class.new
        @bar_repo.store(b)
        b
      }
      foos = (0...4).map { |n|
        f = @foo_model_class.new(bar: bars[n/2])
        @foo_repo.store(f)
        f
      }
      bars = @bar_repo.get_many_by_ids(bars.map { |b| b.id })
      assert_equal([foos[0].id, foos[1].id], bars[0].foos.map { |f| f.id })
      assert_equal([foos[2].id, foos[3].id], bars[1].foos.map { |f| f.id })
    end
  end

  describe '#array_cell_for_dataset', self do
    def setup
      super
      @entities = (0...3).map { |n| make_entity(abc: n.to_s, def: 'bar') }
      @entities.each { |e| @repository.store_new(e) }
    end

    it 'exposes the full collection of objects stored in the repository' do
      @cell = @repository.array_cell_for_dataset
      assert_equal @entities.sort_by(&:id), @cell.get.sort_by(&:id)
      assert_equal @entities.length, @cell.get_length
    end

    it 'allows the dataset to be filtered, ordered etc via a block' do
      @cell = @repository.array_cell_for_dataset do |ds,mapping|
        ds.filter(id: [@entities[0].id, @entities[1].id]).order(Sequel.desc(:id))
      end
      assert_equal @entities[0..1].sort_by {|e| -e.id}, @cell.get
      assert_equal 2, @cell.get_length
    end

    it 'should get_slice via adding a LIMIT clause to the dataset' do
      begin
        # Couldn't find a decent way to do this with mocha - needs a 'test spy', something like
        # "expects(method).once.with(foo).returns_using_existing_implementation"
        @db.expects(:dummy)
        class << @db
          alias :_old_execute :execute
          def execute(sql, *p, &b)
            raise "SQL didn't have expected limit clause" unless /LIMIT (1\s*,\s*2|2\s+OFFSET\s+1)/i =~ sql
            dummy
            _old_execute(sql, *p, &b)
          end
        end

        @cell = @repository.array_cell_for_dataset { |ds,mapping| ds.order(:id) }
        assert_equal @entities[1, 2], @cell.get_slice(1, 2)
      ensure
        class << @db
          undef :execute
          alias :execute :_old_execute
        end
      end
    end
  end

  describe 'mapped to multiple tables', self do
    behaves_like "Hold::IdentitySetRepository"

    def make_id_set_repo
      @db = Sequel.sqlite
      @db.create_table(:base) do
        primary_key :id
        varchar :abc
      end
      @db.create_table(:extra) do
        integer :base_id
        varchar :def
      end
      Hold::Sequel::IdentitySetRepository(AbcDef, :base) do |repo|
        repo.use_table :base
        repo.use_table :extra, id_column: :base_id
        repo.map_column :abc
        repo.map_column :def, table: :extra
      end.new(@db)
    end
  end

  describe 'WithPolymorphicTypeColumn used without any extra subclass-specific properties', self do
    behaves_like "Hold::IdentitySetRepository"

    def make_id_set_repo
      @db = Sequel.sqlite
      the_superclass = AbcDef
      the_subclass = @subclass = Class.new(the_superclass)
      @db.create_table(:test_table) do
        primary_key :id
        varchar :type, null: false
        varchar :abc
        varchar :def
      end
      Class.new(Hold::Sequel::IdentitySetRepository::WithPolymorphicTypeColumn) do
        use_table :test_table
        set_type_column(:type, the_superclass => 'super', the_subclass => 'sub')
        set_model_class AbcDef
        map_column :abc
        map_column :def
      end.new(@db)
    end

    it 'roundtrips a subclass instance, persisting its class' do
      entity = @subclass.new(id: 1, abc: 'foo')
      @repository.store_new(entity)
      again = @repository.get_by_id(1)
      assert_instance_of @subclass, again
      assert_equal 1,     again.id
      assert_equal 'foo', again.abc
    end
  end

  describe 'class table inheritance scenario with WithPolymorphicTypeColumn', self do
    def setup
      @db = Sequel.sqlite
      @db.create_table(:base) do
        primary_key :id
        varchar :type, null: false
        varchar :abc, null: false
      end
      @db.create_table(:sub) do
        integer :base_id
        varchar :def, null: true
      end
      the_baseclass = @baseclass = Class.new(ThinModels::Struct) do
        def self.to_s; 'baseclass'; end
        identity_attribute
        attribute :abc
      end
      the_subclass = @subclass = Class.new(@baseclass) do
        def self.to_s; 'subclass'; end
        attribute :def
      end

      @baseclass_repo_class = Class.new(Hold::Sequel::IdentitySetRepository::WithPolymorphicTypeColumn) do
        use_table :base, id_sequence: true
        set_type_column(:type, the_baseclass => 'baseclass', the_subclass => 'subclass')
        set_model_class(the_baseclass)
        map_column :abc
      end
      @subclass_repo_class = Class.new(@baseclass_repo_class) do
        set_model_class(the_subclass)
        use_table :sub, id_column: :base_id, restricts_type: true
        map_column :def, table: :sub
      end

      @baseclass_repo = @baseclass_repo_class.new(@db)
      @subclass_repo = @subclass_repo_class.new(@db)
    end

    it 'subclass repo should roundtrip a subclass instance, persisting its class and subclass-specific properties' do
      entity = @subclass.new(abc: 'foo', def: 'ghi')
      @subclass_repo.store_new(entity)
      again = @subclass_repo.get_by_id(entity.id)
      assert_instance_of @subclass, again
      assert_equal 1,     again.id
      assert_equal 'foo', again.abc
      assert_equal 'ghi', again.def
    end

    it 'baseclass repo should polymorphically select super/subclass instances (although without loading any subclass-specific properties)' do
      entity = @subclass.new(abc: 'foo', def: 'ghi')
      @subclass_repo.store_new(entity)
      entity2 = @baseclass.new(abc: 'bar')
      @baseclass_repo.store_new(entity2)
      poly1, poly2 = @baseclass_repo.get_many_by_ids([entity.id, entity2.id])
      assert_instance_of @subclass, poly1
      assert_instance_of @baseclass, poly2
      assert !poly2.key?(:def)
    end

    it 'subclass repo should not load instance which is not of that subclass' do
      entity = @baseclass.new(abc: 'bar')
      @baseclass_repo.store_new(entity)
      assert_nil @subclass_repo.get_by_id(entity.id)
      assert !@subclass_repo.contains?(entity)
    end
  end
end
