require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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
