require "../src/proto"

file = Proto::Bootstrap::FileDescriptorProto.new
file.name = "demo.proto"
file.package = "demo"
file.syntax = "proto3"

request = Proto::Bootstrap::DescriptorProto.new
request.name = "PingRequest"
file.message_type << request

reply = Proto::Bootstrap::DescriptorProto.new
reply.name = "PingReply"
file.message_type << reply

service = Proto::Bootstrap::ServiceDescriptorProto.new
service.name = "DemoService"

ping = Proto::Bootstrap::MethodDescriptorProto.new
ping.name = "Ping"
ping.input_type = ".demo.PingRequest"
ping.output_type = ".demo.PingReply"
service.method << ping

watch = Proto::Bootstrap::MethodDescriptorProto.new
watch.name = "Watch"
watch.input_type = ".demo.PingRequest"
watch.output_type = ".demo.PingReply"
watch.server_streaming = true
service.method << watch

file.service << service

extension = Proto::Bootstrap::FieldDescriptorProto.new
extension.name = "rpc_required"
extension.extendee = ".google.protobuf.MethodOptions"
extension.number = 50001
extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL
file.extension << extension

index = Proto::Generator::TypeIndex.new([file])
generator = Proto::Generator::FileGenerator.new(file, index)

puts generator.generate
