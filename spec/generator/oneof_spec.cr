require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "oneof" do
    it "generates oneof setters, clearer, and guarded encode paths" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "oneof.proto"
      file.package = "oneofpkg"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Choice"

      oneof = Proto::Bootstrap::OneofDescriptorProto.new
      oneof.name = "value"
      msg.oneof_decl << oneof

      f1 = Proto::Bootstrap::FieldDescriptorProto.new
      f1.name = "name"
      f1.number = 1
      f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f1.type = Proto::Bootstrap::FieldType::TYPE_STRING
      f1.oneof_index = 0

      f2 = Proto::Bootstrap::FieldDescriptorProto.new
      f2.name = "count"
      f2.number = 2
      f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f2.type = Proto::Bootstrap::FieldType::TYPE_INT32
      f2.oneof_index = 0

      msg.field << f1 << f2
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("enum ValueCase : Int32")
      code.should contain("NONE = 0")
      code.should contain("NAME = 1")
      code.should contain("COUNT = 2")
      code.should contain("getter value_case : ValueCase = ValueCase::NONE")
      code.should contain("def clear_value : Nil")
      code.should contain("@value_case = ValueCase::NONE")
      code.should contain("def name=(value : String) : String")
      code.should contain("@name = value")
      code.should contain("@count = 0")
      code.should contain("@value_case = ValueCase::NAME")
      code.should contain("def count=(value : Int32) : Int32")
      code.should contain("@name = \"\"")
      code.should contain("@value_case = ValueCase::COUNT")
      code.should contain("if value_case == ValueCase::NAME")
      code.should contain("if value_case == ValueCase::COUNT")
      code.should contain("return false unless value_case == other.value_case")
    end
  end
end
