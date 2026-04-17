module Proto
  module Wire
    # Writer wraps an IO and provides typed protobuf wire-format write primitives.
    #
    # Typical message encode pattern:
    #   writer.write_tag(1, WireType::VARINT)
    #   writer.write_int32(value)
    #
    # For embedded messages use write_embedded which buffers the sub-message,
    # then writes the length prefix followed by the bytes.
    struct Writer
      def initialize(@io : IO)
      end

      # ---------------------------------------------------------------------------
      # Tag
      # ---------------------------------------------------------------------------

      def write_tag(field_number : Int32, wire_type : Int32) : Nil
        validate_field_number!(field_number)
        validate_wire_type!(wire_type)
        write_varint(((field_number.to_u64 << 3) | wire_type.to_u64))
      end

      # ---------------------------------------------------------------------------
      # Varint scalars
      # ---------------------------------------------------------------------------

      # int32: sign-extends to 64 bits (negative values become 10-byte varints)
      def write_int32(value : Int32) : Nil
        write_varint(value.to_i64.to_u64!)
      end

      def write_int64(value : Int64) : Nil
        write_varint(value.to_u64!)
      end

      def write_uint32(value : UInt32) : Nil
        write_varint(value.to_u64)
      end

      def write_uint64(value : UInt64) : Nil
        write_varint(value)
      end

      # sint32 / sint64 use zigzag encoding
      def write_sint32(value : Int32) : Nil
        u = value.to_u32!
        mask = (value >> 31).to_u32!
        write_varint(((u << 1) ^ mask).to_u64)
      end

      def write_sint64(value : Int64) : Nil
        u = value.to_u64!
        mask = (value >> 63).to_u64!
        write_varint((u << 1) ^ mask)
      end

      def write_bool(value : Bool) : Nil
        write_varint(value ? 1_u64 : 0_u64)
      end

      # ---------------------------------------------------------------------------
      # Fixed-width scalars
      # ---------------------------------------------------------------------------

      def write_fixed32(value : UInt32) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      def write_sfixed32(value : Int32) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      def write_fixed64(value : UInt64) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      def write_sfixed64(value : Int64) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      def write_float(value : Float32) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      def write_double(value : Float64) : Nil
        @io.write_bytes(value, IO::ByteFormat::LittleEndian)
      end

      # ---------------------------------------------------------------------------
      # Length-delimited
      # ---------------------------------------------------------------------------

      def write_bytes(data : Bytes) : Nil
        write_varint(data.size.to_u64)
        @io.write(data)
      end

      def write_string(value : String) : Nil
        write_bytes(value.to_slice)
      end

      # Write a length-delimited field by buffering the block's output.
      # Yields the underlying IO::Memory; the accumulated bytes are length-prefixed and written.
      def write_embedded(field_number : Int32, & : IO ->) : Nil
        buf = IO::Memory.new
        yield buf
        data = buf.to_slice
        write_tag(field_number, WireType::LENGTH_DELIMITED)
        write_bytes(data)
      end

      # ---------------------------------------------------------------------------
      # Packed repeated helpers
      # ---------------------------------------------------------------------------

      # Write a packed repeated field using the block to write each element into the buffer.
      # Skips writing the field entirely if the array is empty.
      def write_packed(field_number : Int32, & : IO::Memory ->) : Nil
        buf = IO::Memory.new
        yield buf
        return if buf.size == 0
        write_tag(field_number, WireType::LENGTH_DELIMITED)
        write_bytes(buf.to_slice)
      end

      # ---------------------------------------------------------------------------
      # Convenience field writers (tag + value combined)
      # ---------------------------------------------------------------------------

      # Write a string field only if value is not empty.
      def write_string_field(field_number : Int32, value : String) : Nil
        return if value.empty?
        write_tag(field_number, WireType::LENGTH_DELIMITED)
        write_string(value)
      end

      # Write a bytes field only if value is not empty.
      def write_bytes_field(field_number : Int32, value : Bytes) : Nil
        return if value.empty?
        write_tag(field_number, WireType::LENGTH_DELIMITED)
        write_bytes(value)
      end

      # Write an int32 field only if value != 0.
      def write_int32_field(field_number : Int32, value : Int32) : Nil
        return if value == 0
        write_tag(field_number, WireType::VARINT)
        write_int32(value)
      end

      # Write a uint64 field only if value != 0.
      def write_uint64_field(field_number : Int32, value : UInt64) : Nil
        return if value == 0_u64
        write_tag(field_number, WireType::VARINT)
        write_uint64(value)
      end

      # Write a bool field only if value is true.
      def write_bool_field(field_number : Int32, value : Bool) : Nil
        return unless value
        write_tag(field_number, WireType::VARINT)
        write_bool(value)
      end

      # ---------------------------------------------------------------------------

      def write_varint(value : UInt64) : Nil
        loop do
          byte = (value & 0x7F).to_u8
          value >>= 7
          if value == 0
            @io.write_byte(byte)
            break
          else
            @io.write_byte(byte | 0x80_u8)
          end
        end
      end

      private def validate_field_number!(field_number : Int32) : Nil
        if field_number <= 0
          raise EncodeError.new("invalid field number: #{field_number}")
        end
        if field_number > 536_870_911
          raise EncodeError.new("field number out of range: #{field_number}")
        end
        if (19_000..19_999).includes?(field_number)
          raise EncodeError.new("reserved field number range: #{field_number}")
        end
      end

      private def validate_wire_type!(wire_type : Int32) : Nil
        unless WireType.valid?(wire_type)
          raise EncodeError.new("invalid wire type: #{wire_type}")
        end
      end
    end
  end
end
