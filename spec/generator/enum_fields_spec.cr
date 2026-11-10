require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "enum fields" do
    it "normalizes lowercase enum member names to Crystal constants" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "lowercase_enum.proto"
      file.package = "lowercase_enum"
      file.syntax = "proto3"

      enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
      enum_desc.name = "Mode"

      none_value = Proto::Bootstrap::EnumValueDescriptorProto.new
      none_value.name = "none"
      none_value.number = 0
      enum_desc.value << none_value

      ready_value = Proto::Bootstrap::EnumValueDescriptorProto.new
      ready_value.name = "READY"
      ready_value.number = 1
      enum_desc.value << ready_value

      file.enum_type << enum_desc

      index = Proto::Generator::TypeIndex.new([file])
      generated = Proto::Generator::FileGenerator.new(file, index).generate

      generated.should contain("NONE = 0")
      generated.should contain("when 0 then NONE")
      generated.should contain("READY = 1")
    end

    it "deduplicates enum numeric aliases in from_raw?" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "alias_enum.proto"
      file.package = "alias_enum"
      file.syntax = "proto3"

      enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
      enum_desc.name = "Status"

      first = Proto::Bootstrap::EnumValueDescriptorProto.new
      first.name = "STATUS_UNSPECIFIED"
      first.number = 0
      enum_desc.value << first

      alias_value = Proto::Bootstrap::EnumValueDescriptorProto.new
      alias_value.name = "STATUS_DEFAULT"
      alias_value.number = 0
      enum_desc.value << alias_value

      other = Proto::Bootstrap::EnumValueDescriptorProto.new
      other.name = "STATUS_READY"
      other.number = 1
      enum_desc.value << other

      file.enum_type << enum_desc

      index = Proto::Generator::TypeIndex.new([file])
      generated = Proto::Generator::FileGenerator.new(file, index).generate

      generated.scan(/when 0 then/).size.should eq(1)
      generated.should contain("when 1 then STATUS_READY")
    end

    it "uses raw-backed OpenEnum for proto3 enum fields" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "open_enum.proto"
      file.package = "open"
      file.syntax = "proto3"

      en = Proto::Bootstrap::EnumDescriptorProto.new
      en.name = "State"
      zero = Proto::Bootstrap::EnumValueDescriptorProto.new
      zero.name = "STATE_UNSPECIFIED"
      zero.number = 0
      ready = Proto::Bootstrap::EnumValueDescriptorProto.new
      ready.name = "READY"
      ready.number = 1
      en.value << zero << ready
      file.enum_type << en

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Wrapper"

      field = Proto::Bootstrap::FieldDescriptorProto.new
      field.name = "state"
      field.number = 1
      field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      field.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      field.type_name = ".open.State"
      msg.field << field
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property state : Proto::OpenEnum(Open::State) = Proto::OpenEnum(Open::State).new(0)")
      code.should contain("enum State : Int32")
      code.should contain("def self.from_raw?(raw : Int32) : self?")
      code.should contain("when 1 then READY")
      code.should contain("msg.state = Proto::OpenEnum(Open::State).new(_raw)")
      code.should contain("if state.raw != 0")
      code.should contain("w.write_int32(state.raw)")
    end

    it "packs repeated proto3 open enums using raw values" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "open_enum_repeated.proto"
      file.package = "open"
      file.syntax = "proto3"

      en = Proto::Bootstrap::EnumDescriptorProto.new
      en.name = "State"
      zero = Proto::Bootstrap::EnumValueDescriptorProto.new
      zero.name = "STATE_UNSPECIFIED"
      zero.number = 0
      ready = Proto::Bootstrap::EnumValueDescriptorProto.new
      ready.name = "READY"
      ready.number = 1
      en.value << zero << ready
      file.enum_type << en

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Wrapper"

      field = Proto::Bootstrap::FieldDescriptorProto.new
      field.name = "states"
      field.number = 1
      field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      field.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      field.type_name = ".open.State"
      msg.field << field
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property states : Array(Proto::OpenEnum(Open::State)) = [] of Proto::OpenEnum(Open::State)")
      code.should contain("states.each { |item| sub.write_int32(item.raw) }")
    end
  end
end

describe "top-level enum identifiers" do
  it "coalesces normalized aliases only when they have the same number" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "aliases.proto"
    enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
    enum_desc.name = "State"
    {"MOO", "moo"}.each do |name|
      value = Proto::Bootstrap::EnumValueDescriptorProto.new
      value.name = name
      value.number = 2
      enum_desc.value << value
    end
    file.enum_type << enum_desc
    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Container"
    msg.enum_type << enum_desc
    file.message_type << msg

    code = Proto::Generator::FileGenerator.new(file, Proto::Generator::TypeIndex.new([file])).generate
    code.scan(/MOO = 2/).size.should eq(2)
  end

  it "diagnoses collisions after enum member normalization" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "collision.proto"
    enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
    enum_desc.name = "State"
    {"ready", "READY"}.each_with_index do |name, number|
      value = Proto::Bootstrap::EnumValueDescriptorProto.new
      value.name = name
      value.number = number
      enum_desc.value << value
    end
    file.enum_type << enum_desc
    expect_raises(Exception, /enum member collision/) do
      Proto::Generator::FileGenerator.new(file, Proto::Generator::TypeIndex.new([file])).generate
    end
  end
end
