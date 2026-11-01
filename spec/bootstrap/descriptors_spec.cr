require "../spec_helper"
require "../../src/proto/bootstrap/plugin"

describe "Proto::Bootstrap descriptors" do
  describe Proto::Bootstrap::FieldOptions do
    it "round-trips explicit packed field options including false" do
      [false, true].each do |packed|
        options = Proto::Bootstrap::FieldOptions.new
        options.packed = packed
        io = IO::Memory.new
        options.encode(io)
        decoded = Proto::Bootstrap::FieldOptions.decode(IO::Memory.new(io.to_slice))
        decoded.packed.should eq(packed)
      end
      Proto::Bootstrap::FieldOptions.new.packed.should be_nil
    end
  end

  describe "FieldDescriptorProto" do
    it "round-trips all scalar fields" do
      original = Proto::Bootstrap::FieldDescriptorProto.new
      original.name = "my_field"
      original.extendee = ".example.Target"
      original.number = 3
      original.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      original.type = Proto::Bootstrap::FieldType::TYPE_INT32
      original.json_name = "myField"

      io = IO::Memory.new
      original.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::FieldDescriptorProto.decode(io)

      decoded.name.should eq "my_field"
      decoded.extendee.should eq ".example.Target"
      decoded.number.should eq 3
      decoded.label.should eq Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      decoded.type.should eq Proto::Bootstrap::FieldType::TYPE_INT32
      decoded.json_name.should eq "myField"
    end

    it "round-trips oneof_index" do
      original = Proto::Bootstrap::FieldDescriptorProto.new
      original.name = "value"
      original.oneof_index = 0
      original.proto3_optional = true

      io = IO::Memory.new
      original.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::FieldDescriptorProto.decode(io)

      decoded.oneof_index.should eq 0
      decoded.proto3_optional?.should be_true
    end

    it "round-trips field options unknown extension values" do
      original = Proto::Bootstrap::FieldDescriptorProto.new
      original.name = "flag"

      options = Proto::Bootstrap::FieldOptions.new
      options.add_unknown_varint(50_001, 1_u64)
      original.options = options

      io = IO::Memory.new
      original.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::FieldDescriptorProto.decode(io)

      decoded.options.should_not be_nil
      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_001
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL

      if decoded_options = decoded.options
        decoded_options.has_extension?(extension).should be_true
        decoded_options.extension_value?(extension).should be_true
      else
        fail "expected options to be present"
      end
    end
  end

  describe "DescriptorProto nested_type" do
    it "round-trips nested messages" do
      outer = Proto::Bootstrap::DescriptorProto.new
      outer.name = "Outer"

      inner = Proto::Bootstrap::DescriptorProto.new
      inner.name = "Inner"
      outer.nested_type << inner

      io = IO::Memory.new
      outer.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::DescriptorProto.decode(io)

      decoded.name.should eq "Outer"
      decoded.nested_type.size.should eq 1
      decoded.nested_type[0].name.should eq "Inner"
    end

    it "round-trips message options with map_entry" do
      entry = Proto::Bootstrap::DescriptorProto.new
      entry.name = "RatingsEntry"
      entry_options = Proto::Bootstrap::MessageOptions.new
      entry_options.map_entry = true
      entry.options = entry_options

      io = IO::Memory.new
      entry.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::DescriptorProto.decode(io)

      decoded.name.should eq "RatingsEntry"
      decoded.options.should_not be_nil
      if options = decoded.options
        options.map_entry?.should be_true
      else
        fail "expected options to be present"
      end
    end
  end

  describe "ServiceDescriptorProto" do
    it "round-trips a service with streaming methods" do
      svc = Proto::Bootstrap::ServiceDescriptorProto.new
      svc.name = "Greeter"

      m = Proto::Bootstrap::MethodDescriptorProto.new
      m.name = "BidiChat"
      m.input_type = ".helloworld.ChatRequest"
      m.output_type = ".helloworld.ChatReply"
      m.client_streaming = true
      m.server_streaming = true
      svc.method << m

      io = IO::Memory.new
      svc.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::ServiceDescriptorProto.decode(io)

      decoded.name.should eq "Greeter"
      decoded.method.size.should eq 1
      dm = decoded.method[0]
      dm.name.should eq "BidiChat"
      dm.input_type.should eq ".helloworld.ChatRequest"
      dm.output_type.should eq ".helloworld.ChatReply"
      dm.client_streaming?.should be_true
      dm.server_streaming?.should be_true
    end

    it "round-trips method options unknown extension values" do
      method = Proto::Bootstrap::MethodDescriptorProto.new
      method.name = "Run"

      options = Proto::Bootstrap::MethodOptions.new
      options.add_unknown_varint(50_003, 1_u64)
      method.options = options

      io = IO::Memory.new
      method.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::MethodDescriptorProto.decode(io)

      decoded.options.should_not be_nil
      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_003
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL

      if decoded_options = decoded.options
        decoded_options.has_extension?(extension).should be_true
        decoded_options.extension_value?(extension).should be_true
      else
        fail "expected method options to be present"
      end
    end
  end

  describe "FileDescriptorProto extensions" do
    it "round-trips top-level extension fields" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "opts.proto"

      ext = Proto::Bootstrap::FieldDescriptorProto.new
      ext.name = "rpc_required"
      ext.extendee = ".google.protobuf.FieldOptions"
      ext.number = 50001
      ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      file.extension << ext

      io = IO::Memory.new
      file.encode(io)
      io.rewind
      decoded = Proto::Bootstrap::FileDescriptorProto.decode(io)

      decoded.extension.size.should eq 1
      decoded_ext = decoded.extension[0]
      decoded_ext.name.should eq "rpc_required"
      decoded_ext.extendee.should eq ".google.protobuf.FieldOptions"
      decoded_ext.number.should eq 50001
      decoded_ext.type.should eq Proto::Bootstrap::FieldType::TYPE_BOOL
    end
  end
end
