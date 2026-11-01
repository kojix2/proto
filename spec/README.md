# Test layout

Read the runtime from wire primitives to message behavior, then code generation:

| Path | Responsibility |
| --- | --- |
| `wire/` | Varints, scalar values, tags, skipped and unknown fields, packed values and limits |
| `message/` | Serialization, presence, required fields, enums, oneof, extensions and generated-message behavior |
| `open_enum_spec.cr` | Open-enum construction, known/unknown values, hashing and display |
| `bootstrap/` | Descriptor types and protoc request/response serialization |
| `generator/` | Naming, type resolution and FileGenerator features in separate files |
| `integration/` | Building/invoking the protoc plugin and compiling/executing freshly generated programs |
| `support/` | Explicitly required message fixtures and wire helpers; no examples |
| `fixtures/` | Proto schemas, generated messages and golden output |

Each `*_spec.cr` file loads its own dependencies and can run alone. Do not
require another spec file for its fixtures. Hand-written messages live in the
`ProtoSpec` namespace; generated fixtures retain their schema namespaces.

## Adding and ordering examples

- Choose the file by the wire operation or message/generator feature. Put
  regressions beside the behavior they protect rather than collecting them
  chronologically in a generic regression file.
- Use a class or subsystem as the outer `describe`, then a method or coherent
  feature. Keep wire, message, generator and executable-plugin checks separate.
- Order groups and examples as ordinary operation, valid boundaries, then
  invalid input. For presence, distinguish absent values from explicit defaults;
  for enums, show known values before unknown values.
- Give each `it` one independently diagnosable outcome. Keep a round-trip's
  related assertions together. Split absent/false/true optional states and
  strict encode/decode failures into separate examples. For value tables, put
  `it` inside the loop and include the value in its name.
- Keep helpers free of examples, import only the fixtures a file uses, and use
  unique temporary paths with cleanup. No example may depend on another's state.
- Name source-generation assertions as source checks. String matching does not
  establish that generated code compiles. In `integration/generated_code_spec.cr`,
  generate temporary source, compile it against this checkout, then run it to
  exercise message APIs, imports, all RPC metadata shapes and extensions.

The order above is for reading. File names do not encode execution order, and
the suite must also pass with shuffled examples.

## Commands

```sh
crystal spec
crystal spec spec/wire/varint_spec.cr
crystal spec spec/message spec/generator
crystal spec --order 20261101
crystal tool format --check
```
