module Proto
  module WireType
    VARINT           = 0
    FIXED64          = 1
    LENGTH_DELIMITED = 2
    START_GROUP      = 3 # deprecated in proto3
    END_GROUP        = 4 # deprecated in proto3
    FIXED32          = 5

    VALID_VALUES = {
      VARINT,
      FIXED64,
      LENGTH_DELIMITED,
      START_GROUP,
      END_GROUP,
      FIXED32,
    }

    def self.valid?(wire_type : Int32) : Bool
      VALID_VALUES.includes?(wire_type)
    end

    def self.name(wire_type : Int32) : String
      case wire_type
      when VARINT
        "Proto::WireType::VARINT"
      when FIXED64
        "Proto::WireType::FIXED64"
      when LENGTH_DELIMITED
        "Proto::WireType::LENGTH_DELIMITED"
      when START_GROUP
        "Proto::WireType::START_GROUP"
      when END_GROUP
        "Proto::WireType::END_GROUP"
      when FIXED32
        "Proto::WireType::FIXED32"
      else
        wire_type.to_s
      end
    end
  end
end
