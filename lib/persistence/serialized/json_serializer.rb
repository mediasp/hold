require 'hold/serialized'
require 'json'

class Hold::Serialized::JSONSerializer
  def serialize(entity)
    entity.to_json
  end

  def deserialize(string)
    JSON.parse(string)
  end
end
