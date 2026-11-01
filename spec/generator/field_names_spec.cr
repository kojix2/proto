require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "field names" do
    it "normalizes uppercase and camelCase field names to valid Crystal identifiers" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "timing.proto"
      file.package = "timing"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "TimingEnginePeriods"

      f1 = Proto::Bootstrap::FieldDescriptorProto.new
      f1.name = "RST1"
      f1.number = 1
      f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f1.type = Proto::Bootstrap::FieldType::TYPE_UINT32

      f2 = Proto::Bootstrap::FieldDescriptorProto.new
      f2.name = "biasVoltage"
      f2.number = 2
      f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f2.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE

      msg.field << f1 << f2
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      generated = Proto::Generator::FileGenerator.new(file, index).generate

      generated.should contain("property rst1 : UInt32 = 0")
      generated.should contain("msg.rst1 = reader.read_uint32")
      generated.should contain("property bias_voltage : Float64 = 0.0_f64")
      generated.should contain("msg.bias_voltage = reader.read_double")
    end

    it "escapes Crystal keyword field names" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "keyword_field.proto"
      file.package = "keyword_field"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"

      field = Proto::Bootstrap::FieldDescriptorProto.new
      field.name = "alias"
      field.number = 1
      field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      field.type = Proto::Bootstrap::FieldType::TYPE_STRING
      msg.field << field
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      generated = Proto::Generator::FileGenerator.new(file, index).generate

      generated.should contain("property alias_ : String")
      generated.should contain("msg.alias_ = reader.read_string")
      generated.should contain("if !alias_.empty?")
    end

    it "keeps normalized unknown_fields names distinct" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "unknown_fields.proto"
      file.package = "reserved"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"
      {"unknown_fields", "unknown_fields_"}.each_with_index do |name, index|
        field = Proto::Bootstrap::FieldDescriptorProto.new
        field.name = name
        field.number = index + 1
        field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
        field.type = Proto::Bootstrap::FieldType::TYPE_STRING
        msg.field << field
      end
      file.message_type << msg

      generated = Proto::Generator::FileGenerator.new(
        file, Proto::Generator::TypeIndex.new([file])
      ).generate

      generated.should contain("property unknown_fields_ : String")
      generated.should contain("property unknown_fields__2 : String")
    end

    it "fails fast on normalized identifier collisions" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "collision.proto"
      file.package = "collide"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Sample"

      a = Proto::Bootstrap::FieldDescriptorProto.new
      a.name = "foo-bar"
      a.number = 1
      a.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      a.type = Proto::Bootstrap::FieldType::TYPE_INT32

      b = Proto::Bootstrap::FieldDescriptorProto.new
      b.name = "foo_bar"
      b.number = 2
      b.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      b.type = Proto::Bootstrap::FieldType::TYPE_INT32

      msg.field << a << b
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)

      expect_raises(Exception, /identifier collision/) do
        gen.generate
      end
    end
  end
end
