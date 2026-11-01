require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "encoding" do
    it "emits wire type guards for known fields during decode" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "wire_guard.proto"
      file.package = "wireguard"
      file.syntax = "proto3"

      enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
      enum_desc.name = "State"
      zero = Proto::Bootstrap::EnumValueDescriptorProto.new
      zero.name = "STATE_UNKNOWN"
      zero.number = 0
      enum_desc.value << zero
      file.enum_type << enum_desc

      child = Proto::Bootstrap::DescriptorProto.new
      child.name = "Child"
      file.message_type << child

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"

      f1 = Proto::Bootstrap::FieldDescriptorProto.new
      f1.name = "count"
      f1.number = 1
      f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f1.type = Proto::Bootstrap::FieldType::TYPE_INT32

      f2 = Proto::Bootstrap::FieldDescriptorProto.new
      f2.name = "child"
      f2.number = 2
      f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f2.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      f2.type_name = ".wireguard.Child"

      f3 = Proto::Bootstrap::FieldDescriptorProto.new
      f3.name = "values"
      f3.number = 3
      f3.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      f3.type = Proto::Bootstrap::FieldType::TYPE_INT32

      f4 = Proto::Bootstrap::FieldDescriptorProto.new
      f4.name = "state"
      f4.number = 4
      f4.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f4.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      f4.type_name = ".wireguard.State"

      msg.field << f1 << f2 << f3 << f4
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      code = Proto::Generator::FileGenerator.new(file, index).generate

      code.should contain("reader.expect_wire_type!(1, wt, Proto::WireType::VARINT)")
      code.should contain("msg.child = reader.read_embedded(2, wt) do |sub|")
      code.should contain("Wireguard::Child.decode_partial(merged)")
      code.should contain("if reader.packed_wire_type?(3, wt, Proto::WireType::VARINT)")
      code.should contain("reader.expect_wire_type!(4, wt, Proto::WireType::VARINT)")
    end

    it "uses a Crystal-compatible proto3 non-default check for float and double" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "float_non_default.proto"
      file.package = "flt"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"

      ratio = Proto::Bootstrap::FieldDescriptorProto.new
      ratio.name = "ratio"
      ratio.number = 1
      ratio.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ratio.type = Proto::Bootstrap::FieldType::TYPE_FLOAT

      gain = Proto::Bootstrap::FieldDescriptorProto.new
      gain.name = "gain"
      gain.number = 2
      gain.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      gain.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE

      msg.field << ratio << gain
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("if !ratio.zero? || ratio.sign_bit < 0")
      code.should contain("if !gain.zero? || gain.sign_bit < 0")
      code.should_not contain("to_bits != 0")
    end

    it "elides regular proto3 scalar fields when value is default" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "plain_scalar.proto"
      file.package = "plain"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Item"

      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "count"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f.type = Proto::Bootstrap::FieldType::TYPE_INT32

      msg.field << f
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property count : Int32 = 0")
      code.should contain("if count != 0")
      code.should contain("w.write_tag(1, Proto::WireType::VARINT)")
      code.should contain("w.write_int32(count)")
      code.should_not contain("if _v = count")
    end

    it "fails fast for unsupported TYPE_GROUP fields" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "group.proto"
      file.package = "grp"
      file.syntax = "proto2"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Container"

      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "legacy_group"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f.type = Proto::Bootstrap::FieldType::TYPE_GROUP
      msg.field << f

      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)

      expect_raises(Exception, /TYPE_GROUP is not supported yet/) do
        gen.generate
      end
    end

    it "includes unknown_fields in generated equality" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "eq.proto"
      file.package = "eq"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"
      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "count"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f.type = Proto::Bootstrap::FieldType::TYPE_INT32
      msg.field << f
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      code = Proto::Generator::FileGenerator.new(file, index).generate
      code.should contain("return false unless unknown_fields == other.unknown_fields")
    end
  end
end
