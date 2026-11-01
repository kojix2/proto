require "../spec_helper"
require "../support/message_types"

describe Proto::Message do
  describe "extension access helpers" do
    it "reads a bool extension from unknown varint fields" do
      msg = ProtoSpec::PingMessage.new
      msg.add_unknown_varint(50_001, 1_u64)

      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_001
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL

      msg.has_extension?(extension).should be_true
      msg.extension_value?(extension).should be_true
    end

    it "returns repeated extension values in wire order" do
      msg = ProtoSpec::PingMessage.new
      msg.add_unknown_varint(50_002, 10_u64)
      msg.add_unknown_varint(50_002, 20_u64)

      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_002
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      extension.type = Proto::Bootstrap::FieldType::TYPE_INT32

      values = msg.extension_values(extension)
      values.size.should eq(2)
      values[0].should eq(10)
      values[1].should eq(20)
      msg.extension_value?(extension).should eq(20)
    end

    it "reads string extensions from length-delimited unknown fields" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(50_003, Proto::WireType::LENGTH_DELIMITED)
      writer.write_string("demo")

      msg = ProtoSpec::PingMessage.decode(io.to_slice)
      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_003
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_STRING

      msg.has_extension?(extension).should be_true
      msg.extension_value?(extension).should eq("demo")
    end

    it "reads mixed packed and unpacked repeated varint extensions" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_packed(50_004) do |buf|
        packed = Proto::Wire::Writer.new(buf)
        packed.write_int32(10)
        packed.write_int32(20)
      end
      writer.write_tag(50_004, Proto::WireType::VARINT)
      writer.write_int32(30)

      descriptor = Proto::Bootstrap::FieldDescriptorProto.new
      descriptor.number = 50_004
      descriptor.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      descriptor.type = Proto::Bootstrap::FieldType::TYPE_INT32
      ProtoSpec::PingMessage.decode(io.to_slice).extension_values(descriptor).should eq([10, 20, 30])
    end

    it "reads packed fixed-width and enum extensions" do
      fixed_io = IO::Memory.new
      fixed_writer = Proto::Wire::Writer.new(fixed_io)
      fixed_writer.write_packed(50_005) do |buf|
        packed = Proto::Wire::Writer.new(buf)
        packed.write_fixed32(1_u32)
        packed.write_fixed32(UInt32::MAX)
      end
      fixed = Proto::Bootstrap::FieldDescriptorProto.new
      fixed.number = 50_005
      fixed.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      fixed.type = Proto::Bootstrap::FieldType::TYPE_FIXED32
      ProtoSpec::PingMessage.decode(fixed_io.to_slice).extension_values(fixed).should eq([1_u32, UInt32::MAX])

      enum_io = IO::Memory.new
      enum_writer = Proto::Wire::Writer.new(enum_io)
      enum_writer.write_packed(50_006) do |buf|
        packed = Proto::Wire::Writer.new(buf)
        packed.write_int32(1)
        packed.write_int32(2)
      end
      enum_desc = Proto::Bootstrap::FieldDescriptorProto.new
      enum_desc.number = 50_006
      enum_desc.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      enum_desc.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      ProtoSpec::PingMessage.decode(enum_io.to_slice).extension_values(enum_desc).should eq([1, 2])
    end
  end
end
