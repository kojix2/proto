module Proto
  alias ExtensionValue = Bool | Int32 | Int64 | UInt32 | UInt64 | Float32 | Float64 | String | Bytes
  alias UnknownFieldData = Bytes | UInt64 | UInt32 | Array(UnknownField)

  # Holds one unknown field captured during message decoding.
  # Preserves wire_type so the field can be faithfully re-encoded.
  struct UnknownField
    getter field_number : Int32
    getter wire_type : Int32
    getter data : UnknownFieldData

    def initialize(@field_number : Int32, @wire_type : Int32, @data : UnknownFieldData)
    end
  end

  # Mixin that adds unknown field capture and re-serialization to a message class.
  #
  # Include this module inside any class that inherits Proto::Message to get:
  #   capture_unknown_field(reader, field_number, wire_type)
  #   write_unknown_fields(writer)
  module HasUnknownFields
    getter unknown_fields : Array(UnknownField) = [] of UnknownField

    # Returns true when at least one unknown field matches the descriptor and can
    # be decoded as an extension value.
    def has_extension?(descriptor : T) : Bool forall T
      !extension_values(descriptor).empty?
    end

    # Returns the last matching extension value (proto singular semantics) or nil.
    def extension_value?(descriptor : T) : ExtensionValue? forall T
      extension_values(descriptor).last?
    end

    # Returns all matching extension values in wire order.
    def extension_values(descriptor : T) : Array(ExtensionValue) forall T
      expected_wire_type = extension_wire_type_for(descriptor.type)
      return [] of ExtensionValue unless expected_wire_type

      values = [] of ExtensionValue
      unknown_fields.each do |unknown_field|
        next unless unknown_field.field_number == descriptor.number
        next unless unknown_field.wire_type == expected_wire_type

        value = decode_extension_value(unknown_field, descriptor.type)
        values << value unless value.nil?
      end

      values
    end

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
      when WireType::START_GROUP
        nested = capture_unknown_group(reader)
        @unknown_fields << UnknownField.new(field_number, WireType::START_GROUP, nested)
      when WireType::END_GROUP
        raise DecodeError.new("unexpected END_GROUP")
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
        when Array(UnknownField)
          write_unknown_group_fields(writer, d)
          writer.write_tag(unknown_field.field_number, WireType::END_GROUP)
        end
      end
    end

    private def capture_unknown_group(reader : Wire::Reader) : Array(UnknownField)
      fields = [] of UnknownField
      while tag = reader.read_tag
        fn, wt = tag
        break if wt == WireType::END_GROUP
        capture_unknown_field_into(fields, reader, fn, wt)
      end
      fields
    end

    private def capture_unknown_field_into(fields : Array(UnknownField), reader : Wire::Reader, field_number : Int32, wire_type : Int32) : Nil
      case wire_type
      when WireType::VARINT
        fields << UnknownField.new(field_number, WireType::VARINT, reader.read_uint64)
      when WireType::FIXED64
        fields << UnknownField.new(field_number, WireType::FIXED64, reader.read_fixed64)
      when WireType::LENGTH_DELIMITED
        fields << UnknownField.new(field_number, WireType::LENGTH_DELIMITED, reader.read_bytes)
      when WireType::FIXED32
        fields << UnknownField.new(field_number, WireType::FIXED32, reader.read_fixed32)
      when WireType::START_GROUP
        fields << UnknownField.new(field_number, WireType::START_GROUP, capture_unknown_group(reader))
      when WireType::END_GROUP
        raise DecodeError.new("unexpected END_GROUP")
      else
        reader.skip_field(wire_type)
      end
    end

    private def write_unknown_group_fields(writer : Wire::Writer, fields : Array(UnknownField)) : Nil
      fields.each do |field|
        writer.write_tag(field.field_number, field.wire_type)
        case d = field.data
        when UInt64
          if field.wire_type == WireType::FIXED64
            writer.write_fixed64(d)
          else
            writer.write_varint(d)
          end
        when UInt32
          writer.write_fixed32(d)
        when Bytes
          writer.write_bytes(d)
        when Array(UnknownField)
          write_unknown_group_fields(writer, d)
          writer.write_tag(field.field_number, WireType::END_GROUP)
        end
      end
    end

    private def extension_wire_type_for(field_type : Bootstrap::FieldType) : Int32?
      case field_type
      when Bootstrap::FieldType::TYPE_DOUBLE,
           Bootstrap::FieldType::TYPE_FIXED64,
           Bootstrap::FieldType::TYPE_SFIXED64
        WireType::FIXED64
      when Bootstrap::FieldType::TYPE_FLOAT,
           Bootstrap::FieldType::TYPE_FIXED32,
           Bootstrap::FieldType::TYPE_SFIXED32
        WireType::FIXED32
      when Bootstrap::FieldType::TYPE_STRING,
           Bootstrap::FieldType::TYPE_BYTES,
           Bootstrap::FieldType::TYPE_MESSAGE
        WireType::LENGTH_DELIMITED
      when Bootstrap::FieldType::TYPE_GROUP
        nil
      else
        WireType::VARINT
      end
    end

    private def decode_extension_value(field : UnknownField, field_type : Bootstrap::FieldType) : ExtensionValue?
      case field.wire_type
      when WireType::VARINT
        decode_varint_extension(field, field_type)
      when WireType::FIXED64
        decode_fixed64_extension(field, field_type)
      when WireType::FIXED32
        decode_fixed32_extension(field, field_type)
      when WireType::LENGTH_DELIMITED
        decode_length_delimited_extension(field, field_type)
      end
    rescue OverflowError
      nil
    rescue ArgumentError
      nil
    end

    private def decode_varint_extension(field : UnknownField, field_type : Bootstrap::FieldType) : ExtensionValue?
      case field_type
      when Bootstrap::FieldType::TYPE_BOOL
        decode_varint(field) { |value| value != 0_u64 }
      when Bootstrap::FieldType::TYPE_INT32
        decode_varint(field, &.to_i32!)
      when Bootstrap::FieldType::TYPE_INT64
        decode_varint(field, &.to_i64!)
      when Bootstrap::FieldType::TYPE_UINT32
        decode_varint(field, &.to_u32!)
      when Bootstrap::FieldType::TYPE_UINT64
        decode_varint(field) { |value| value }
      when Bootstrap::FieldType::TYPE_SINT32
        decode_varint(field) do |value|
          zigzag = value.to_u32!
          ((zigzag >> 1).to_i32 ^ -(zigzag & 1_u32).to_i32)
        end
      when Bootstrap::FieldType::TYPE_SINT64
        decode_varint(field) { |value| ((value >> 1).to_i64 ^ -(value & 1_u64).to_i64) }
      when Bootstrap::FieldType::TYPE_ENUM
        decode_varint(field, &.to_i32!)
      end
    end

    private def decode_fixed64_extension(field : UnknownField, field_type : Bootstrap::FieldType) : ExtensionValue?
      case field_type
      when Bootstrap::FieldType::TYPE_FIXED64
        decode_fixed64(field) { |value| value }
      when Bootstrap::FieldType::TYPE_SFIXED64
        decode_fixed64(field, &.to_i64!)
      when Bootstrap::FieldType::TYPE_DOUBLE
        decode_fixed64(field) { |value| unpack_float64(value) }
      end
    end

    private def decode_fixed32_extension(field : UnknownField, field_type : Bootstrap::FieldType) : ExtensionValue?
      case field_type
      when Bootstrap::FieldType::TYPE_FIXED32
        decode_fixed32(field) { |value| value }
      when Bootstrap::FieldType::TYPE_SFIXED32
        decode_fixed32(field, &.to_i32!)
      when Bootstrap::FieldType::TYPE_FLOAT
        decode_fixed32(field) { |value| unpack_float32(value) }
      end
    end

    private def decode_length_delimited_extension(field : UnknownField, field_type : Bootstrap::FieldType) : ExtensionValue?
      case field_type
      when Bootstrap::FieldType::TYPE_STRING
        decode_bytes(field) { |value| String.new(value) }
      when Bootstrap::FieldType::TYPE_BYTES,
           Bootstrap::FieldType::TYPE_MESSAGE
        decode_bytes(field) { |value| value }
      end
    end

    private def decode_varint(field : UnknownField, & : UInt64 -> ExtensionValue) : ExtensionValue?
      return unless field.wire_type == WireType::VARINT
      data = field.data
      return unless data.is_a?(UInt64)
      yield data
    end

    private def decode_fixed64(field : UnknownField, & : UInt64 -> ExtensionValue) : ExtensionValue?
      return unless field.wire_type == WireType::FIXED64
      data = field.data
      return unless data.is_a?(UInt64)
      yield data
    end

    private def decode_fixed32(field : UnknownField, & : UInt32 -> ExtensionValue) : ExtensionValue?
      return unless field.wire_type == WireType::FIXED32
      data = field.data
      return unless data.is_a?(UInt32)
      yield data
    end

    private def decode_bytes(field : UnknownField, & : Bytes -> ExtensionValue) : ExtensionValue?
      return unless field.wire_type == WireType::LENGTH_DELIMITED
      data = field.data
      return unless data.is_a?(Bytes)
      yield data
    end

    private def unpack_float64(bits : UInt64) : Float64
      io = IO::Memory.new
      io.write_bytes(bits, IO::ByteFormat::LittleEndian)
      io.rewind
      io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
    end

    private def unpack_float32(bits : UInt32) : Float32
      io = IO::Memory.new
      io.write_bytes(bits, IO::ByteFormat::LittleEndian)
      io.rewind
      io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
    end
  end
end
