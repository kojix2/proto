require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "file layout" do
    it "emits relative requires for nested proto imports" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "minknow_api/manager.proto"
      file.package = "minknow_api.manager"
      file.dependency << "minknow_api/rpc_options.proto"
      file.dependency << "google/protobuf/timestamp.proto"

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      generated = gen.generate

      generated.should contain("require \"./rpc_options.pb.cr\"")
      generated.should contain("require \"../google/protobuf/timestamp.pb.cr\"")
    end

    it "generates code matching the golden file for simple.proto" do
      # Load the descriptor by running protoc --descriptor_set_out
      # For unit testing without invoking protoc, we build a minimal descriptor manually.
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "simple.proto"
      file.package = "simple"
      file.syntax = "proto3"

      # enum Status
      en = Proto::Bootstrap::EnumDescriptorProto.new
      en.name = "Status"
      ev0 = Proto::Bootstrap::EnumValueDescriptorProto.new
      ev0.name = "STATUS_UNKNOWN"
      ev0.number = 0
      ev1 = Proto::Bootstrap::EnumValueDescriptorProto.new
      ev1.name = "STATUS_OK"
      ev1.number = 1
      ev2 = Proto::Bootstrap::EnumValueDescriptorProto.new
      ev2.name = "STATUS_ERROR"
      ev2.number = 2
      en.value << ev0 << ev1 << ev2
      file.enum_type << en

      # message Person
      person = Proto::Bootstrap::DescriptorProto.new
      person.name = "Person"

      f1 = Proto::Bootstrap::FieldDescriptorProto.new
      f1.name = "name"
      f1.number = 1
      f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f1.type = Proto::Bootstrap::FieldType::TYPE_STRING

      f2 = Proto::Bootstrap::FieldDescriptorProto.new
      f2.name = "age"
      f2.number = 2
      f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f2.type = Proto::Bootstrap::FieldType::TYPE_INT32

      f3 = Proto::Bootstrap::FieldDescriptorProto.new
      f3.name = "active"
      f3.number = 3
      f3.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f3.type = Proto::Bootstrap::FieldType::TYPE_BOOL

      f4 = Proto::Bootstrap::FieldDescriptorProto.new
      f4.name = "status"
      f4.number = 4
      f4.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f4.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      f4.type_name = ".simple.Status"

      f5 = Proto::Bootstrap::FieldDescriptorProto.new
      f5.name = "tags"
      f5.number = 5
      f5.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      f5.type = Proto::Bootstrap::FieldType::TYPE_STRING

      f6 = Proto::Bootstrap::FieldDescriptorProto.new
      f6.name = "address"
      f6.number = 6
      f6.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      f6.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      f6.type_name = ".simple.Address"

      person.field << f1 << f2 << f3 << f4 << f5 << f6
      file.message_type << person

      # message Address
      address = Proto::Bootstrap::DescriptorProto.new
      address.name = "Address"

      a1 = Proto::Bootstrap::FieldDescriptorProto.new
      a1.name = "street"
      a1.number = 1
      a1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      a1.type = Proto::Bootstrap::FieldType::TYPE_STRING

      a2 = Proto::Bootstrap::FieldDescriptorProto.new
      a2.name = "city"
      a2.number = 2
      a2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      a2.type = Proto::Bootstrap::FieldType::TYPE_STRING

      address.field << a1 << a2
      file.message_type << address

      index = Proto::Generator::TypeIndex.new([file])
      resolver = Proto::Generator::TypeNameResolver.build("", [file])
      gen = Proto::Generator::FileGenerator.new(file, index, resolver)

      golden_path = File.join(__DIR__, "../fixtures/simple.pb.cr.golden")
      golden = File.read(golden_path)

      gen.generate.should eq(golden)
    end

    it "generates packed repeated code matching the golden file for packed.proto" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "packed.proto"
      file.package = "packed"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Numbers"

      {
        {"values", 1, Proto::Bootstrap::FieldType::TYPE_INT32},
        {"scores", 2, Proto::Bootstrap::FieldType::TYPE_DOUBLE},
        {"flags", 3, Proto::Bootstrap::FieldType::TYPE_BOOL},
        {"ids", 4, Proto::Bootstrap::FieldType::TYPE_FIXED32},
      }.each do |(fname, fnum, ftype)|
        f = Proto::Bootstrap::FieldDescriptorProto.new
        f.name = fname
        f.number = fnum
        f.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
        f.type = ftype
        msg.field << f
      end
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)

      golden_path = File.join(__DIR__, "../fixtures/packed.pb.cr.golden")
      golden = File.read(golden_path)

      gen.generate.should eq(golden)
    end
  end
end
