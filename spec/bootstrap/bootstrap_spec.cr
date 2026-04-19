require "../spec_helper"
require "file_utils"
require "../../src/proto/bootstrap/plugin"

describe "Proto::Bootstrap" do
  describe "CodeGeneratorRequest round-trip" do
    it "decodes an empty request" do
      req = Proto::Bootstrap::CodeGeneratorRequest.decode(IO::Memory.new(Bytes.empty))
      req.file_to_generate.should be_empty
      req.parameter.should eq ""
      req.proto_file.should be_empty
    end

    it "round-trips a minimal request" do
      # Build a minimal CodeGeneratorRequest with one file_to_generate and
      # one FileDescriptorProto having a single message.
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)

      # file_to_generate = ["hello.proto"]  (field 1)
      w.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
      w.write_string("hello.proto")

      # parameter = "plugins=grpc"  (field 2)
      w.write_tag(2, Proto::WireType::LENGTH_DELIMITED)
      w.write_string("plugins=grpc")

      # proto_file[0]  (field 15, embedded FileDescriptorProto)
      #   name    = "hello.proto"
      #   package = "helloworld"
      #   syntax  = "proto3"
      #   message_type[0] = DescriptorProto { name = "HelloRequest" }
      file_io = IO::Memory.new
      fw = Proto::Wire::Writer.new(file_io)
      fw.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
      fw.write_string("hello.proto")
      fw.write_tag(2, Proto::WireType::LENGTH_DELIMITED)
      fw.write_string("helloworld")
      fw.write_tag(12, Proto::WireType::LENGTH_DELIMITED)
      fw.write_string("proto3")
      # nested message_type (field 4)
      msg_io = IO::Memory.new
      mw = Proto::Wire::Writer.new(msg_io)
      mw.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
      mw.write_string("HelloRequest")
      fw.write_tag(4, Proto::WireType::LENGTH_DELIMITED)
      fw.write_bytes(msg_io.to_slice)

      # Write proto_file into request (field 15)
      w.write_tag(15, Proto::WireType::LENGTH_DELIMITED)
      w.write_bytes(file_io.to_slice)

      # Decode
      io.rewind
      req = Proto::Bootstrap::CodeGeneratorRequest.decode(io)

      req.file_to_generate.should eq ["hello.proto"]
      req.parameter.should eq "plugins=grpc"
      req.proto_file.size.should eq 1

      fd = req.proto_file[0]
      fd.name.should eq "hello.proto"
      fd.package.should eq "helloworld"
      fd.syntax.should eq "proto3"
      fd.message_type.size.should eq 1
      fd.message_type[0].name.should eq "HelloRequest"
    end
  end

  describe "CodeGeneratorResponse" do
    it "serializes an empty success response" do
      resp = Proto::Bootstrap::CodeGeneratorResponse.new
      resp.supported_features = Proto::Bootstrap::FEATURE_PROTO3_OPTIONAL
      bytes = resp.encode

      # Decode back
      decoded = Proto::Bootstrap::CodeGeneratorResponse.decode(IO::Memory.new(bytes))
      decoded.error.should eq ""
      decoded.supported_features.should eq Proto::Bootstrap::FEATURE_PROTO3_OPTIONAL
      decoded.file.should be_empty
    end

    it "serializes a response with one generated file" do
      resp = Proto::Bootstrap::CodeGeneratorResponse.new
      f = Proto::Bootstrap::CodeGeneratorResponseFile.new
      f.name = "hello.pb.cr"
      f.content = "# generated\n"
      resp.file << f

      bytes = resp.encode
      decoded = Proto::Bootstrap::CodeGeneratorResponse.decode(IO::Memory.new(bytes))
      decoded.file.size.should eq 1
      decoded.file[0].name.should eq "hello.pb.cr"
      decoded.file[0].content.should eq "# generated\n"
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

  describe "protoc plugin integration" do
    it "plugin binary handles an empty request and emits a valid response" do
      # Ensure the plugin binary is built from the current source to avoid
      # stale artifacts causing false negatives.
      plugin_src = "#{__DIR__}/../../src/protoc-gen-crystal_main.cr"
      plugin_bin = "#{__DIR__}/../../bin/protoc-gen-crystal"
      FileUtils.mkdir_p(File.dirname(plugin_bin))
      build = Process.new(
        "crystal",
        ["build", plugin_src, "-o", plugin_bin],
        output: Process::Redirect::Close,
        error: Process::Redirect::Pipe,
      )
      build_err = build.error.gets_to_end
      build_status = build.wait
      build_status.success?.should(
        be_true,
        "failed to build plugin binary: #{build_err}"
      )

      # Build an empty CodeGeneratorRequest
      req = Proto::Bootstrap::CodeGeneratorRequest.new
      req_bytes = IO::Memory.new
      req.encode(req_bytes)

      # Run the plugin binary
      proc = Process.new(
        plugin_bin,
        input: IO::Memory.new(req_bytes.to_slice),
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe,
      )
      resp_bytes = proc.output.gets_to_end.to_slice
      proc.wait

      resp = Proto::Bootstrap::CodeGeneratorResponse.decode(IO::Memory.new(resp_bytes))
      resp.error.should eq ""
      resp.supported_features.should eq Proto::Bootstrap::FEATURE_PROTO3_OPTIONAL
    end
  end
end
