require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "required fields" do
    it "tracks proto2 required scalar presence and validates before encoding" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "required.proto"
      file.package = "req"
      file.syntax = "proto2"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Settings"

      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = "retries"
      f.number = 1
      f.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
      f.type = Proto::Bootstrap::FieldType::TYPE_INT32

      msg.field << f
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("getter? has_retries : Bool = false")
      code.should contain("getter retries : Int32 = 0")
      code.should_not contain("property retries : Int32? = nil")
      code.should contain("def retries=(value : Int32) : Int32")
      code.should contain("def clear_retries : Nil")
      code.should contain("def validate_required! : Nil")
      code.should contain("def validate_required_deep! : Nil")
      code.should contain("raise Proto::RequiredFieldError.new(\"Missing required field: retries\") unless has_retries?")
      code.should contain("def self.decode_partial(io : IO) : self")
      code.should contain("def self.decode(io : IO) : self")
      code.should contain("msg = decode_partial(io)")
      code.should contain("def encode_partial(io : IO) : Nil")
      code.should contain("encode_partial(io)")
      code.should contain("msg.validate_required_deep!")
      code.should contain("validate_required_deep!")
      code.should contain("if has_retries?")
      code.should contain("w.write_tag(1, Proto::WireType::VARINT)")
      code.should contain("w.write_int32(retries)")
    end

    it "tracks proto2 required message presence and validates via has_*" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "required_message.proto"
      file.package = "req"
      file.syntax = "proto2"

      child = Proto::Bootstrap::DescriptorProto.new
      child.name = "Child"

      child_field = Proto::Bootstrap::FieldDescriptorProto.new
      child_field.name = "value"
      child_field.number = 1
      child_field.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
      child_field.type = Proto::Bootstrap::FieldType::TYPE_INT32
      child.field << child_field

      file.message_type << child

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Settings"

      field = Proto::Bootstrap::FieldDescriptorProto.new
      field.name = "child"
      field.number = 1
      field.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
      field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      field.type_name = ".req.Child"
      msg.field << field
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property child : Req::Child? = nil")
      code.should contain("def has_child? : Bool")
      code.should contain("def clear_child : Nil")
      code.should contain("def validate_required_deep! : Nil")
      code.should contain("raise Proto::RequiredFieldError.new(\"Missing required field: child\") unless has_child?")
      code.should contain("msg.child = reader.read_embedded(1, wt) do |sub|")
      code.should contain("Req::Child.decode_partial(sub.rewrap(merged.to_slice))")
      code.should contain("child.try &.validate_required_deep!")
      code.should contain("if _v = child")
      code.should contain("w.write_embedded(1) { |sub| _v.encode_partial(sub) }")
    end
  end
end
