require "../support/generated_program"
require "../support/audit_descriptors"

describe "protoc proto2 descriptors" do
  it "retains required and optional presence when protoc omits the syntax field" do
    files = ProtoAuditSpec.files.reject { |file| file.name == "runtime.proto" }
    files.find { |file| file.name == "defaults.proto" }.try(&.syntax).should eq("")
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("presence passed\n")
      require "./defaults.pb"
      item = AuditDefaults::Config.new
      raise "required presence" if item.has_id?
      raise "optional presence" if item.has_enabled?
      raise "default" unless item.enabled
      raise "partial output" unless item.encode_partial.empty?
      begin
        item.encode
        raise "required encode accepted"
      rescue Proto::RequiredFieldError
      end
      begin
        AuditDefaults::Config.decode(Bytes.empty)
        raise "required decode accepted"
      rescue Proto::RequiredFieldError
      end
      item.id = 0
      item.enabled = false
      copy = AuditDefaults::Config.decode(item.encode)
      raise "explicit zero" unless copy.has_id? && copy.id == 0
      raise "explicit false" unless copy.has_enabled? && !copy.enabled
      copy.clear_enabled
      raise "clear" if copy.has_enabled?
      raise "reset default" unless copy.enabled
      puts "presence passed"
      CRYSTAL
  end

  it "uses bytes escapes and local, imported, nested and normalized enum defaults" do
    files = ProtoAuditSpec.files.reject { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("defaults passed\n")
      require "./defaults.pb"
      item = AuditDefaults::Config.decode_partial(Bytes.empty)
      raise "bytes default" unless item.blob == Bytes[0, 1, 65, 255, 34, 92, 10, 127]
      raise "enum first" unless item.stage.value == 7
      raise "enum imported first" unless item.imported_stage.value == 11
      raise "enum nested first" unless item.nested_stage.value == 13
      raise "lowercase enum default" unless item.state == AuditDefaults::State::READY
      item.id = 1
      item.blob = Bytes[255]
      copy = AuditDefaults::Config.decode(item.encode)
      raise "bytes round-trip" unless copy.blob == Bytes[255]
      copy.clear_blob
      raise "clear bytes default" unless copy.blob == Bytes[0, 1, 65, 255, 34, 92, 10, 127]
      puts "defaults passed"
      CRYSTAL
  end

  it "lists the actual extension constants after duplicate leaf names and ALL are disambiguated" do
    files = ProtoAuditSpec.files.reject { |file| file.name == "runtime.proto" }
    ProtoCompilationSpec.run(files, <<-CRYSTAL).should eq("extensions passed\n")
      require "./defaults.pb"
      extensions = AuditDefaults::Extensions::ALL
      raise "extension numbers" unless extensions.map(&.number).sort == [100, 101, 102, 103]
      raise "unique descriptors" unless extensions.size == 4
      puts "extensions passed"
      CRYSTAL
  end
end
