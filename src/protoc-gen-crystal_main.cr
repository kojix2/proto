#!/usr/bin/env crystal
# protoc-gen-crystal — protoc plugin that generates Crystal message classes
# from .proto files using the new proto.cr runtime.
#
# Usage:
#   protoc --crystal_out=OUTPUT_DIR \
#          --plugin=protoc-gen-crystal \
#          path/to/foo.proto

require "./proto"

# Read a CodeGeneratorRequest from stdin (raw protobuf bytes).
request_bytes = STDIN.gets_to_end.to_slice
request = Proto::Bootstrap::CodeGeneratorRequest.decode(IO::Memory.new(request_bytes))

response = Proto::Bootstrap::CodeGeneratorResponse.new
response.supported_features = Proto::Bootstrap::FEATURE_PROTO3_OPTIONAL

# Build type index from all proto_file entries in the request.
index = Proto::Generator::TypeIndex.new(request.proto_file)

# Generate code for each requested file.
request.file_to_generate.each do |fname|
  proto_file = request.proto_file.find { |file_desc| file_desc.name == fname }
  next unless proto_file

  generator = Proto::Generator::FileGenerator.new(proto_file, index)
  out_file = Proto::Bootstrap::CodeGeneratorResponseFile.new
  out_file.name = generator.output_name
  out_file.content = generator.generate
  response.file << out_file
end

STDOUT.write(response.encode)
STDOUT.flush
