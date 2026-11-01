# proto.cr

[![Test](https://github.com/kojix2/proto/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/proto/actions/workflows/test.yml)

Protocol Buffers runtime and message-code generator for Crystal >= 1.9.
Supports unknown fields, enums, oneof, maps, field presence and extensions.
Use [grpc.cr](https://github.com/kojix2/grpc) for RPC client/server stubs.

## Installation

Add to your application's `shard.yml`, then run `shards install`:

```yaml
dependencies:
  proto:
    github: kojix2/proto
```

## Generate and use messages

Install `protoc`. In your application, save this as `greeting.proto`:

```proto
syntax = "proto3";
package example;
message Greeting { string text = 1; }
```

```sh
mkdir -p bin
crystal build lib/proto/src/protoc-gen-crystal_main.cr -o bin/protoc-gen-crystal
protoc --plugin=protoc-gen-crystal=bin/protoc-gen-crystal --crystal_out=. greeting.proto
```

```crystal
require "./greeting.pb"

message = Example::Greeting.new
message.text = "Hello"
puts Example::Greeting.decode(message.encode).text
```

`encode` / `decode` validate required fields throughout the message tree and
raise `Proto::RequiredFieldError` when a required value is missing. Use
`encode_partial` / `decode_partial` explicitly for incomplete messages.
Presence is exposed through generated `has_*?` and `clear_*` methods.

Wire readers default to 64 MiB per message and 8 MiB per length-delimited field.
Malformed lengths and field numbers raise `Proto::DecodeError`.

## Development

From this checkout:

```sh
shards install
shards build
crystal spec
crystal run examples/basic_roundtrip.cr
```

Tests include compiling and executing freshly generated code. See
[test layout](spec/README.md) and [examples](examples/) for details.

License: MIT, as declared in [shard.yml](shard.yml).
