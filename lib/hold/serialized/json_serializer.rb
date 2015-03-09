require 'hold/serialized'
require 'json'

module Hold
  module Serialized
    class JSONSerializer
      def serialize(entity)
        entity.to_json
      end

      def deserialize(string)
        JSON.parse(string)
      end
    end
  end
end
