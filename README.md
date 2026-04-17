# proto.cr

protobuf runtime and protoc plugin for Crystal.
This library was generated using an AI agent.

- IO-based encode/decode
- unknown field preservation
- strict / partial wire APIs for required-field workflows
- open enum support for proto3-style unknown enum values
- .pb.cr generation via protoc plugin
- service/rpc metadata generation
- extension metadata generation

## Installation

### Shards (local path)

```yaml
dependencies:
  proto:
    path: ../proto.cr
```

### Shards (GitHub)

```yaml
dependencies:
  proto:
    github: kojix2/proto.cr
```

## Build plugin

```sh
crystal build src/protoc-gen-crystal_main.cr -o bin/protoc-gen-crystal
```

## Generate .pb.cr

```sh
protoc --plugin=protoc-gen-crystal=bin/protoc-gen-crystal \
  --crystal_out=. path/to/example.proto
```

Generated .pb.cr files include:

- message / enum definitions
- RPC metadata for each service
- extension metadata at file and message scope

Client/server stubs are not generated for services themselves. For gRPC stubs, use grpc.cr's protoc-gen-crystal-grpc.

## Runtime usage

```crystal
require "proto"
require "./example.pb.cr"

msg = Example::HelloRequest.new
msg.name = "Alice"

bytes = msg.encode
parsed = Example::HelloRequest.decode(bytes)
puts parsed.name
```

Generated message types expose two wire-level API layers:

- `decode` / `encode`: strict APIs that validate required fields across the full message tree
- `decode_partial` / `encode_partial`: explicit partial APIs for working with incomplete messages

Strict validation failures raise `Proto::RequiredFieldError`, which is a `Proto::ValidationError`.

```crystal
begin
  parsed = Example::Settings.decode(bytes)
rescue ex : Proto::RequiredFieldError
  puts ex.message
end
```

For proto2-style required fields, generated code keeps the value surface non-nilable where practical
and exposes presence separately:

```crystal
settings = Example::Settings.new
settings.retries = 3
settings.has_retries? # => true
settings.clear_retries
settings.has_retries? # => false
```

## Examples

Minimal self-contained example:

```sh
crystal run examples/basic_roundtrip.cr
```

Example output:

```text
encoded bytes: 9
decoded id: 42
decoded name: Alice
```

Strict vs partial required-field example:

```sh
crystal run examples/required_strict_partial.cr
```

Example output:

```text
strict encode error: Missing required field: value
partial bytes: 2
strict decode error: Missing required field: value
partial child present?: true
partial child has_value?: false
```

Example for service metadata / extension metadata generation:

```sh
crystal run examples/service_extensions_codegen.cr
```

This example constructs descriptors inline and shows that the generated code includes output like the following.

```crystal
module DemoService
  METHODS = [
    {
      name: "Ping",
      request_type: ".demo.PingRequest",
      response_type: ".demo.PingReply",
      client_streaming: false,
      server_streaming: false,
      path: "/demo.DemoService/Ping",
    },
  ] of NamedTuple(name: String, request_type: String, response_type: String, client_streaming: Bool, server_streaming: Bool, path: String)
end

module Extensions
  RPC_REQUIRED = ExtensionDescriptor.new(
    name: "rpc_required",
    extendee: ".google.protobuf.MethodOptions",
    number: 50001,
    label: Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL,
    type: Proto::Bootstrap::FieldType::TYPE_BOOL,
    type_name: "",
  )
end
```

## Testing

```sh
crystal spec
```

## Notes

- gRPC service stubs are out of scope.
- Services are generated as RPC metadata.
- Extensions are generated as descriptor metadata, not as interpreted option logic.
- For gRPC support, use grpc.cr's protoc-gen-crystal-grpc.
