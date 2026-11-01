require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "descriptors" do
    it "generates service/rpc descriptors" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "svc.proto"
      file.package = "svc"
      file.syntax = "proto3"

      req = Proto::Bootstrap::DescriptorProto.new
      req.name = "PingRequest"
      file.message_type << req

      rep = Proto::Bootstrap::DescriptorProto.new
      rep.name = "PingReply"
      file.message_type << rep

      service = Proto::Bootstrap::ServiceDescriptorProto.new
      service.name = "Health"

      unary = Proto::Bootstrap::MethodDescriptorProto.new
      unary.name = "Ping"
      unary.input_type = ".svc.PingRequest"
      unary.output_type = ".svc.PingReply"
      service.method << unary

      stream = Proto::Bootstrap::MethodDescriptorProto.new
      stream.name = "Watch"
      stream.input_type = ".svc.PingRequest"
      stream.output_type = ".svc.PingReply"
      stream.server_streaming = true
      service.method << stream

      file.service << service

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("module Health")
      code.should contain("METHODS = [")
      code.should contain("name: \"Ping\"")
      code.should contain("request_type: \".svc.PingRequest\"")
      code.should contain("response_type: \".svc.PingReply\"")
      code.should contain("path: \"/svc.Health/Ping\"")
      code.should contain("name: \"Watch\"")
      code.should contain("server_streaming: true")
    end

    it "generates extend definitions as extension descriptors" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "extensions.proto"
      file.package = "extensions"
      file.syntax = "proto3"

      ext = Proto::Bootstrap::FieldDescriptorProto.new
      ext.name = "rpc_required"
      ext.extendee = ".google.protobuf.FieldOptions"
      ext.number = 50001
      ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      file.extension << ext

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("module Extensions")
      code.should contain("struct ExtensionDescriptor")
      code.should contain("RPC_REQUIRED = ExtensionDescriptor.new(")
      code.should contain("extendee: \".google.protobuf.FieldOptions\"")
      code.should contain("number: 50001")
      code.should contain("type: Proto::Bootstrap::FieldType::TYPE_BOOL")
      code.should contain("ALL = [")
      code.should contain("RPC_REQUIRED")
    end
  end
end
