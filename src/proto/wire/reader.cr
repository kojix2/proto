module Proto
  module Wire
    # Reader copies share the byte counter for their shared IO.
    private class ReadBudget
      property bytes_read = 0_i64
    end

    # Preserve nesting policy when generated/bootstrap decoders open child IOs.
    class EmbeddedIO < IO::Memory
      getter depth : Int32
      getter max_recursion_depth : Int32
      getter max_message_size : Int64
      getter max_field_length : Int32

      def initialize(bytes : Bytes, @depth : Int32, @max_recursion_depth : Int32,
                     @max_message_size : Int64 = 64_i64 * 1024 * 1024,
                     @max_field_length : Int32 = 8_i32 * 1024 * 1024)
        super(bytes)
      end

      def rewrap(bytes : Bytes) : self
        self.class.new(bytes, depth, max_recursion_depth, max_message_size, max_field_length)
      end
    end

    # Reader wraps an IO and provides typed protobuf wire-format read primitives.
    #
    # Entry point for message decode loops is `read_tag`, which returns nil on
    # clean EOF (end of message) and raises DecodeError on malformed input.
    # All other read methods raise DecodeError on unexpected EOF.
    struct Reader
      MAX_FIELD_NUMBER            = 536_870_911
      DEFAULT_MAX_MESSAGE_SIZE    = 64_i64 * 1024 * 1024
      DEFAULT_MAX_FIELD_LENGTH    = 8_i32 * 1024 * 1024
      DEFAULT_MAX_RECURSION_DEPTH = 100

      @budget : ReadBudget
      @depth : Int32
      @max_recursion_depth : Int32

      def initialize(
        @io : IO,
        @max_message_size : Int64 = DEFAULT_MAX_MESSAGE_SIZE,
        @max_field_length : Int32 = DEFAULT_MAX_FIELD_LENGTH,
        max_recursion_depth : Int32 = DEFAULT_MAX_RECURSION_DEPTH,
      )
        @budget = ReadBudget.new
        @depth = io.is_a?(EmbeddedIO) ? io.depth : 0
        @max_recursion_depth = io.is_a?(EmbeddedIO) ? io.max_recursion_depth : max_recursion_depth
        @max_message_size = io.max_message_size if io.is_a?(EmbeddedIO)
        @max_field_length = io.max_field_length if io.is_a?(EmbeddedIO)
        raise ArgumentError.new("max_recursion_depth must be nonnegative") if @max_recursion_depth < 0
        check_depth!
      end

      # ---------------------------------------------------------------------------
      # Tag
      # ---------------------------------------------------------------------------

      def expect_wire_type!(field_number : Int32, wire_type : Int32, expected_wire_type : Int32) : Nil
        return if wire_type == expected_wire_type
        raise_wire_type_mismatch(field_number, wire_type, WireType.name(expected_wire_type))
      end

      def expect_wire_type!(field_number : Int32, wire_type : Int32, expected_wire_type : Int32, alternate_wire_type : Int32) : Nil
        return if wire_type == expected_wire_type || wire_type == alternate_wire_type
        expected = "#{WireType.name(expected_wire_type)} or #{WireType.name(alternate_wire_type)}"
        raise_wire_type_mismatch(field_number, wire_type, expected)
      end

      def packed_wire_type?(field_number : Int32, wire_type : Int32, unpacked_wire_type : Int32) : Bool
        return true if wire_type == WireType::LENGTH_DELIMITED
        return false if wire_type == unpacked_wire_type
        expect_wire_type!(field_number, wire_type, WireType::LENGTH_DELIMITED, unpacked_wire_type)
        false
      end

      # Read the next field tag.
      # Returns {field_number, wire_type}, or nil on clean EOF.
      def read_tag : {Int32, Int32}?
        v = read_varint? { return }
        wire_type = (v & 0x7_u64).to_i32
        raw_field_number = v >> 3
        if raw_field_number == 0
          raise DecodeError.new("invalid field number: 0")
        end
        if raw_field_number > MAX_FIELD_NUMBER.to_u64
          raise DecodeError.new("field number out of range: #{raw_field_number}")
        end
        field_number = raw_field_number.to_i32
        unless WireType.valid?(wire_type)
          raise DecodeError.new("invalid wire type: #{wire_type}")
        end
        {field_number, wire_type}
      rescue OverflowError
        raise DecodeError.new("field number out of range")
      end

      # ---------------------------------------------------------------------------
      # Varint scalars
      # ---------------------------------------------------------------------------

      # int32 / int64 use sign-extended varint
      def read_int32 : Int32
        self.class.int32_from_varint(read_varint)
      end

      def read_int64 : Int64
        read_varint.unsafe_as(Int64)
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
        value = @io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        consume_bytes!(4)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_sfixed32 : Int32
        value = @io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        consume_bytes!(4)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_fixed64 : UInt64
        value = @io.read_bytes(UInt64, IO::ByteFormat::LittleEndian)
        consume_bytes!(8)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_sfixed64 : Int64
        value = @io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
        consume_bytes!(8)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_float : Float32
        value = @io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
        consume_bytes!(4)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_double : Float64
        value = @io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
        consume_bytes!(8)
        value
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      # ---------------------------------------------------------------------------
      # Length-delimited
      # ---------------------------------------------------------------------------

      def read_bytes : Bytes
        len = read_length
        slice = Bytes.new(len)
        @io.read_fully(slice)
        consume_bytes!(len.to_i64)
        slice
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      def read_string : String
        value = read_string_unchecked
        raise DecodeError.new("invalid UTF-8 string") unless value.valid_encoding?
        value
      end

      def read_string_unchecked : String
        String.new(read_bytes)
      end

      # Return a scoped IO::Memory over the next length-delimited field.
      # The bytes are consumed from this reader immediately.
      def read_embedded : EmbeddedIO
        raise DecodeLimitError.new("message exceeds recursion limit") if @depth >= @max_recursion_depth
        EmbeddedIO.new(read_bytes, @depth + 1, @max_recursion_depth, @max_message_size, @max_field_length)
      end

      def read_embedded(field_number : Int32, wire_type : Int32, & : EmbeddedIO -> T) : T forall T
        expect_wire_type!(field_number, wire_type, WireType::LENGTH_DELIMITED)
        yield read_embedded
      end

      # ---------------------------------------------------------------------------
      # Packed repeated helpers
      # ---------------------------------------------------------------------------

      # Decode a packed repeated varint field into the given array.
      # Yields each decoded UInt64 raw value; callers convert as needed.
      def read_packed_varint(& : UInt64 ->) : Nil
        sub_io = IO::Memory.new(read_bytes)
        sub = Reader.new(sub_io, max_message_size: @max_message_size,
          max_field_length: @max_field_length, max_recursion_depth: @max_recursion_depth)
        while sub_io.pos < sub_io.size
          yield sub.read_uint64
        end
      end

      # Decode a packed repeated fixed32 field.
      def read_packed_fixed32(& : UInt32 ->) : Nil
        read_packed_fixed_values(4) do |sub_io|
          yield sub_io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated sfixed32 field.
      def read_packed_sfixed32(& : Int32 ->) : Nil
        read_packed_fixed_values(4) do |sub_io|
          yield sub_io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated fixed64 field.
      def read_packed_fixed64(& : UInt64 ->) : Nil
        read_packed_fixed_values(8) do |sub_io|
          yield sub_io.read_bytes(UInt64, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated sfixed64 field.
      def read_packed_sfixed64(& : Int64 ->) : Nil
        read_packed_fixed_values(8) do |sub_io|
          yield sub_io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated float field.
      def read_packed_float(& : Float32 ->) : Nil
        read_packed_fixed_values(4) do |sub_io|
          yield sub_io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
        end
      end

      # Decode a packed repeated double field.
      def read_packed_double(& : Float64 ->) : Nil
        read_packed_fixed_values(8) do |sub_io|
          yield sub_io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
        end
      end

      # ---------------------------------------------------------------------------
      # Skip
      # ---------------------------------------------------------------------------

      # Skip one untagged field value of the given wire type.
      def skip_field(wire_type : Int32) : Nil
        skip_field_value(nil, wire_type)
      end

      # Skip one tagged field value with strict START_GROUP/END_GROUP matching.
      def skip_tag(tag : {Int32, Int32}) : Nil
        field_number, wire_type = tag
        skip_field_value(field_number, wire_type)
      end

      def read_unknown_field(field_number : Int32, wire_type : Int32) : UnknownField
        case wire_type
        when WireType::VARINT
          UnknownField.new(field_number, WireType::VARINT, read_uint64)
        when WireType::FIXED64
          UnknownField.new(field_number, WireType::FIXED64, read_fixed64)
        when WireType::LENGTH_DELIMITED
          UnknownField.new(field_number, WireType::LENGTH_DELIMITED, read_bytes)
        when WireType::FIXED32
          UnknownField.new(field_number, WireType::FIXED32, read_fixed32)
        when WireType::START_GROUP
          fields = read_unknown_group(field_number)
          UnknownField.new(field_number, WireType::START_GROUP, fields)
        when WireType::END_GROUP
          raise DecodeError.new("unexpected END_GROUP")
        else
          skip_tag({field_number, wire_type})
          raise DecodeError.new("unknown wire type: #{wire_type}")
        end
      end

      private def skip_field_value(field_number : Int32?, wire_type : Int32) : Nil
        case wire_type
        when WireType::VARINT
          read_varint
        when WireType::FIXED64
          @io.skip(8)
          consume_bytes!(8)
        when WireType::LENGTH_DELIMITED
          len = read_length
          @io.skip(len)
          consume_bytes!(len.to_i64)
        when WireType::START_GROUP
          start_field_number = field_number || raise DecodeError.new("START_GROUP requires field number")
          skip_group(start_field_number)
        when WireType::END_GROUP
          # Caller already consumed the END_GROUP tag; nothing to skip.
        when WireType::FIXED32
          @io.skip(4)
          consume_bytes!(4)
        else
          raise DecodeError.new("unknown wire type: #{wire_type}")
        end
      rescue IO::EOFError
        raise DecodeError.new("unexpected EOF")
      end

      # ---------------------------------------------------------------------------
      # Private helpers
      # ---------------------------------------------------------------------------

      # Read a base-128 varint. Raises DecodeError on unexpected EOF or overflow.
      # Pass a block to handle clean EOF on the *first* byte (e.g., for read_tag).
      private def read_varint?(&) : UInt64
        result = 0_u64
        first = true
        10.times do |index|
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
          consume_bytes!(1)
          b = byte.to_u64
          # A UInt64 varint may use ten bytes, but byte ten contains only the
          # 64th payload bit and must terminate the value.
          if index == 9 && (b & 0xFE) != 0
            raise DecodeError.new("varint overflow")
          end
          result |= (b & 0x7F) << (index * 7)
          return result if (b & 0x80) == 0
        end
        raise DecodeError.new("varint overflow")
      end

      private def read_varint : UInt64
        read_varint? { raise DecodeError.new("unexpected EOF") }
      end

      private def read_length : Int32
        len_u64 = read_varint
        if len_u64 > Int32::MAX.to_u64
          raise DecodeError.new("length out of range: #{len_u64}")
        end
        len = len_u64.to_i32
        if len > @max_field_length
          raise DecodeLimitError.new("field length exceeds limit: #{len} > #{@max_field_length}")
        end
        # Reject before allocating, reading or skipping the payload. The length
        # varint has already been charged to this reader's message budget.
        if @budget.bytes_read + len > @max_message_size
          raise DecodeLimitError.new("message exceeds max size: #{@budget.bytes_read + len} > #{@max_message_size}")
        end
        len
      end

      private def consume_bytes!(count : Int64) : Nil
        @budget.bytes_read += count
        if @budget.bytes_read > @max_message_size
          raise DecodeLimitError.new("message exceeds max size: #{@budget.bytes_read} > #{@max_message_size}")
        end
      end

      private def read_packed_fixed_values(byte_size : Int32, & : IO::Memory ->) : Nil
        sub_io = IO::Memory.new(read_bytes)
        while sub_io.pos < sub_io.size
          remaining = sub_io.size - sub_io.pos
          raise DecodeError.new("unexpected EOF") if remaining < byte_size
          yield sub_io
        end
      end

      private def read_unknown_group(start_field_number : Int32) : Array(UnknownField)
        @depth += 1
        check_depth!
        fields = [] of UnknownField
        loop do
          tag = read_tag || raise DecodeError.new("unexpected EOF inside group")
          fn, wt = tag
          if wt == WireType::END_GROUP
            raise DecodeError.new("mismatched END_GROUP") if fn != start_field_number
            break
          end
          fields << read_unknown_field(fn, wt)
        end
        fields
      ensure
        @depth -= 1
      end

      private def skip_group(start_field_number : Int32) : Nil
        @depth += 1
        check_depth!
        loop do
          tag = read_tag || raise DecodeError.new("unexpected EOF inside group")
          fn, wt = tag
          if wt == WireType::END_GROUP
            raise DecodeError.new("mismatched END_GROUP") if fn != start_field_number
            break
          end
          skip_tag({fn, wt})
        end
      ensure
        @depth -= 1
      end

      def self.int32_from_varint(raw : UInt64) : Int32
        raw.to_u32!.unsafe_as(Int32)
      end

      private def check_depth! : Nil
        raise DecodeLimitError.new("message exceeds recursion limit") if @depth > @max_recursion_depth
      end

      private def raise_wire_type_mismatch(field_number : Int32, wire_type : Int32, expected : String) : NoReturn
        raise DecodeError.new("wire type mismatch for field #{field_number}: expected #{expected}, got #{wire_type}")
      end
    end
  end
end
