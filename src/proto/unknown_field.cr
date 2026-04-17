module Proto
  # Holds one unknown field captured during message decoding.
  # Preserves wire_type so the field can be faithfully re-encoded.
  struct UnknownField
    getter field_number : Int32
    getter wire_type : Int32
    getter data : Bytes | UInt64 | UInt32

    def initialize(@field_number : Int32, @wire_type : Int32, @data : Bytes | UInt64 | UInt32)
    end
  end

  # Mixin that adds unknown field capture and re-serialization to a message class.
  #
  # Include this module inside any class that inherits Proto::Message to get:
  #   capture_unknown_field(reader, field_number, wire_type)
  #   write_unknown_fields(writer)
  module HasUnknownFields
    getter unknown_fields : Array(UnknownField) = [] of UnknownField

    # Append a raw unknown varint value when a field cannot be decoded semantically
    # (for example, unknown enum numeric values under strict enum APIs).
    def add_unknown_varint(field_number : Int32, value : UInt64) : Nil
      @unknown_fields << UnknownField.new(field_number, WireType::VARINT, value)
    end

    def capture_unknown_field(reader : Wire::Reader, field_number : Int32, wire_type : Int32) : Nil
      case wire_type
      when WireType::VARINT
        v = reader.read_uint64
        @unknown_fields << UnknownField.new(field_number, WireType::VARINT, v)
      when WireType::FIXED64
        v = reader.read_fixed64
        @unknown_fields << UnknownField.new(field_number, WireType::FIXED64, v)
      when WireType::LENGTH_DELIMITED
        b = reader.read_bytes
        @unknown_fields << UnknownField.new(field_number, WireType::LENGTH_DELIMITED, b)
      when WireType::FIXED32
        v = reader.read_fixed32
        @unknown_fields << UnknownField.new(field_number, WireType::FIXED32, v)
      else
        reader.skip_field(wire_type)
      end
    end

    def write_unknown_fields(writer : Wire::Writer) : Nil
      @unknown_fields.each do |unknown_field|
        writer.write_tag(unknown_field.field_number, unknown_field.wire_type)
        case d = unknown_field.data
        when UInt64
          if unknown_field.wire_type == WireType::FIXED64
            writer.write_fixed64(d)
          else
            writer.write_varint(d)
          end
        when UInt32
          writer.write_fixed32(d)
        when Bytes
          writer.write_bytes(d)
        end
      end
    end
  end
end
