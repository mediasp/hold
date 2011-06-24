require 'test/helpers'
require 'persistence/interfaces'
require 'thin_models/struct/identity'

module PersistenceTestHelpers
  def void_where_unsupported
    begin
      yield
      true
    rescue Persistence::UnsupportedOperation
      false
    end
  end
end

describe_shared "Persistence::Cell" do
  def make_cell
    # Some::Cell.new
  end

  def make_cell_test_data(data='foo')
    # some data to try storing inside the cell, based on the arg
  end

  include PersistenceTestHelpers

  describe "in its implementation of Persistence::Cell", self do
    def setup
      @cell = make_cell
    end

    it "should set then get" do
      value = make_cell_test_data
      @cell.set(value)
      assert_equal value, @cell.get
    end

    it "should allow second set to overwrite first" do
      value1 = make_cell_test_data('foo')
      value2 = make_cell_test_data('bar')
      @cell.set(value1)
      @cell.set(value2)
      assert_equal value2, @cell.get
    end

    it "should not be empty after set" do
      value = make_cell_test_data
      @cell.set(value)
      assert !@cell.empty?
    end

    it "should be empty after clear, where supported" do
      void_where_unsupported do
        value = make_cell_test_data
        @cell.set(value)
        @cell.clear
        assert @cell.empty?
        assert_nil @cell.get
      end
    end

    it "should distinguish nil from empty, where empty is supported" do
      void_where_unsupported do
        @cell.clear
        assert @cell.empty?
        assert_nil @cell.get
        @cell.set(nil)
        assert !@cell.empty?
        assert_nil @cell.get
      end
    end
  end
end

describe_shared "Persistence::ArrayCell" do
  behaves_like "Persistence::Cell"

  # should make an instance of the relevant ArrayCell class
  def make_cell
    # Some::ArrayCell.new
  end

  def make_cell_test_data(data='foo')
    [data]
  end

  describe "in its implementation of Persistence::ArrayCell", self do
    def setup
      @cell = make_cell
    end

    it "should allow you to get slices of an array set within it" do
      @cell.set(['a','b','c'])
      assert_equal [], @cell.get_slice(0,0)
      assert_equal ['a'], @cell.get_slice(0,1)
      assert_equal ['b','c'], @cell.get_slice(1,2)
      assert_equal ['c'], @cell.get_slice(2,3)
      assert_equal [], @cell.get_slice(3,1)
      assert_equal nil, @cell.get_slice(4,1)
    end

    it "should allow you to get length of an array set within it" do
      @cell.set(['a','b','c'])
      assert_equal 3, @cell.get_length
      @cell.set([])
      assert_equal 0, @cell.get_length
    end

    it "should allow you to get a lazy array based off get_length and get_slice" do
      @cell.set(['a','b','c','d'])
      @cell.expects(:get).never
      @cell.expects(:get_length).returns(4)
      @cell.expects(:get_slice).with(1,2).returns(['b','c'])
      lazy = @cell.get_lazy_array
      assert_equal 4, lazy.length
      assert_equal ['b','c'], lazy[1...3]
    end

  end
end

describe_shared "Persistence::ObjectCell" do
  behaves_like "Persistence::Cell"

  def make_cell
    # Some::ObjectCell.new
  end

  def make_cell_test_data(data='foo')
    {:foo => data}
  end

  describe "in its implementation of Persistence::ObjectCell", self do
    def setup
      @cell = make_cell
    end

    it "should allow you to get_property of an object within it" do
      @cell.set(:foo => 'bar')
      assert_equal 'bar', @cell.get_property(:foo)
    end

    it "should allow you to set_property of an object within it" do
      @cell.set({})
      @cell.set_property :foo, 'bar'
      assert_equal 'bar', @cell.get_property(:foo)
      assert_equal({:foo => 'bar'}, @cell.get)
    end

    it "should allow you to has_property? for the object set within it" do
      @cell.set({})
      assert !@cell.has_property?(:foo)
      @cell.set({:foo=>'bar'})
      assert @cell.has_property?(:foo)
    end

    it "should allow you to clear_property for the object set within it" do
      @cell.set(:foo => 'bar')
      @cell.clear_property(:foo)
      assert_equal({}, @cell.get)
      assert !@cell.has_property?(:foo)
    end

    it "should allow you to get multiple properties" do
      @cell.set({:foo => 'x', :bar => 'y'})
      assert_equal ['x','y'], @cell.get_properties(:foo,:bar)
    end

    it "should allow nil and missing property values to be distinguished" do
      @cell.set({})
      assert_nil @cell.get_property(:foo)
      assert_nil @cell.property_cell(:foo).get
      assert !@cell.has_property?(:foo)
      assert @cell.property_cell(:foo).empty?

      @cell.set({:foo => nil})
      assert_nil @cell.get_property(:foo)
      assert_nil @cell.property_cell(:foo).get
      assert @cell.has_property?(:foo)
      assert !@cell.property_cell(:foo).empty?
    end

    it "should expose a property_cell whose get / set / clear / empty? methods correspond to get/set/clear/has_property" do
      @cell.set({})
      assert @cell.property_cell(:foo).empty?
      @cell.property_cell(:foo).set('bar')
      assert_equal 'bar', @cell.property_cell(:foo).get
      assert_equal 'bar', @cell.get_property(:foo)
      assert !@cell.property_cell(:foo).empty?
      @cell.property_cell(:foo).clear
      assert @cell.property_cell(:foo).empty?
      assert !@cell.has_property?(:foo)
    end

    describe "its property_cell for a property", self do
      behaves_like 'Persistence::Cell'

      def make_cell
        cell = super
        cell.set({})
        cell.property_cell(:foo)
      end

      def make_cell_test_data(data='foo')
        data
      end
    end
  end
