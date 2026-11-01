require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
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
end
