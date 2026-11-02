require "../support/generated_program"
require "../support/audit_descriptors"

describe "freshly generated runtime compatibility" do
  it "preserves serialization APIs and disambiguates the oneof NONE sentinel" do
    files = ProtoAuditSpec.files.select { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("names passed\n")
      require "./runtime.pb"
      item = AuditRuntime::Item.new
      item.encode_ = 1
      item.encode_partial_ = 2
      item.validate_required_ = 3
      item.validate_required_deep_ = 4
      item.unknown_fields_ = 5
      item.capture_unknown_field_ = 6
      item.extension_values_ = 7
      item.none = 8
      raise "sentinel selected" if item.choice_case == AuditRuntime::Item::ChoiceCase::NONE
      copy = AuditRuntime::Item.decode(item.encode)
      raise "runtime field round-trip" unless copy == item
      copy.none_8 = 10
      raise "oneof replacement" unless copy.none == 0 && copy.none_8 == 10
      copy.clear_choice
      raise "sentinel clear" unless copy.choice_case == AuditRuntime::Item::ChoiceCase::NONE
      copy.validate_required!
      copy.validate_required_deep!
      puts "names passed"
      CRYSTAL
  end

  it "truncates int32 and enum values identically for singular, packed and unpacked input" do
    files = ProtoAuditSpec.files.select { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("integers passed\n")
      require "./runtime.pb"
      raw = Bytes[0x80, 0x80, 0x80, 0x80, 0x10]
      data = Bytes[8] + raw + Bytes[16] + raw + Bytes[18, 5] + raw + Bytes[24] + raw + Bytes[32] + raw + Bytes[34, 5] + raw
      item = AuditRuntime::Numbers.decode(data)
      raise "singular" unless item.value == 0
      raise "repeated" unless item.values == [0, 0]
      raise "enum singular" unless item.state.raw == 0
      raise "enum repeated" unless item.states.map(&.raw) == [0, 0]
      puts "integers passed"
      CRYSTAL
  end

  it "validates proto3 UTF-8 while keeping bytes and proto2 strings byte-preserving" do
    ProtoCompilationSpec.run(ProtoAuditSpec.files, <<-CRYSTAL).should eq("UTF-8 passed\n")
      require "./runtime.pb"
      require "./defaults.pb"
      begin
        AuditRuntime::Numbers.decode(Bytes[42, 1, 255])
        raise "invalid UTF-8 decode accepted"
      rescue Proto::DecodeError
      end
      item = AuditRuntime::Numbers.new
      item.text = String.new(Bytes[255])
      begin
        item.encode
        raise "invalid UTF-8 encode accepted"
      rescue Proto::EncodeError
      end
      item.text = "日本語"
      item.data = Bytes[255]
      raise "valid UTF-8" unless AuditRuntime::Numbers.decode(item.encode) == item
      proto2 = AuditDefaults::Config.decode_partial(Bytes[66, 1, 255])
      raise "proto2 preservation" unless proto2.text.to_slice == Bytes[255]
      raise "proto2 encode" unless proto2.encode_partial == Bytes[66, 1, 255]
      puts "UTF-8 passed"
      CRYSTAL
  end

  it "preserves a known field number with an incompatible wire type as unknown" do
    files = ProtoAuditSpec.files.select { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("unknown wire type passed\n")
      require "./runtime.pb"
      wire = Bytes[10, 1, 97]
      item = AuditRuntime::Numbers.decode(wire)
      raise "known default" unless item.value == 0
      raise "unknown capture" unless item.unknown_fields.size == 1
      raise "unknown round-trip" unless item.encode == wire
      puts "unknown wire type passed"
      CRYSTAL
  end

  it "bounds recursion through singular, repeated, merged messages and unknown groups" do
    files = ProtoAuditSpec.files.select { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("recursion passed\n")
      require "./runtime.pb"
      def nested_wire(depth : Int32, repeated : Bool, merge : Bool) : Bytes
        wire = Bytes.empty
        depth.times do
          io = IO::Memory.new
          writer = Proto::Wire::Writer.new(io)
          writer.write_tag(repeated ? 2 : 1, Proto::WireType::LENGTH_DELIMITED)
          if merge && !repeated
            writer.write_bytes(Bytes.empty)
            writer.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
          end
          writer.write_bytes(wire)
          wire = io.to_slice
        end
        wire
      end
      {false, true}.each do |repeated|
        {false, true}.each do |merge|
          AuditRuntime::Node.decode(nested_wire(20, repeated, merge))
          begin
            AuditRuntime::Node.decode(nested_wire(101, repeated, merge))
            raise "unbounded known recursion"
          rescue Proto::DecodeError
          end
        end
      end
      mixed = Bytes[0x1b, 0x1c]
      100.times do
        io = IO::Memory.new
        Proto::Wire::Writer.new(io).write_bytes(mixed)
        mixed = Bytes[10] + io.to_slice
      end
      begin
        AuditRuntime::Node.decode(mixed)
        raise "mixed recursion budget bypassed"
      rescue Proto::DecodeError
      end
      puts "recursion passed"
      CRYSTAL
  end
end
