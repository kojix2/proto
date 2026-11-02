require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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

    it "accepts the maximum valid ten-byte varint" do
      bytes = Bytes[0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]
      decode_varint(bytes).should eq(UInt64::MAX)
    end

    it "raises on varint overflow" do
      bytes = Bytes[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01]
      reader = Proto::Wire::Reader.new(IO::Memory.new(bytes))
      expect_raises(Proto::DecodeError, /varint overflow/) do
        reader.read_uint64
      end
    end

    it "rejects payload bits above UInt64 in the tenth byte" do
      [0x02_u8, 0x7f_u8].each do |last|
        bytes = Bytes[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, last]
        expect_raises(Proto::DecodeError, /varint overflow/) { decode_varint(bytes) }
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
end

describe Proto::Wire::Reader do
  {0x1_0000_0000_u64 => 0, 0x1_ffff_ffff_u64 => -1,
   0x1234_5678_8000_0000_u64 => Int32::MIN, UInt64::MAX => -1}.each do |raw, expected|
    it "truncates int32 varint #{raw} to its signed low 32 bits" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_varint(raw)
      io.rewind
      Proto::Wire::Reader.new(io).read_int32.should eq(expected)
    end
  end
end
