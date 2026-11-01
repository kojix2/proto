require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "service and extension source structure" do
    it "emits service and extension modules together" do
      # Build a complete proto file with service and extensions
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "integration_test.proto"
      file.package = "test_pkg"
      file.syntax = "proto3"

      # Add a simple message
      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "TestRequest"
      file.message_type << msg

      reply = Proto::Bootstrap::DescriptorProto.new
      reply.name = "TestReply"
      file.message_type << reply

      # Add service with RPC
      service = Proto::Bootstrap::ServiceDescriptorProto.new
      service.name = "TestService"

      method = Proto::Bootstrap::MethodDescriptorProto.new
      method.name = "TestMethod"
      method.input_type = ".test_pkg.TestRequest"
      method.output_type = ".test_pkg.TestReply"
      service.method << method
      file.service << service

      # Add extension definition
      ext = Proto::Bootstrap::FieldDescriptorProto.new
      ext.name = "test_option"
      ext.extendee = ".google.protobuf.MethodOptions"
      ext.number = 50002
      ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext.type = Proto::Bootstrap::FieldType::TYPE_STRING
      file.extension << ext

      # Generate code
      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify code structure is complete
      code.should contain("module TestService")
      code.should contain("module Extensions")
      code.should contain("TEST_OPTION = ExtensionDescriptor.new(")

      # Check that the generated source survives a file round-trip
      tmp_file = File.tempname("proto-generated-", ".pb.cr")
      begin
        File.write(tmp_file, code)

        # Verify file was written
        File.exists?(tmp_file).should be_true

        # Read back to ensure content matches
        written_code = File.read(tmp_file)
        written_code.should eq(code)

        # Source-shape assertions; these do not compile the generated code
        code.lines.size.should be > 0
      ensure
        File.delete(tmp_file) if File.exists?(tmp_file)
      end
    end

    it "emits typed NamedTuple service metadata" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "service_check.proto"
      file.package = "svc"
      file.syntax = "proto3"

      req = Proto::Bootstrap::DescriptorProto.new
      req.name = "Request"
      file.message_type << req

      rep = Proto::Bootstrap::DescriptorProto.new
      rep.name = "Response"
      file.message_type << rep

      service = Proto::Bootstrap::ServiceDescriptorProto.new
      service.name = "CheckService"

      m1 = Proto::Bootstrap::MethodDescriptorProto.new
      m1.name = "Unary"
      m1.input_type = ".svc.Request"
      m1.output_type = ".svc.Response"
      service.method << m1

      m2 = Proto::Bootstrap::MethodDescriptorProto.new
      m2.name = "ServerStream"
      m2.input_type = ".svc.Request"
      m2.output_type = ".svc.Response"
      m2.server_streaming = true
      service.method << m2

      m3 = Proto::Bootstrap::MethodDescriptorProto.new
      m3.name = "ClientStream"
      m3.input_type = ".svc.Request"
      m3.output_type = ".svc.Response"
      m3.client_streaming = true
      service.method << m3

      file.service << service

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify NamedTuple array syntax is correct
      code.should contain("METHODS = [")
      code.should contain("] of NamedTuple(")
      code.should contain("name: String")
      code.should contain("request_type: String")
      code.should contain("response_type: String")
      code.should contain("client_streaming: Bool")
      code.should contain("server_streaming: Bool")
      code.should contain("path: String")
      code.should contain("Unary")
      code.should contain("ServerStream")
      code.should contain("ClientStream")

      # Verify method details are correct
      code.should contain("server_streaming: true") # For ServerStream
      code.should contain("client_streaming: true") # For ClientStream
    end

    it "generates extension constants with proper ExtensionDescriptor struct" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "ext_check.proto"
      file.package = "ext_pkg"
      file.syntax = "proto3"

      # Add multiple extensions to verify constant naming
      ext1 = Proto::Bootstrap::FieldDescriptorProto.new
      ext1.name = "field_one"
      ext1.extendee = ".google.protobuf.FieldOptions"
      ext1.number = 60001
      ext1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext1.type = Proto::Bootstrap::FieldType::TYPE_INT32
      file.extension << ext1

      ext2 = Proto::Bootstrap::FieldDescriptorProto.new
      ext2.name = "field_two"
      ext2.extendee = ".google.protobuf.MethodOptions"
      ext2.number = 60002
      ext2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext2.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      file.extension << ext2

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify struct definition
      code.should contain("struct ExtensionDescriptor")
      code.should contain("getter name : String")
      code.should contain("getter extendee : String")
      code.should contain("getter number : Int32")
      code.should contain("getter type : Proto::Bootstrap::FieldType")

      # Verify constant instantiation
      code.should contain("FIELD_ONE = ExtensionDescriptor.new(")
      code.should contain("FIELD_TWO = ExtensionDescriptor.new(")
      code.should contain("ALL = [")
      code.should contain("FIELD_ONE")
      code.should contain("FIELD_TWO")

      # Verify correct field values
      code.should contain("name: \"field_one\"")
      code.should contain("name: \"field_two\"")
      code.should contain("extendee: \".google.protobuf.FieldOptions\"")
      code.should contain("extendee: \".google.protobuf.MethodOptions\"")
      code.should contain("number: 60001")
      code.should contain("number: 60002")
    end

    it "emits source for all RPC shapes and extension types" do
      # Check the emitted service and extension source structure:
      # 1. Module definitions are well-formed
      # 2. NamedTuple type annotations are present
      # 3. Struct constructors are valid
      # 4. Constants are properly initialized

      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "comprehensive_check.proto"
      file.package = "check_pkg"
      file.syntax = "proto3"

      # Message definitions
      req_msg = Proto::Bootstrap::DescriptorProto.new
      req_msg.name = "ComprehensiveRequest"
      file.message_type << req_msg

      rep_msg = Proto::Bootstrap::DescriptorProto.new
      rep_msg.name = "ComprehensiveResponse"
      file.message_type << rep_msg

      # Service with mixed streaming modes
      svc = Proto::Bootstrap::ServiceDescriptorProto.new
      svc.name = "ComprehensiveService"

      %w[
        UnaryCall
        ServerStreamingCall
        ClientStreamingCall
        BidirectionalStreamingCall
      ].each do |method_name|
        method = Proto::Bootstrap::MethodDescriptorProto.new
        method.name = method_name
        method.input_type = ".check_pkg.ComprehensiveRequest"
        method.output_type = ".check_pkg.ComprehensiveResponse"

        # Set streaming flags based on method name
        if method_name.includes?("ServerStreaming")
          method.server_streaming = true
        end
        if method_name.includes?("ClientStreaming")
          method.client_streaming = true
        end
        if method_name.includes?("Bidirectional")
          method.client_streaming = true
          method.server_streaming = true
        end

        svc.method << method
      end
      file.service << svc

      # Extensions with various field types
      extension_types = [
        {
          name:     "ext_bool",
          type:     Proto::Bootstrap::FieldType::TYPE_BOOL,
          extendee: ".google.protobuf.FieldOptions",
        },
        {
          name:     "ext_int",
          type:     Proto::Bootstrap::FieldType::TYPE_INT32,
          extendee: ".google.protobuf.MethodOptions",
        },
        {
          name:     "ext_string",
          type:     Proto::Bootstrap::FieldType::TYPE_STRING,
          extendee: ".google.protobuf.ServiceOptions",
        },
      ]

      extension_types.each_with_index do |ext_spec, idx|
        ext = Proto::Bootstrap::FieldDescriptorProto.new
        ext.name = ext_spec[:name]
        ext.extendee = ext_spec[:extendee]
        ext.number = 70001 + idx
        ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
        ext.type = ext_spec[:type]
        file.extension << ext
      end

      # Generate and validate
      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Syntax structure validations
      code.should_not be_empty

      # Service module structure
      code.should contain("module ComprehensiveService")
      code.should contain("METHODS = [")
      code.should contain("UnaryCall")
      code.should contain("ServerStreamingCall")
      code.should contain("ClientStreamingCall")
      code.should contain("BidirectionalStreamingCall")

      # All methods should have complete metadata
      ["UnaryCall", "ServerStreamingCall", "ClientStreamingCall", "BidirectionalStreamingCall"].each do |mname|
        # Each method entry should be a complete NamedTuple
        code.should contain("name: \"#{mname}\"")
        code.should contain("request_type:")
        code.should contain("response_type:")
        code.should contain("client_streaming:")
        code.should contain("server_streaming:")
      end

      # Extension module structure
      code.should contain("module Extensions")
      code.should contain("struct ExtensionDescriptor")

      # Each extension should have its constant
      code.should contain("EXT_BOOL = ExtensionDescriptor.new(")
      code.should contain("EXT_INT = ExtensionDescriptor.new(")
      code.should contain("EXT_STRING = ExtensionDescriptor.new(")

      # All array should contain all extensions
      code.should contain("ALL = [")
      code.should contain("EXT_BOOL")
      code.should contain("EXT_INT")
      code.should contain("EXT_STRING")

      # Verify indentation and structure (basic heuristic)
      lines = code.lines
      lines.size.should be > 20                                # Should generate substantial code
      lines.any?(&.includes?("def initialize")).should be_true # Struct constructor
      lines.any?(&.includes?("getter ")).should be_true        # Struct properties
    end
  end
end
