module Proto
  module Wire
    # Reader wraps an IO and provides typed protobuf wire-format read primitives.
    #
    # Entry point for message decode loops is `read_tag`, which returns nil on
    # clean EOF (end of message) and raises DecodeError on malformed input.
    # All other read methods raise DecodeError on unexpected EOF.
    struct Reader
      def initialize(@io : IO)
      end

      # ---------------------------------------------------------------------------
      # Tag
      # ---------------------------------------------------------------------------

      # Read the next field tag.
      # Returns {field_number, wire_type}, or nil on clean EOF.
      def read_tag : {Int32, Int32}?
        v = read_varint? { return }
        wire_type = (v & 0x7_u64).to_i32
        field_number = (v >> 3).to_i32
        if field_number <= 0
          raise DecodeError.new("invalid field number: #{field_number}")
        end
        unless WireType.valid?(wire_type)
          raise DecodeError.new("invalid wire type: #{wire_type}")
        end
        {field_number, wire_type}
      end

      # ---------------------------------------------------------------------------
      # Varint scalars
      # ---------------------------------------------------------------------------

      # int32 / int64 use sign-extended varint
      def read_int32 : Int32
        read_varint.to_i32!
      end

      def read_int64 : Int64
        read_varint.to_i64!
      end

      # uint32 / uint64 use plain varint
      def read_uint32 : UInt32
        read_varint.to_u32!
      end

      def read_uint64 : UInt64
        read_varint
      end

      # sint32 / sint64 use zigzag encoding
      def read_sint32 : Int32
        v = read_varint.to_u32!
        ((v >> 1).to_i32 ^ -(v & 1_u32).to_i32)
      end

      def read_sint64 : Int64
        v = read_varint
        ((v >> 1).to_i64 ^ -(v & 1_u64).to_i64)
      end

      def read_bool : Bool
        read_varint != 0_u64
      end

      # ---------------------------------------------------------------------------
      # Fixed-width scalars
      # ---------------------------------------------------------------------------

      def read_fixed32 : UInt32
        @io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
      end

      def read_sfixed32 : Int32
        @io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      end

      def read_fixed64 : UInt64
        @io.read_bytes(UInt64, IO::ByteFormat::LittleEndian)
      end

      def read_sfixed64 : Int64
        @io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
      end

      def read_float : Float32
        @io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
      end

      def read_double : Float64
        @io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
      end

      # ---------------------------------------------------------------------------
      # Length-delimited
      # ---------------------------------------------------------------------------

      def read_bytes : Bytes
        len = read_varint.to_i32
        raise DecodeError.new("negative length: #{len}") if len < 0
        slice = Bytes.new(len)
        @io.read_fully(slice)
        slice
      end

      def read_string : String
        String.new(read_bytes)
      end

      # Return a scoped IO::Memory over the next length-delimited field.
      # The bytes are consumed from this reader immediately.
      def read_embedded : IO::Memory
        IO::Memory.new(read_bytes)
      end

      # ---------------------------------------------------------------------------
      # Packed repeated helpers
      # ---------------------------------------------------------------------------

      # Decode a packed repeated varint field into the given array.
      # Yields each decoded UInt64 raw value; callers convert as needed.
      def read_packed_varint(& : UInt64 ->) : Nil
        sub_io = read_embedded
        sub = Reader.new(sub_io)
        while sub_io.pos < sub_io.size
          yield sub.read_uint64
        end
      end

      # Decode a packed repeated fixed32 field.
      def read_packed_fixed32(& : UInt32 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated sfixed32 field.
      def read_packed_sfixed32(& : Int32 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated fixed64 field.
      def read_packed_fixed64(& : UInt64 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(UInt64, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated sfixed64 field.
      def read_packed_sfixed64(& : Int64 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated float field.
      def read_packed_float(& : Float32 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated double field.
      def read_packed_double(& : Float64 ->) : Nil
        sub_io = read_embedded
        while sub_io.pos < sub_io.size
          yield sub_io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
        end
      end

      # ---------------------------------------------------------------------------
      # Skip
      # ---------------------------------------------------------------------------

      # Skip one field value of the given wire type.
      # Handles groups recursively (deprecated but must be skippable).
      def skip_field(wire_type : Int32) : Nil
        case wire_type
        when WireType::VARINT
          read_varint
        when WireType::FIXED64
          @io.skip(8)
        when WireType::LENGTH_DELIMITED
          @io.skip(read_varint.to_i32)
        when WireType::START_GROUP
          loop do
            tag = read_tag || raise DecodeError.new("unexpected EOF inside group")
            _, wt = tag
            break if wt == WireType::END_GROUP
            skip_field(wt)
          end
        when WireType::END_GROUP
          # Caller already consumed the END_GROUP tag; nothing to skip.
        when WireType::FIXED32
          @io.skip(4)
        else
          raise DecodeError.new("unknown wire type: #{wire_type}")
        end
      end

      # ---------------------------------------------------------------------------
      # Private helpers
      # ---------------------------------------------------------------------------

      # Read a base-128 varint. Raises DecodeError on unexpected EOF or overflow.
      # Pass a block to handle clean EOF on the *first* byte (e.g., for read_tag).
      private def read_varint?(&) : UInt64
        result = 0_u64
        shift = 0
        first = true
        loop do
          byte = @io.read_byte
          if byte.nil?
            if first
              yield
              raise DecodeError.new("unexpected EOF")
            else
              raise DecodeError.new("unexpected EOF in varint")
            end
          end
          first = false
          b = byte.to_u64
          result |= (b & 0x7F) << shift
          shift += 7
          return result if (b & 0x80) == 0
          raise DecodeError.new("varint overflow") if shift >= 64
        end
      end

      private def read_varint : UInt64
        read_varint? { raise DecodeError.new("unexpected EOF") }
      end
    end
  end
end
