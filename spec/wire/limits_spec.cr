require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
  describe "reader limits" do
    [0x80000000_u64, 0x100000000_u64, 0x100000001_u64, UInt64::MAX].each do |length|
      {"bytes", "string", "embedded", "skip", "unknown"}.each do |operation|
        it "rejects length #{length} before #{operation} can truncate it" do
          io = IO::Memory.new
          Proto::Wire::Writer.new(io).write_varint(length)
          io.rewind
          reader = Proto::Wire::Reader.new(io)
          expect_raises(Proto::DecodeError, /length out of range/) do
            case operation
            when "bytes"    then reader.read_bytes
            when "string"   then reader.read_string
            when "embedded" then reader.read_embedded
            when "skip"     then reader.skip_field(Proto::WireType::LENGTH_DELIMITED)
            when "unknown"  then reader.read_unknown_field(1, Proto::WireType::LENGTH_DELIMITED)
            end
          end
        end
      end
    end

    it "accepts a payload exactly at both configured limits" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[3, 1, 2, 3]), max_message_size: 4, max_field_length: 3)
      reader.read_bytes.should eq(Bytes[1, 2, 3])
    end

    it "rejects a declared payload exceeding the remaining budget before reading it" do
      io = IO::Memory.new(Bytes[3, 1, 2, 3])
      reader = Proto::Wire::Reader.new(io, max_message_size: 3)
      expect_raises(Proto::DecodeError, /message exceeds max size/) { reader.read_bytes }
      io.pos.should eq(1)
    end

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

describe "shared reader accounting" do
  it "enforces the cumulative byte budget through the reader-taking unknown-field helper" do
    message = Proto::Bootstrap::CodeGeneratorResponse.new
    reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[122, 2, 97, 98, 122, 2, 99, 100]), max_message_size: 5)
    fn, wt = reader.read_tag.as({Int32, Int32})
    message.capture_unknown_field(reader, fn, wt)
    fn, wt = reader.read_tag.as({Int32, Int32})
    expect_raises(Proto::DecodeError, /max size/) { message.capture_unknown_field(reader, fn, wt) }
  end
end

describe "recursion limits" do
  {"capture", "skip"}.each do |operation|
    it "bounds nested unknown groups while #{operation} uses the same reader" do
      {5, 6}.each do |depth|
        data = Bytes.new(depth, 0x0b_u8) + Bytes.new(depth, 0x0c_u8)
        reader = Proto::Wire::Reader.new(IO::Memory.new(data), max_recursion_depth: 5)
        tag = reader.read_tag.as({Int32, Int32})
        if depth == 5
          operation == "capture" ? reader.read_unknown_field(*tag) : reader.skip_tag(tag)
          reader.read_tag.should be_nil
        else
          expect_raises(Proto::DecodeError, /recursion/) do
            operation == "capture" ? reader.read_unknown_field(*tag) : reader.skip_tag(tag)
          end
        end
      end
    end
  end

  it "shares depth between nested-message IO and unknown groups" do
    outer = Proto::Wire::Reader.new(IO::Memory.new(Bytes[2, 11, 12]), max_recursion_depth: 1)
    inner = Proto::Wire::Reader.new(outer.read_embedded)
    fn, wt = inner.read_tag.as({Int32, Int32})
    expect_raises(Proto::DecodeError, /recursion/) { inner.read_unknown_field(fn, wt) }
  end

  it "permits packed values at the deepest allowed message level" do
    outer = Proto::Wire::Reader.new(IO::Memory.new(Bytes[7, 1, 1, 4, 0, 0, 0, 0]), max_recursion_depth: 1)
    inner = Proto::Wire::Reader.new(outer.read_embedded)
    values = [] of UInt64
    inner.read_packed_varint { |value| values << value }
    fixed = [] of UInt32
    inner.read_packed_fixed32 { |value| fixed << value }
    values.should eq([1_u64])
    fixed.should eq([0_u32])
  end
end
