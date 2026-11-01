require "../support/generated_program"

describe "freshly generated Crystal programs" do
  it "compiles and executes messages, all RPC metadata shapes and extension descriptors together" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "service.proto"
    file.package = "compile_check"
    file.syntax = "proto3"

    request = Proto::Bootstrap::DescriptorProto.new
    request.name = "Request"
    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "id"
    field.number = 1
    field.type = Proto::Bootstrap::FieldType::TYPE_INT32
    request.field << field
    flag = Proto::Bootstrap::FieldDescriptorProto.new
    flag.name = "flag"
    flag.number = 2
    flag.type = Proto::Bootstrap::FieldType::TYPE_BOOL
    flag.proto3_optional = true
    request.field << flag
    file.message_type << request

    reply = Proto::Bootstrap::DescriptorProto.new
    reply.name = "Reply"
    file.message_type << reply
    service = Proto::Bootstrap::ServiceDescriptorProto.new
    service.name = "Echo"
    {"Unary" => {false, false}, "ServerStream" => {false, true},
     "ClientStream" => {true, false}, "Bidi" => {true, true}}.each do |name, flags|
      method = Proto::Bootstrap::MethodDescriptorProto.new
      method.name = name
      method.input_type = ".compile_check.Request"
      method.output_type = ".compile_check.Reply"
      method.client_streaming, method.server_streaming = flags
      service.method << method
    end
    file.service << service
    extension = Proto::Bootstrap::FieldDescriptorProto.new
    extension.name = "rpc_required"
    extension.extendee = ".google.protobuf.MethodOptions"
    extension.number = 50001
    extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL
    file.extension << extension

    result = ProtoCompilationSpec.run([file], <<-CRYSTAL)
      require "./service.pb"
      request = CompileCheck::Request.new
      request.id = 7
      request.flag = false
      decoded = CompileCheck::Request.decode(request.encode)
      raise "message round-trip" unless decoded.id == 7 && decoded.has_flag? && decoded.flag == false
      raise "reply round-trip" unless CompileCheck::Reply.decode(CompileCheck::Reply.new.encode) == CompileCheck::Reply.new
      methods = CompileCheck::Echo::METHODS
      flags = methods.map { |method| {method[:client_streaming], method[:server_streaming]} }
      raise "RPC shapes" unless flags == [{false, false}, {false, true}, {true, false}, {true, true}]
      raise "RPC path" unless methods.first[:path] == "/compile_check.Echo/Unary"
      raise "extension number" unless CompileCheck::Extensions::RPC_REQUIRED.number == 50001
      raise "extension type" unless CompileCheck::Extensions::RPC_REQUIRED.type == Proto::Bootstrap::FieldType::TYPE_BOOL
      raise "extension list" unless CompileCheck::Extensions::ALL.size == 1
      puts "service, messages and extensions passed"
      CRYSTAL
    result.should eq("service, messages and extensions passed\n")
  end

  it "compiles imported proto2 required messages and enforces strict and partial APIs" do
    common = Proto::Bootstrap::FileDescriptorProto.new
    common.name = "nested/common.proto"
    common.package = "compile_check"
    common.syntax = "proto2"
    child = Proto::Bootstrap::DescriptorProto.new
    child.name = "Child"
    value = Proto::Bootstrap::FieldDescriptorProto.new
    value.name = "value"
    value.number = 1
    value.type = Proto::Bootstrap::FieldType::TYPE_INT32
    value.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
    child.field << value
    common.message_type << child

    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "settings.proto"
    file.package = "compile_check"
    file.syntax = "proto2"
    file.dependency << common.name
    settings = Proto::Bootstrap::DescriptorProto.new
    settings.name = "Settings"
    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "child"
    field.number = 1
    field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    field.type_name = ".compile_check.Child"
    field.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
    settings.field << field
    file.message_type << settings

    result = ProtoCompilationSpec.run([common, file], <<-CRYSTAL)
      require "./settings.pb"
      settings = CompileCheck::Settings.new
      child = CompileCheck::Child.new
      child.value = 7
      settings.child = child
      raise "imported message" unless CompileCheck::Settings.decode(settings.encode).child.not_nil!.value == 7
      settings.child = CompileCheck::Child.new
      partial = CompileCheck::Settings.decode_partial(settings.encode_partial)
      raise "partial nested presence" unless partial.has_child? && !partial.child.not_nil!.has_value?
      begin
        CompileCheck::Settings.decode(settings.encode_partial)
        raise "strict decode accepted a missing required value"
      rescue Proto::RequiredFieldError
      end
      begin
        settings.encode
        raise "strict encode accepted a missing required value"
      rescue Proto::RequiredFieldError
      end
      puts "imported required messages passed"
      CRYSTAL
    result.should eq("imported required messages passed\n")
  end
end
