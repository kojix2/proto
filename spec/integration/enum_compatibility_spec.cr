require "../support/generated_program"

private def enum_compat_files : Array(Proto::Bootstrap::FileDescriptorProto)
  bytes = File.read(File.join(__DIR__, "../fixtures/enum_compat/descriptors.pb")).to_slice
  reader = Proto::Wire::Reader.new(IO::Memory.new(bytes))
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

describe "generated enum compatibility" do
  it "uses the declaration's open enum semantics in proto2 messages" do
    ProtoCompilationSpec.run(enum_compat_files, <<-CRYSTAL).should eq("open enum passed\n")
      require "./consumer.pb"
      # Singular unknown value, packed repeated values and a oneof value.
      data = Bytes[8, 123, 18, 2, 1, 123, 24, 123]
      message = EnumAudit::Container.decode(data)
      raise "singular presence" unless message.has_value? && message.value.raw == 123
      raise "packed values" unless message.values.map(&.raw) == [1, 123]
      raise "oneof value" unless message.choice.raw == 123
      raise "unexpected unknown" unless message.unknown_fields.empty?
      restored = EnumAudit::Container.decode(message.encode)
      raise "round trip" unless restored.value.raw == 123 && restored.values.map(&.raw) == [1, 123] && restored.choice.raw == 123
      alias_value = EnumAudit::Container.decode(Bytes[8, 2])
      raise "normalized enum alias" unless alias_value.value.raw == EnumAudit::OpenEnum::MOO.value

      negative = IO::Memory.new
      writer = Proto::Wire::Writer.new(negative)
      writer.write_tag(1, Proto::WireType::VARINT)
      writer.write_int32(-1)
      raise "negative" unless EnumAudit::Container.decode(negative.to_slice).value.raw == -1

      open_map = EnumAudit::Container.decode(Bytes[42, 5, 10, 1, 107, 16, 123])
      raise "open map" unless open_map.open_values["k"].raw == 123 && open_map.unknown_fields.empty?
      puts "open enum passed"
      CRYSTAL
  end

  it "preserves an unknown closed enum map entry on its parent" do
    ProtoCompilationSpec.run(enum_compat_files, <<-CRYSTAL).should eq("closed map passed\n")
      require "./consumer.pb"
      unknown_entry = Bytes[34, 5, 10, 1, 107, 16, 123]
      known_entry = Bytes[34, 5, 10, 1, 107, 16, 1]
      missing_value = Bytes[34, 3, 10, 1, 120]
      message = EnumAudit::Container.decode(unknown_entry + known_entry + missing_value)
      raise "known value" unless message.closed_values["k"] == EnumAudit::ClosedEnum::CLOSED_ONE
      raise "missing value" unless message.closed_values["x"] == EnumAudit::ClosedEnum::CLOSED_ZERO
      raise "entry lost" unless message.unknown_fields.size == 1 && message.unknown_fields.first.data == Bytes[10, 1, 107, 16, 123]
      restored = EnumAudit::Container.decode(message.encode)
      raise "known values lost" unless restored.closed_values == message.closed_values
      raise "unknown entry lost" unless restored.unknown_fields.size == 1 && restored.unknown_fields.first.data == Bytes[10, 1, 107, 16, 123]
      borrowed = unknown_entry.dup
      captured = EnumAudit::Container.decode(borrowed)
      borrowed.fill(0_u8)
      raise "unknown entry aliases input" unless captured.unknown_fields.first.data == Bytes[10, 1, 107, 16, 123]
      puts "closed map passed"
      CRYSTAL
  end
end
