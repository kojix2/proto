require "../spec_helper"
require "../../src/proto/bootstrap/plugin"

describe "protoc plugin protocol" do
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
end
