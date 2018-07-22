require "json"

module Util
  def self.pretty_json(
    obj,
    *,
    child_depth : Int32 = 1,
    indent : String = "  "
  ) : String
    case obj
    when Hash
      s = "{\n"
      obj.each_with_index do |(k, v), index|
        s += indent * child_depth + "\"#{k}\": "
        s += pretty_json(v, child_depth: child_depth + 1, indent: indent)
        s += "," if index < (obj.size - 1)
        s += "\n"
      end
      s + indent * (child_depth - 1) + "}"
    when Array
      s = "[\n"
      obj.each_with_index do |v, index|
        s += indent * child_depth
        s += pretty_json(v, child_depth: child_depth + 1, indent: indent)
        s += "," if index < (obj.size - 1)
        s += "\n"
      end
      s + indent * (child_depth - 1) + "]"
    when Enum
      obj.to_s.to_json
    when Number, Bool, String, Nil
      obj.to_json
    else
      raise "invalid object of type #{obj.class.name}: #{obj.inspect}" unless obj.responds_to?(:to_h)
      pretty_json(obj.to_h, child_depth: child_depth, indent: indent)
    end
  end
end
