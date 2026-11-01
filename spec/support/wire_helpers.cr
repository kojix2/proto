require "../spec_helper"

# Helpers
def encode_varint(value : UInt64) : Bytes
  io = IO::Memory.new
  Proto::Wire::Writer.new(io).write_varint(value)
  io.to_slice
end

def decode_varint(bytes : Bytes) : UInt64
  Proto::Wire::Reader.new(IO::Memory.new(bytes)).read_uint64
end

def roundtrip_varint(value : UInt64) : UInt64
  decode_varint(encode_varint(value))
end

# Minimal test helper that includes HasUnknownFields
class Proto::HasUnknownFieldsCapture
  include Proto::HasUnknownFields
end
