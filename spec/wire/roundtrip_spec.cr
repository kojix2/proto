require "../spec_helper"

# Helpers
def encode_varint(value : UInt64) : Bytes
  io = IO::Memory.new
  Proto::Wire::Writer.new(io).write_varint(value)
  io.to_slice
end

def decode_varint(bytes : Bytes) : UInt64
  Proto::Wire::Reader.new(IO::Memory.new(bytes)).read_uint64
end

def roundtrip_varint(value : UInt64) : UInt64
  decode_varint(encode_varint(value))
end

describe "Proto::Wire::Reader / Writer" do
  describe "varint" do
    it "encodes 0 as single zero byte" do
      encode_varint(0_u64).should eq Bytes[0]
    end

    it "encodes 1 as single byte 0x01" do
      encode_varint(1_u64).should eq Bytes[0x01]
    end

    it "encodes 127 as single byte 0x7F" do
      encode_varint(127_u64).should eq Bytes[0x7F]
    end

    it "encodes 128 as two bytes 0x80 0x01" do
      encode_varint(128_u64).should eq Bytes[0x80, 0x01]
    end

    it "encodes 300 correctly" do
      encode_varint(300_u64).should eq Bytes[0xAC, 0x02]
    end

    it "round-trips 0" do
      roundtrip_varint(0_u64).should eq 0_u64
    end

    it "round-trips 1" do
      roundtrip_varint(1_u64).should eq 1_u64
    end

    it "round-trips 127" do
      roundtrip_varint(127_u64).should eq 127_u64
    end

    it "round-trips 128" do
      roundtrip_varint(128_u64).should eq 128_u64
    end

    it "round-trips 2^32" do
      roundtrip_varint(4294967296_u64).should eq 4294967296_u64
    end

    it "round-trips UInt64::MAX" do
      roundtrip_varint(UInt64::MAX).should eq UInt64::MAX
    end

    it "raises on varint overflow" do
      bytes = Bytes[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01]
      reader = Proto::Wire::Reader.new(IO::Memory.new(bytes))
      expect_raises(Proto::DecodeError, /varint overflow/) do
        reader.read_uint64
      end
    end

    it "raises on truncated varint" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x80]))
      expect_raises(Proto::DecodeError, /unexpected EOF in varint/) do
        reader.read_uint64
      end
    end
  end

  describe "int32 (sign-extended varint)" do
    it "round-trips 0" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_int32(0_i32)
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq 0_i32
    end

    it "round-trips 1" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_int32(1_i32)
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq 1_i32
    end

    it "round-trips -1 (10-byte varint)" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_int32(-1_i32)
      # -1 must encode as 10 bytes (sign-extended to 64 bits)
      io.size.should eq 10
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq -1_i32
    end

    it "round-trips Int32::MIN" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_int32(Int32::MIN)
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq Int32::MIN
    end

    it "round-trips Int32::MAX" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_int32(Int32::MAX)
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq Int32::MAX
    end
  end

  describe "sint32 (zigzag)" do
    {
               0 => 0_u64,
              -1 => 1_u64,
               1 => 2_u64,
              -2 => 3_u64,
      Int32::MAX => 4294967294_u64,
      Int32::MIN => 4294967295_u64,
    }.each do |value, expected_encoded|
      it "encodes #{value} as #{expected_encoded}" do
        io = IO::Memory.new
        Proto::Wire::Writer.new(io).write_sint32(value.to_i32)
        io.rewind
        Proto::Wire::Reader.new(io).read_uint64.should eq expected_encoded
      end
    end

    [-2147483648, -1, 0, 1, 2147483647].each do |value|
      it "round-trips #{value}" do
        io = IO::Memory.new
        Proto::Wire::Writer.new(io).write_sint32(value.to_i32)
        io.rewind
        Proto::Wire::Reader.new(io).read_sint32.should eq value.to_i32
      end
    end
  end

  describe "sint64 (zigzag)" do
    [
      -9223372036854775808_i64,
      -1_i64,
      0_i64,
      1_i64,
      9223372036854775807_i64,
    ].each do |value|
      it "round-trips #{value}" do
        io = IO::Memory.new
        Proto::Wire::Writer.new(io).write_sint64(value)
        io.rewind
        Proto::Wire::Reader.new(io).read_sint64.should eq value
      end
    end
  end

  describe "bool" do
    it "encodes true as 1" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(true)
      io.to_slice.should eq Bytes[1]
    end

    it "encodes false as 0" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(false)
      io.to_slice.should eq Bytes[0]
    end

    it "round-trips true" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(true)
      io.rewind
      Proto::Wire::Reader.new(io).read_bool.should be_true
    end

    it "round-trips false" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(false)
      io.rewind
      Proto::Wire::Reader.new(io).read_bool.should be_false
    end
  end

  describe "fixed32 / sfixed32" do
    it "round-trips fixed32 0" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed32(0_u32)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed32.should eq 0_u32
    end

    it "round-trips fixed32 UInt32::MAX" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed32(UInt32::MAX)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed32.should eq UInt32::MAX
    end

    it "round-trips sfixed32 -1" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed32(-1_i32)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed32.should eq -1_i32
    end

    it "round-trips sfixed32 Int32::MIN" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed32(Int32::MIN)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed32.should eq Int32::MIN
    end

    it "raises on truncated fixed32" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0xAA, 0xBB, 0xCC]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_fixed32
      end
    end
  end

  describe "fixed64 / sfixed64" do
    it "round-trips fixed64 UInt64::MAX" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed64(UInt64::MAX)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed64.should eq UInt64::MAX
    end

    it "round-trips sfixed64 Int64::MIN" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed64(Int64::MIN)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed64.should eq Int64::MIN
    end

    it "raises on truncated fixed64" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x01, 0x02, 0x03, 0x04, 0x05]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_fixed64
      end
    end
  end

  describe "float / double" do
    it "round-trips float 3.14" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_float(3.14_f32)
      io.rewind
      Proto::Wire::Reader.new(io).read_float.should be_close(3.14_f32, 1e-6_f32)
    end

    it "round-trips double 3.141592653589793" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_double(3.141592653589793_f64)
      io.rewind
      Proto::Wire::Reader.new(io).read_double.should be_close(3.141592653589793_f64, 1e-15_f64)
    end
  end

  describe "bytes / string" do
    it "round-trips empty bytes" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bytes(Bytes.empty)
      io.rewind
      Proto::Wire::Reader.new(io).read_bytes.should eq Bytes.empty
    end

    it "round-trips bytes" do
      data = Bytes[0x00, 0xFF, 0x42, 0x7F]
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bytes(data)
      io.rewind
      Proto::Wire::Reader.new(io).read_bytes.should eq data
    end

    it "round-trips empty string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq ""
    end

    it "round-trips ASCII string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("hello world")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq "hello world"
    end

    it "round-trips UTF-8 string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("こんにちは")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq "こんにちは"
    end

    it "raises on truncated length-delimited payload" do
      # length prefix says 5 bytes, but only 2 bytes follow.
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x05, 0x41, 0x42]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_string
      end
    end
  end

  describe "read_tag" do
    it "returns nil on clean EOF" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes.empty))
      reader.read_tag.should be_nil
    end

    it "decodes field_number=1 wire_type=0" do
      # tag = (1 << 3) | 0 = 8 = 0x08
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x08]))
      tag = reader.read_tag
      tag.should_not be_nil
      field_number, wire_type = tag.as({Int32, Int32})
      field_number.should eq 1 # field_number
      wire_type.should eq 0    # wire_type VARINT
    end

    it "decodes field_number=2 wire_type=2" do
      # tag = (2 << 3) | 2 = 18 = 0x12
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x12]))
      tag = reader.read_tag
      tag.should_not be_nil
      field_number, wire_type = tag.as({Int32, Int32})
      field_number.should eq 2
      wire_type.should eq 2 # wire_type LENGTH_DELIMITED
    end

    it "raises for field_number=0" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x00]))
      expect_raises(Proto::DecodeError, /invalid field number/) do
        reader.read_tag
      end
    end

    it "raises for invalid wire_type" do
      # tag = (1 << 3) | 7 = 0x0F (wire type 7 is invalid)
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x0F]))
      expect_raises(Proto::DecodeError, /invalid wire type/) do
        reader.read_tag
      end
    end

    it "raises for field number out of range" do
      # tag = (536_870_912 << 3) | 0
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x80, 0x80, 0x80, 0x80, 0x10]))
      expect_raises(Proto::DecodeError, /field number out of range/) do
        reader.read_tag
      end
    end
  end

  describe "write_tag" do
    it "encodes field_number=1 wire_type=0 as 0x08" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_tag(1, Proto::WireType::VARINT)
      io.to_slice.should eq Bytes[0x08]
    end

    it "encodes field_number=2 wire_type=2 as 0x12" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_tag(2, Proto::WireType::LENGTH_DELIMITED)
      io.to_slice.should eq Bytes[0x12]
    end

    it "raises for field_number=0" do
      io = IO::Memory.new
      expect_raises(Proto::EncodeError, /invalid field number/) do
        Proto::Wire::Writer.new(io).write_tag(0, Proto::WireType::VARINT)
      end
    end

    it "raises for reserved field numbers" do
      io = IO::Memory.new
      expect_raises(Proto::EncodeError, /reserved field number range/) do
        Proto::Wire::Writer.new(io).write_tag(19_000, Proto::WireType::VARINT)
      end
    end

    it "raises for field number out of range" do
      io = IO::Memory.new
      expect_raises(Proto::EncodeError, /field number out of range/) do
        Proto::Wire::Writer.new(io).write_tag(536_870_912, Proto::WireType::VARINT)
      end
    end

    it "raises for invalid wire_type" do
      io = IO::Memory.new
      expect_raises(Proto::EncodeError, /invalid wire type/) do
        Proto::Wire::Writer.new(io).write_tag(1, 7)
      end
    end
  end

  describe "skip_field" do
    it "skips a varint field" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_int32(42)
      Proto::Wire::Writer.new(io).write_int32(99)
      io.rewind
      reader = Proto::Wire::Reader.new(io)
      reader.skip_field(Proto::WireType::VARINT)
      reader.read_int32.should eq 99
    end

    it "skips a fixed32 field" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed32(0xDEADBEEF_u32)
      Proto::Wire::Writer.new(io).write_uint32(7_u32)
      io.rewind
      reader = Proto::Wire::Reader.new(io)
      reader.skip_field(Proto::WireType::FIXED32)
      reader.read_uint32.should eq 7_u32
    end

    it "skips a fixed64 field" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed64(0xDEADBEEFCAFEBABE_u64)
      Proto::Wire::Writer.new(io).write_uint64(123_u64)
      io.rewind
      reader = Proto::Wire::Reader.new(io)
      reader.skip_field(Proto::WireType::FIXED64)
      reader.read_uint64.should eq 123_u64
    end

    it "skips a length-delimited field" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("skip me")
      Proto::Wire::Writer.new(io).write_int32(55)
      io.rewind
      reader = Proto::Wire::Reader.new(io)
      reader.skip_field(Proto::WireType::LENGTH_DELIMITED)
      reader.read_int32.should eq 55
    end

    it "enforces max_message_size while skipping length-delimited fields" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("abc")
      io.rewind

      reader = Proto::Wire::Reader.new(io, max_message_size: 3)
      expect_raises(Proto::DecodeError, /message exceeds max size/) do
        reader.skip_field(Proto::WireType::LENGTH_DELIMITED)
      end
    end

    it "enforces max_message_size while skipping fixed32 fields" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_fixed32(0xDEADBEEF_u32)
      writer.write_fixed32(0xCAFEBABE_u32)
      io.rewind

      reader = Proto::Wire::Reader.new(io, max_message_size: 7)
      reader.skip_field(Proto::WireType::FIXED32)
      expect_raises(Proto::DecodeError, /message exceeds max size/) do
        reader.skip_field(Proto::WireType::FIXED32)
      end
    end

    it "raises when END_GROUP field number does not match in skip_field" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_uint64(7_u64)
      writer.write_tag(97, Proto::WireType::END_GROUP)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      fn.should eq 96
      wt.should eq Proto::WireType::START_GROUP
      expect_raises(Proto::DecodeError, /mismatched END_GROUP/) do
        reader.skip_tag({fn, wt})
      end
    end

    it "detects nested END_GROUP mismatch in skip_field" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(10, Proto::WireType::START_GROUP)
      writer.write_tag(11, Proto::WireType::END_GROUP)
      writer.write_tag(96, Proto::WireType::END_GROUP)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      expect_raises(Proto::DecodeError, /mismatched END_GROUP/) do
        reader.skip_tag({fn, wt})
      end
    end

    it "skips a nested group and continues with the next field" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(10, Proto::WireType::START_GROUP)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_uint64(9_u64)
      writer.write_tag(10, Proto::WireType::END_GROUP)
      writer.write_tag(96, Proto::WireType::END_GROUP)
      writer.write_int32(55)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      reader.skip_tag({fn, wt})
      reader.read_int32.should eq 55
    end

    it "raises when EOF occurs before END_GROUP in skip_field" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_uint64(7_u64)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      expect_raises(Proto::DecodeError, /unexpected EOF inside group/) do
        reader.skip_tag({fn, wt})
      end
    end
  end

  describe "full message round-trip (hand-written)" do
    # message Person { string name = 1; int32 age = 2; }
    it "encodes and decodes a simple two-field message" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      # field 1: name (string, wire type 2)
      w.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
      w.write_string("Alice")
      # field 2: age (int32, wire type 0)
      w.write_tag(2, Proto::WireType::VARINT)
      w.write_int32(30)

      io.rewind
      r = Proto::Wire::Reader.new(io)

      name = ""
      age = 0_i32
      while tag = r.read_tag
        fn, _wt = tag
        case fn
        when 1 then name = r.read_string
        when 2 then age = r.read_int32
        else        r.skip_tag(tag)
        end
      end

      name.should eq "Alice"
      age.should eq 30
    end
  end

  describe "unknown field preservation" do
    it "captures and re-encodes an unknown varint field" do
      # Encode a message with field 99 (unknown to decoder)
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(42)
      w.write_tag(99, Proto::WireType::VARINT) # unknown field
      w.write_uint64(1234_u64)

      # Decode, capture unknowns
      known_value = 0_i32

      io.rewind
      r = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new

      while tag = r.read_tag
        fn, wt = tag
        case fn
        when 1 then known_value = r.read_int32
        else        mock_msg.capture_unknown_field(r, fn, wt)
        end
      end

      known_value.should eq 42
      mock_msg.unknown_fields.size.should eq 1
      mock_msg.unknown_fields[0].field_number.should eq 99
      mock_msg.unknown_fields[0].wire_type.should eq Proto::WireType::VARINT

      # Re-encode including unknown fields
      re_encoded = IO::Memory.new
      ow = Proto::Wire::Writer.new(re_encoded)
      ow.write_tag(1, Proto::WireType::VARINT)
      ow.write_int32(known_value)
      mock_msg.write_unknown_fields(ow)

      # Decode the re-encoded bytes and verify field 99 is still present
      re_encoded.rewind
      r2 = Proto::Wire::Reader.new(re_encoded)
      fields = {} of Int32 => UInt64
      while tag = r2.read_tag
        fn, wt = tag
        case wt
        when Proto::WireType::VARINT
          fields[fn] = r2.read_uint64
        else
          r2.skip_tag(tag)
        end
      end
      fields[99]?.should eq 1234_u64
    end

    it "captures and re-encodes an unknown length-delimited field" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(7)
      w.write_tag(98, Proto::WireType::LENGTH_DELIMITED) # unknown field
      w.write_string("opaque")

      known_value = 0_i32
      io.rewind
      r = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new

      while tag = r.read_tag
        fn, wt = tag
        case fn
        when 1 then known_value = r.read_int32
        else        mock_msg.capture_unknown_field(r, fn, wt)
        end
      end

      known_value.should eq 7
      mock_msg.unknown_fields.size.should eq 1
      mock_msg.unknown_fields[0].field_number.should eq 98
      mock_msg.unknown_fields[0].wire_type.should eq Proto::WireType::LENGTH_DELIMITED

      re_encoded = IO::Memory.new
      ow = Proto::Wire::Writer.new(re_encoded)
      ow.write_tag(1, Proto::WireType::VARINT)
      ow.write_int32(known_value)
      mock_msg.write_unknown_fields(ow)

      re_encoded.rewind
      r2 = Proto::Wire::Reader.new(re_encoded)
      payload = ""
      while tag = r2.read_tag
        fn, wt = tag
        case fn
        when 98
          wt.should eq Proto::WireType::LENGTH_DELIMITED
          payload = r2.read_string
        else
          r2.skip_tag(tag)
        end
      end
      payload.should eq "opaque"
    end

    it "captures and re-encodes an unknown fixed32 field" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(11)
      w.write_tag(97, Proto::WireType::FIXED32) # unknown field
      w.write_fixed32(0xDEADBEEF_u32)

      known_value = 0_i32
      io.rewind
      r = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new

      while tag = r.read_tag
        fn, wt = tag
        case fn
        when 1 then known_value = r.read_int32
        else        mock_msg.capture_unknown_field(r, fn, wt)
        end
      end

      known_value.should eq 11
      mock_msg.unknown_fields.size.should eq 1
      mock_msg.unknown_fields[0].field_number.should eq 97
      mock_msg.unknown_fields[0].wire_type.should eq Proto::WireType::FIXED32

      re_encoded = IO::Memory.new
      ow = Proto::Wire::Writer.new(re_encoded)
      ow.write_tag(1, Proto::WireType::VARINT)
      ow.write_int32(known_value)
      mock_msg.write_unknown_fields(ow)

      re_encoded.rewind
      r2 = Proto::Wire::Reader.new(re_encoded)
      value = 0_u32
      while tag = r2.read_tag
        fn, wt = tag
        case fn
        when 97
          wt.should eq Proto::WireType::FIXED32
          value = r2.read_fixed32
        else
          r2.skip_tag(tag)
        end
      end
      value.should eq 0xDEADBEEF_u32
    end

    it "captures and re-encodes an unknown group field" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(96, Proto::WireType::START_GROUP)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_uint64(77_u64)
      w.write_tag(96, Proto::WireType::END_GROUP)

      io.rewind
      r = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new
      while tag = r.read_tag
        fn, wt = tag
        mock_msg.capture_unknown_field(r, fn, wt)
      end

      mock_msg.unknown_fields.size.should eq 1
      mock_msg.unknown_fields[0].field_number.should eq 96
      mock_msg.unknown_fields[0].wire_type.should eq Proto::WireType::START_GROUP

      re = IO::Memory.new
      ow = Proto::Wire::Writer.new(re)
      mock_msg.write_unknown_fields(ow)

      re.rewind
      rr = Proto::Wire::Reader.new(re)
      first = rr.read_tag
      first.should_not be_nil
      first_tag = first.as({Int32, Int32})
      first_tag[0].should eq 96
      first_tag[1].should eq Proto::WireType::START_GROUP

      nested = rr.read_tag
      nested.should_not be_nil
      nested_tag = nested.as({Int32, Int32})
      nested_tag[0].should eq 1
      nested_tag[1].should eq Proto::WireType::VARINT
      rr.read_uint64.should eq 77_u64

      group_end = rr.read_tag
      group_end.should_not be_nil
      end_tag = group_end.as({Int32, Int32})
      end_tag[0].should eq 96
      end_tag[1].should eq Proto::WireType::END_GROUP
    end

    it "raises for mismatched END_GROUP while capturing unknown group" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_uint64(77_u64)
      writer.write_tag(97, Proto::WireType::END_GROUP)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      expect_raises(Proto::DecodeError, /mismatched END_GROUP/) do
        mock_msg.capture_unknown_field(reader, fn, wt)
      end
    end

    it "raises for unexpected EOF while capturing unknown group" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(96, Proto::WireType::START_GROUP)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_uint64(77_u64)
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      mock_msg = Proto::HasUnknownFieldsCapture.new
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})
      expect_raises(Proto::DecodeError, /unexpected EOF inside group/) do
        mock_msg.capture_unknown_field(reader, fn, wt)
      end
    end
  end

  describe "packed repeated" do
    it "roundtrips packed int32 values" do
      values = [1_i32, -2_i32, 300_i32, Int32::MIN, Int32::MAX]
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_packed(1) do |buf|
        sub = Proto::Wire::Writer.new(buf)
        values.each { |v| sub.write_int32(v) }
      end
      io.rewind
      r = Proto::Wire::Reader.new(io)
      tag = r.read_tag
      tag.should_not be_nil
      decoded_tag = tag.as({Int32, Int32})
      decoded_tag[0].should eq 1
      decoded_tag[1].should eq Proto::WireType::LENGTH_DELIMITED
      result = [] of Int32
      r.read_packed_varint { |v| result << Proto::Wire::Reader.int32_from_varint(v) }
      result.should eq values
    end

    it "roundtrips packed double values" do
      values = [0.0_f64, 1.5_f64, -3.14_f64]
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_packed(2) do |buf|
        sub = Proto::Wire::Writer.new(buf)
        values.each { |v| sub.write_double(v) }
      end
      io.rewind
      r = Proto::Wire::Reader.new(io)
      tag = r.read_tag
      tag.should_not be_nil
      decoded_tag = tag.as({Int32, Int32})
      decoded_tag[0].should eq 2
      result = [] of Float64
      r.read_packed_double { |v| result << v }
      result.should eq values
    end

    it "roundtrips packed fixed32 values" do
      values = [0_u32, 1_u32, 0xDEADBEEF_u32]
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_packed(3) do |buf|
        sub = Proto::Wire::Writer.new(buf)
        values.each { |v| sub.write_fixed32(v) }
      end
      io.rewind
      r = Proto::Wire::Reader.new(io)
      tag = r.read_tag
      tag.should_not be_nil
      decoded_tag = tag.as({Int32, Int32})
      decoded_tag[0].should eq 3
      result = [] of UInt32
      r.read_packed_fixed32 { |v| result << v }
      result.should eq values
    end

    it "raises DecodeError for malformed packed fixed32 payload" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(4, Proto::WireType::LENGTH_DELIMITED)
      writer.write_varint(3_u64)
      io.write(Bytes[0x01, 0x02, 0x03])
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      reader.read_tag.should_not be_nil
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_packed_fixed32 { |_| }
      end
    end

    it "raises DecodeError for malformed packed double payload" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(5, Proto::WireType::LENGTH_DELIMITED)
      writer.write_varint(7_u64)
      io.write(Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      reader.read_tag.should_not be_nil
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_packed_double { |_| }
      end
    end

    it "skips empty packed field" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_packed(5) { |_buf| }
      io.size.should eq 0
    end
  end

  describe "reader limits" do
    it "raises when length-delimited payload exceeds max_field_length" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_string("abc")
      io.rewind

      reader = Proto::Wire::Reader.new(io, max_field_length: 2)
      expect_raises(Proto::DecodeError, /field length exceeds limit/) do
        reader.read_string
      end
    end

    it "raises when total bytes exceed max_message_size" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_string("abcdef")
      io.rewind

      reader = Proto::Wire::Reader.new(io, max_message_size: 4)
      expect_raises(Proto::DecodeError, /message exceeds max size/) do
        reader.read_string
      end
    end
  end

  describe "writer limits" do
    it "raises when bytes field exceeds max_field_length" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io, max_field_length: 2)
      expect_raises(Proto::EncodeError, /field length exceeds limit/) do
        writer.write_bytes(Bytes[0x01, 0x02, 0x03])
      end
    end

    it "raises when embedded payload exceeds max_field_length" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io, max_field_length: 3)
      expect_raises(Proto::EncodeError, /field length exceeds limit/) do
        writer.write_embedded(1, &.write(Bytes[1, 2, 3, 4]))
      end
    end

    it "raises when packed payload exceeds max_field_length" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io, max_field_length: 3)
      expect_raises(Proto::EncodeError, /field length exceeds limit/) do
        writer.write_packed(1, &.write(Bytes[1, 2, 3, 4]))
      end
    end
  end
end

# Minimal test helper that includes HasUnknownFields
class Proto::HasUnknownFieldsCapture
  include Proto::HasUnknownFields
end
