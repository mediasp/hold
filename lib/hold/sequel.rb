require 'hold/interfaces'
require 'hold/error'
require 'hold/sequel/identity_set_repository'
require 'hold/sequel/polymorphic_repository'
require 'hold/sequel/with_polymorphic_type_column'
require 'hold/sequel/query'
require 'hold/sequel/dataset_lazy_array'
require 'hold/sequel/query_array_cell'
require 'hold/sequel/repository_observer'
require 'hold/sequel/property_mapper'
require 'hold/sequel/property_mapper/column'
require 'hold/sequel/property_mapper/identity'
require 'hold/sequel/property_mapper/updated_at'
require 'hold/sequel/property_mapper/created_at'
require 'hold/sequel/property_mapper/transformed_column'
require 'hold/sequel/property_mapper/foreign_key'
require 'hold/sequel/property_mapper/one_to_many'
require 'hold/sequel/property_mapper/many_to_many'
require 'hold/sequel/property_mapper/hash'
require 'hold/sequel/property_mapper/array'
require 'hold/sequel/property_mapper/custom_query'
require 'hold/sequel/property_mapper/custom_query_single_value'
require 'sequel'

module Hold
  # Module containing implementations of hold interfaces which persist in a
  # relational database, using the Sequel library, via some configurable
  # mapping.
  module Sequel
    def self.translate_exceptions
      yield
    rescue ::Sequel::DatabaseError => error
      case error.message
      when /duplicate|unique/i
        raise Hold::IdentityConflict
      else
        error.extend(Hold::Error)
        raise
      end
    end
  end
end
