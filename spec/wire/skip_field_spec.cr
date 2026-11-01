require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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
end
