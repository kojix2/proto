require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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

  describe "decode helpers" do
    it "formats wire type mismatch errors via expect_wire_type!" do
      reader = Proto::Wire::Reader.new(IO::Memory.new)
      expect_raises(Proto::DecodeError, /wire type mismatch for field 7: expected Proto::WireType::LENGTH_DELIMITED, got 0/) do
        reader.expect_wire_type!(7, Proto::WireType::VARINT, Proto::WireType::LENGTH_DELIMITED)
      end
    end

    it "recognizes packed wire types and rejects invalid alternates" do
      reader = Proto::Wire::Reader.new(IO::Memory.new)
      reader.packed_wire_type?(3, Proto::WireType::LENGTH_DELIMITED, Proto::WireType::VARINT).should be_true
      reader.packed_wire_type?(3, Proto::WireType::VARINT, Proto::WireType::VARINT).should be_false
      expect_raises(Proto::DecodeError, /wire type mismatch for field 3: expected Proto::WireType::LENGTH_DELIMITED or Proto::WireType::VARINT, got 5/) do
        reader.packed_wire_type?(3, Proto::WireType::FIXED32, Proto::WireType::VARINT)
      end
    end

    it "scopes embedded reads through the field-aware helper" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_embedded(4) do |sub|
        Proto::Wire::Writer.new(sub).write_string("nested")
      end
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      _fn, wt = tag.as({Int32, Int32})

      value = reader.read_embedded(4, wt) { |sub| Proto::Wire::Reader.new(sub).read_string }
      value.should eq "nested"
    end

    it "reads unknown fields through the reader helper" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(9, Proto::WireType::LENGTH_DELIMITED)
      writer.write_string("opaque")
      io.rewind

      reader = Proto::Wire::Reader.new(io)
      tag = reader.read_tag
      tag.should_not be_nil
      fn, wt = tag.as({Int32, Int32})

      field = reader.read_unknown_field(fn, wt)
      field.field_number.should eq 9
      field.wire_type.should eq Proto::WireType::LENGTH_DELIMITED
      field.data.should eq "opaque".to_slice
    end
  end
end
