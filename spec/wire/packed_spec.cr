require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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
end
