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
  end
end
