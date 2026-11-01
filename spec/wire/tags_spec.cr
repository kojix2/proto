require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
  describe "read_tag" do
    [0x100000001_u64, UInt64::MAX >> 3].each do |field_number|
      it "rejects field number #{field_number} before narrowing its representation" do
        io = IO::Memory.new
        Proto::Wire::Writer.new(io).write_varint(field_number << 3)
        io.rewind
        expect_raises(Proto::DecodeError, /field number out of range/) do
          Proto::Wire::Reader.new(io).read_tag
        end
      end
    end

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
end
