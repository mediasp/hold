require 'test/interfaces'
require 'persistence/in_memory'

describe "Persistence::InMemory::Cell" do
  behaves_like "Persistence::Cell"

  def make_cell
    Persistence::InMemory::Cell.new
  end

  def make_cell_test_data(data='foo')
    data
  end
end

describe "Persistence::InMemory::ArrayCell" do
  behaves_like "Persistence::ArrayCell"

  def make_cell
    Persistence::InMemory::ArrayCell.new
  end
end

describe "Persistence::InMemory::ObjectCell" do
  behaves_like "Persistence::ObjectCell"

  def make_cell
    Persistence::InMemory::ObjectCell.new
  end
end

describe "Persistence::InMemory::HashRepository" do
  behaves_like "Persistence::HashRepository"

  def make_hash_repo
    Persistence::InMemory::HashRepository.new
  end
end

describe "Persistence::InMemory::SetRepository" do
  behaves_like "Persistence::SetRepository"

  def make_set_repo
    Persistence::InMemory::SetRepository.new
  end
end

describe "Persistence::InMemory::IdentitySetRepository" do
  behaves_like "Persistence::IdentitySetRepository"

  def make_id_set_repo
    Persistence::InMemory::IdentitySetRepository.new
  end
end
