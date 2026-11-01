require "../spec_helper"
require "../support/message_types"

describe Proto::Message do
  describe "unknown enum compatibility" do
    it "keeps unknown enum numeric values as unknown fields" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(123)

      decoded = ProtoSpec::StrictEnumMessage.decode(IO::Memory.new(io.to_slice))
      decoded.mode.should eq(ProtoSpec::StrictMode::UNKNOWN)
      decoded.unknown_fields.size.should eq(1)
      decoded.unknown_fields[0].field_number.should eq(1)
      decoded.unknown_fields[0].wire_type.should eq(Proto::WireType::VARINT)
      decoded.unknown_fields[0].data.should eq(123_u64)

      reencoded = decoded.encode
      parsed = ProtoSpec::StrictEnumMessage.decode(IO::Memory.new(reencoded))
      parsed.unknown_fields.size.should eq(1)
      parsed.unknown_fields[0].data.should eq(123_u64)
    end

    it "keeps negative unknown enum values as raw unknown varints" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(-1)

      decoded = ProtoSpec::StrictEnumMessage.decode(IO::Memory.new(io.to_slice))
      decoded.mode.should eq(ProtoSpec::StrictMode::UNKNOWN)
      decoded.unknown_fields.size.should eq(1)
      decoded.unknown_fields[0].field_number.should eq(1)
      decoded.unknown_fields[0].wire_type.should eq(Proto::WireType::VARINT)
      decoded.unknown_fields[0].data.should eq(UInt64::MAX)

      reencoded = decoded.encode
      parsed = ProtoSpec::StrictEnumMessage.decode(IO::Memory.new(reencoded))
      parsed.unknown_fields.size.should eq(1)
      parsed.unknown_fields[0].data.should eq(UInt64::MAX)
    end
  end
end
