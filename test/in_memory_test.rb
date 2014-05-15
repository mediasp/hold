require_relative 'interfaces'
require_relative '../lib/hold/in_memory'

describe "Hold::InMemory::Cell" do
  behaves_like "Hold::Cell"

  def make_cell
    Hold::InMemory::Cell.new
  end

  def make_cell_test_data(data='foo')
    data
  end
end

describe "Hold::InMemory::ArrayCell" do
  behaves_like "Hold::ArrayCell"

  def make_cell
    Hold::InMemory::ArrayCell.new
  end
end

describe "Hold::InMemory::ObjectCell" do
  behaves_like "Hold::ObjectCell"

  def make_cell
    Hold::InMemory::ObjectCell.new
  end
end

describe "Hold::InMemory::HashRepository" do
  behaves_like "Hold::HashRepository"

  def make_hash_repo
    Hold::InMemory::HashRepository.new
  end
end

describe "Hold::InMemory::SetRepository" do
  behaves_like "Hold::SetRepository"

  def make_set_repo
    Hold::InMemory::SetRepository.new
  end
end

describe "Hold::InMemory::IdentitySetRepository" do
  behaves_like "Hold::IdentitySetRepository"

  def make_id_set_repo
    Hold::InMemory::IdentitySetRepository.new
  end
end