end



describe_shared "Persistence::HashRepository" do
  # should make a HashRepository with integer keys and whatever values you like,
  # provided you implement make_test_value to make suitable values
  def make_hash_repo
    #
  end

  # makes an instance usable as a value for testing.
  # @repository will be set to the result of make_hash_repo
  def make_hash_repo_test_value(data='foo')
    data
  end

  describe "in its implementation of Persistence::HashRepository", self do
    def setup
      @repository = make_hash_repo
    end

    it "should return nil on get_with_key of missing" do
      assert_nil @repository.get_with_key(1234)
    end

    it "should set_with_key then get_with_key, returning a different instance" do
      @value = make_hash_repo_test_value('foo')
      @repository.set_with_key(123, @value)
      again = @repository.get_with_key(123)
      assert_equal @value, again
      assert_not_same @value, again
    end

    it "should allow store to replace existing" do
      value = make_hash_repo_test_value('foo')
      @repository.set_with_key(1, value)
      assert_equal value, @repository.get_with_key(1)
      value2 = make_hash_repo_test_value('bar')
      @repository.set_with_key(1, value2)
      assert_equal value2, @repository.get_with_key(1)
    end

    it "should has_key? true for a key under which something is stored" do
      value = make_hash_repo_test_value('foo')
      @repository.set_with_key(1, value)
      assert @repository.has_key?(1)
    end

    it "should not has_key? for a key not stored" do
      assert !@repository.has_key?(1)
    end

    it "should successfully clear_key a stored value by its key" do
      value = make_hash_repo_test_value('foo')
      @repository.set_with_key(1, value)
      @repository.clear_key(1)
      assert !@repository.has_key?(1)
    end

    it "should not do anything on clear_key of an unused key" do
      value = make_hash_repo_test_value('foo')
      @repository.clear_key(1)
      assert !@repository.has_key?(1)
    end
  end
end

describe_shared "Persistence::SetRepository" do
  def make_set_repo
    # ...
  end

  def make_set_repo_test_value(data=123)
    data
  end

  include PersistenceTestHelpers

  describe "in its implementation of Persistence::SetRepository", self do
    def setup
      @repository = make_set_repo
    end

    it "should store stuff, then this and only this stuff should (where supported) show up in get_all" do
      data = make_set_repo_test_value(123)
      @repository.store(data)
      void_where_unsupported do
        assert_equal [data], @repository.get_all
      end
      data2 = make_set_repo_test_value(456)
      @repository.store(data2)
      void_where_unsupported do
        assert [[data, data2], [data2, data]].include?(@repository.get_all)
      end
    end

    it "should not show duplicates via get_all when the same thing persisted via store" do
      @repository.store(make_set_repo_test_value(123))
      @repository.store(make_set_repo_test_value(123))
      void_where_unsupported do
        assert_equal 1, @repository.get_all.length
      end
    end

    it "should store_new then (where supported) show up in get_all" do
      data = make_set_repo_test_value(123)
      @repository.store_new(data)
      void_where_unsupported do
        assert_equal [data], @repository.get_all
      end
      data2 = make_set_repo_test_value(456)
      @repository.store_new(data2)
      void_where_unsupported do
        assert [[data, data2], [data2, data]].include?(@repository.get_all)
      end
    end

    it "should not allow store_new to replace existing" do
      entity = make_set_repo_test_value(123)
      @repository.store(entity)
      assert_raise(Persistence::IdentityConflict) do
        @repository.store_new(entity)
      end
    end

    it "should contains? true for something stored" do
      entity = make_set_repo_test_value(123)
      @repository.store(entity)
      assert @repository.contains?(entity)
    end

    it "should not contains? something not stored" do
      entity = make_set_repo_test_value(123)
      assert !@repository.contains?(entity)
    end

    it "should successfully delete a stored entity, after which it does not contains? it" do
      entity = make_set_repo_test_value(123)
      @repository.store(entity)
      @repository.delete(entity)
      assert !@repository.contains?(entity)
    end

    it "should not do anything on delete of a non-stored entity" do
      entity = make_set_repo_test_value(123)
      @repository.delete(entity)
      assert !@repository.contains?(entity)
    end
  end
