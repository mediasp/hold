require 'persistence/interfaces'
require 'persistence/sequel/identity_set_repository'
require 'persistence/sequel/polymorphic_repository'
require 'persistence/sequel/with_polymorphic_type_column'
require 'persistence/sequel/query'
require 'persistence/sequel/dataset_lazy_array'
require 'persistence/sequel/query_array_cell'
require 'persistence/sequel/repository_observer'
require 'persistence/sequel/property_mapper'
require 'persistence/sequel/property_mapper/column'
require 'persistence/sequel/property_mapper/identity'
require 'persistence/sequel/property_mapper/updated_at'
require 'persistence/sequel/property_mapper/created_at'
require 'persistence/sequel/property_mapper/foreign_key'
require 'persistence/sequel/property_mapper/one_to_many'
require 'persistence/sequel/property_mapper/many_to_many'
require 'persistence/sequel/property_mapper/hash'
require 'persistence/sequel/property_mapper/array'
require 'persistence/sequel/property_mapper/custom_query'
require 'persistence/sequel/property_mapper/custom_query_single_value'
require 'sequel'

module Persistence
  # Module containing implementations of persistence interfaces which persist in a relational database, using the Sequel
  # library, via some configurable mapping.
  module Sequel

    def self.translate_exceptions
      begin
        yield
      rescue ::Sequel::DatabaseError => e
        case e.message
        when /duplicate|unique/i then raise Persistence::IdentityConflict.new(e)
        else raise Persistence::Error.new("#{e.class}: #{e.message}")
        end
      end
    end

  end
end
