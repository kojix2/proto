# proto.cr

[![Test](https://github.com/kojix2/proto/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/proto/actions/workflows/test.yml)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Fproto%2Flines)](https://tokei.kojix2.net/github/kojix2/proto)

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
Nested messages and unknown groups share a default limit of 100 levels;
direct readers can set `max_recursion_depth:`. Malformed lengths, field numbers
and excessive nesting raise `Proto::DecodeError`. Proto3 strings are validated
as UTF-8 during encode and decode; bytes and proto2 strings preserve their bytes.

Regenerate existing `.pb.cr` files to apply generator fixes, including proto2
presence/defaults, wrong-wire-type unknown fields and nesting checks through
merged messages. Fields that conflict with message/runtime methods are escaped
(for example `encode` becomes `encode_`); oneof case names avoid the `NONE`
sentinel. The original protobuf field numbers remain unchanged.

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
