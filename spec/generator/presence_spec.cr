require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "presence" do
    it "generates nilable type and nil default for proto3_optional scalar fields" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "optional.proto"
      file.package = "optpkg"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Wrapper"

      # synthetic oneof for the optional field
      syn_oneof = Proto::Bootstrap::OneofDescriptorProto.new
      syn_oneof.name = "_count"
      msg.oneof_decl << syn_oneof

      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "count"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f.type = Proto::Bootstrap::FieldType::TYPE_INT32
      f.oneof_index = 0
      f.proto3_optional = true

      msg.field << f
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # type should be nilable; default should be nil
      code.should contain("property count : Int32? = nil")
      code.should contain("def has_count? : Bool")
      code.should contain("def clear_count : Nil")
      # no case enum emitted for the synthetic oneof
      code.should_not contain("_CountCase")
      code.should_not contain("count_case")
      # encode should guard with nil check
      code.should contain("unless (_v = count).nil?")
      code.should contain("w.write_int32(_v)")
      # == method must be generated
      code.should contain("def ==(other : self) : Bool")
      code.should contain("return false unless count == other.count")
    end

    it "generates nilable type and nil guard for singular message fields" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "embed.proto"
      file.package = "embed"
      file.syntax = "proto3"

      inner = Proto::Bootstrap::DescriptorProto.new
      inner.name = "Inner"
      file.message_type << inner

      outer = Proto::Bootstrap::DescriptorProto.new
      outer.name = "Outer"

      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "child"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      f.type_name = ".embed.Inner"
      outer.field << f
      file.message_type << outer

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property child : Embed::Inner? = nil")
      code.should contain("def has_child? : Bool")
      code.should contain("def clear_child : Nil")
      code.should contain("if _v = child")
      code.should contain("w.write_embedded(1) { |sub| _v.encode_partial(sub) }")
      code.should contain("return false unless child == other.child")
    end
  end
end
