require "../spec_helper"

module ProtoAuditSpec
  # Checked-in FileDescriptorSet produced by real protoc, including omitted
  # proto2 syntax values. No external protoc is needed to execute these specs.
  def self.files : Array(Proto::Bootstrap::FileDescriptorProto)
    reader = Proto::Wire::Reader.new(IO::Memory.new(File.read(File.join(__DIR__, "../fixtures/audit/descriptors.pb")).to_slice))
    files = [] of Proto::Bootstrap::FileDescriptorProto
    while tag = reader.read_tag
      if tag == {1, Proto::WireType::LENGTH_DELIMITED}
        files << Proto::Bootstrap::FileDescriptorProto.decode(reader.read_embedded)
      else
        reader.skip_tag(tag)
      end
    end
    files
  end
end