end

AbcDef = ThinModels::StructWithIdentity(:abc, :def)

describe_shared "Persistence::IdentitySetRepository" do
  behaves_like "Persistence::SetRepository"

  def make_set_repo
    make_id_set_repo
  end

  def make_set_repo_test_value(id=123)
    make_entity(:id => id)
  end

  def make_id_set_repo
    # Some::Repo.new
  end

  # should make an object for testing purposes which has :abc and :def properties
  # which the tests can use.
  def make_entity(props={})
    AbcDef.new(props)
  end

  include PersistenceTestHelpers

  describe "in its implementation of Persistence::IdentitySetRepository", self do
    def setup
      @repository = make_id_set_repo
    end

    it "should store then get_by_id, returning a different instance" do
      entity = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity)
      again = @repository.get_by_id(1)
      assert_equal 1,     again.id
      assert_equal 'foo', again.abc
      assert_not_same entity, again
    end

    it "should allow store to update properties of an existing persisted instance with the same ID" do
      entity = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity)
      assert_equal 'foo', @repository.get_by_id(1).abc
      entity = make_entity(:id => 1, :abc => 'bar')
      @repository.store(entity)
      assert_equal 'bar', @repository.get_by_id(1).abc
    end

    it "should store many then get_many_by_ids" do
      entity1 = make_entity(:id => 1, :abc => 'foo')
      entity2 = make_entity(:id => 2, :abc => 'bar')
      @repository.store(entity1)
      @repository.store(entity2)
      again1, again2 = @repository.get_many_by_ids([1,2])
      assert_equal 'foo', again1.abc
      assert_equal 'bar', again2.abc
    end

    it "should return nils in the array returned by get_many_by_ids corresponding to ids which were not found" do
      entity1 = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity1)
      again1, again2 = @repository.get_many_by_ids([123,1])
      assert_nil again1
      assert_equal 'foo', again2.abc
    end

    it "should not allow store_new to replace existing with the same ID" do
      entity = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity)
      assert_equal 'foo', @repository.get_by_id(1).abc
      entity = make_entity(:id => 1, :abc => 'bar')
      assert_raise(Persistence::IdentityConflict) {@repository.store_new(entity)}
    end

    it "should reload an object with just its identity, returning the full entity as a different instance" do
      entity = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity)
      id_entity = make_entity(:id => 1)
      reloaded = @repository.reload(id_entity)
      assert_equal 'foo', reloaded.abc
      assert_not_same id_entity, reloaded
    end

    it "should load an object with just its identity, returning the same instance with the full entity properties" do
      entity = make_entity(:id => 1, :abc => 'foo')
      @repository.store(entity)
      id_entity = make_entity(:id => 1)
      loaded = @repository.load(id_entity)
      assert_equal 'foo', loaded.abc
      assert_same id_entity, loaded
    end

    it "should apply an update_entity to an entity in the repo" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      update_entity = make_entity(:def => 'updated!')
      result = @repository.update(entity, update_entity)
      after = @repository.get_by_id(1)
      assert_equal 1, after.id
      assert_equal 'foo', after.abc
      assert_equal 'updated!', after.def
      assert_same result, entity
      assert_equal 'updated!', result.def
    end

    it "should apply an update entity to an id of an entity in the repository" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      update_entity = make_entity(:def => 'updated!')
      @repository.update_by_id(1, update_entity)
      after = @repository.get_by_id(1)
      assert_equal 1, after.id
      assert_equal 'foo', after.abc
      assert_equal 'updated!', after.def
    end

    it "should do nothing when asked to update an identity which doesn't exist in the repo" do
      update_entity = make_entity(:id => 1, :abc => 'foo', :def => 'updated!')
      @repository.update_by_id(1, update_entity)
      @repository.update(update_entity, update_entity)
      assert_nil @repository.get_by_id(1)
    end

    it "should contains_id? true for something stored" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      assert @repository.contains_id?(1)
    end

    it "should not contains_id? something not stored" do
      assert !@repository.contains_id?(1)
    end

    it "should successfully delete_id a stored entity by its id" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      @repository.delete_id(1)
      assert !@repository.contains?(entity)
      assert !@repository.contains_id?(1)
    end

    it "should update a property of a stored entity via set_property-ing the entity's persistence cell in this repo" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      @repository.cell(entity).set_property(:abc, 'updated!')
      after = @repository.get_by_id(1)
      assert_equal 1, after.id
      assert_equal 'updated!', after.abc
      assert_equal 'bar', after.def
    end

    it "should get a property of a stored entity via get_property-ing the entity's persistence cell in this repo" do
      entity = make_entity(:id => 1, :abc => 'foo', :def => 'bar')
      @repository.store(entity)
      assert_equal 'foo', @repository.cell(entity).get_property(:abc)
    end

  end
end
