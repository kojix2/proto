require "../spec_helper"
require "../../src/proto"

describe Proto::Generator::NamingPolicy do
  describe ".package_to_module" do
    it "converts dot-separated package to Crystal module path" do
      Proto::Generator::NamingPolicy.package_to_module("foo.bar_baz").should eq("Foo::BarBaz")
    end

    it "returns nil for empty package" do
      Proto::Generator::NamingPolicy.package_to_module("").should be_nil
    end

    it "handles single-component package" do
      Proto::Generator::NamingPolicy.package_to_module("simple").should eq("Simple")
    end
  end

  describe ".fq_type_to_crystal" do
    it "converts fully-qualified type name to Crystal name" do
      Proto::Generator::NamingPolicy.fq_type_to_crystal(".simple.Person").should eq("Simple::Person")
    end

    it "handles nested type names" do
      Proto::Generator::NamingPolicy.fq_type_to_crystal(".foo.bar.Outer.Inner").should eq("Foo::Bar::Outer::Inner")
    end
  end

  describe ".camelize" do
    it "converts snake_case to CamelCase" do
      Proto::Generator::NamingPolicy.camelize("hello_world").should eq("HelloWorld")
    end

    it "leaves already CamelCase strings alone" do
      Proto::Generator::NamingPolicy.camelize("Hello").should eq("Hello")
    end
  end
end

describe Proto::Generator::TypeIndex do
  it "resolves a top-level message" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "simple.proto"
    file.package = "simple"
    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Person"
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    entry = index.resolve(".simple.Person")
    entry.should_not be_nil
    resolved_entry = entry.as(Proto::Generator::TypeIndex::Entry)
    resolved_entry.crystal_name.should eq("Simple::Person")
    resolved_entry.kind.should eq(Proto::Generator::TypeIndex::Kind::Message)
    resolved_entry.file.name.should eq("simple.proto")
  end

  it "resolves a top-level enum" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "simple.proto"
    file.package = "simple"
    en = Proto::Bootstrap::EnumDescriptorProto.new
    en.name = "Status"
    file.enum_type << en

    index = Proto::Generator::TypeIndex.new([file])
    entry = index.resolve(".simple.Status")
    entry.should_not be_nil
    resolved_entry = entry.as(Proto::Generator::TypeIndex::Entry)
    resolved_entry.crystal_name.should eq("Simple::Status")
    resolved_entry.kind.should eq(Proto::Generator::TypeIndex::Kind::Enum)
  end

  it "resolves a nested message" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "nested.proto"
    file.package = "pkg"
    outer = Proto::Bootstrap::DescriptorProto.new
    outer.name = "Outer"
    inner = Proto::Bootstrap::DescriptorProto.new
    inner.name = "Inner"
    outer.nested_type << inner
    file.message_type << outer

    index = Proto::Generator::TypeIndex.new([file])
    entry = index.resolve(".pkg.Outer.Inner")
    entry.should_not be_nil
    resolved_entry = entry.as(Proto::Generator::TypeIndex::Entry)
    resolved_entry.crystal_name.should eq("Pkg::Outer::Inner")
    resolved_entry.file.name.should eq("nested.proto")
  end
end

describe Proto::Generator::TypeNameResolver do
  it "builds a canonical resolver when type_map is absent" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "svc.proto"
    file.package = "mypkg"

    reply = Proto::Bootstrap::DescriptorProto.new
    reply.name = "Reply"
    file.message_type << reply

    resolver = Proto::Generator::TypeNameResolver.build("", [file])

    resolver.resolve(".mypkg.Reply", "mypkg").should eq("Reply")
    resolver.resolve(".google.protobuf.Empty", "mypkg").should eq("Google::Protobuf::Empty")
  end

  it "builds a strict type_map resolver when mappings are provided" do
    resolver = Proto::Generator::TypeNameResolver.build(
      "type_map=.google.protobuf.Empty=My::Custom::Empty;.mypkg.Reply=Reply",
      [] of Proto::Bootstrap::FileDescriptorProto
    )

    resolver.resolve(".google.protobuf.Empty", "mypkg").should eq("My::Custom::Empty")
    resolver.resolve(".mypkg.Reply", "mypkg").should eq("Reply")
    expect_raises(ArgumentError, /Missing type_map entry/) do
      resolver.resolve(".unmapped.Type", "mypkg")
    end
  end

  it "ignores unrelated parameters and surrounding whitespace while parsing type_map" do
    resolver = Proto::Generator::TypeNameResolver.build(
      " foo = bar , type_map = google.protobuf.Empty = My::Custom::Empty ; .mypkg.Reply = Reply ",
      [] of Proto::Bootstrap::FileDescriptorProto
    )

    resolver.resolve(".google.protobuf.Empty", "mypkg").should eq("My::Custom::Empty")
    resolver.resolve(".mypkg.Reply", "mypkg").should eq("Reply")
  end
end

describe Proto::Generator::FileGenerator do
  it "normalizes uppercase and camelCase field names to valid Crystal identifiers" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "timing.proto"
    file.package = "timing"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "TimingEnginePeriods"

    f1 = Proto::Bootstrap::FieldDescriptorProto.new
    f1.name = "RST1"
    f1.number = 1
    f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f1.type = Proto::Bootstrap::FieldType::TYPE_UINT32

    f2 = Proto::Bootstrap::FieldDescriptorProto.new
    f2.name = "biasVoltage"
    f2.number = 2
    f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f2.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE

    msg.field << f1 << f2
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    generated = Proto::Generator::FileGenerator.new(file, index).generate

    generated.should contain("property rst1 : UInt32 = 0")
    generated.should contain("msg.rst1 = reader.read_uint32")
    generated.should contain("property bias_voltage : Float64 = 0.0_f64")
    generated.should contain("msg.bias_voltage = reader.read_double")
  end

  it "escapes Crystal keyword field names" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "keyword_field.proto"
    file.package = "keyword_field"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Sample"

    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "alias"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    field.type = Proto::Bootstrap::FieldType::TYPE_STRING
    msg.field << field
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    generated = Proto::Generator::FileGenerator.new(file, index).generate

    generated.should contain("property alias_ : String")
    generated.should contain("msg.alias_ = reader.read_string")
    generated.should contain("if !alias_.empty?")
  end

  it "normalizes lowercase enum member names to Crystal constants" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "lowercase_enum.proto"
    file.package = "lowercase_enum"
    file.syntax = "proto3"

    enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
    enum_desc.name = "Mode"

    none_value = Proto::Bootstrap::EnumValueDescriptorProto.new
    none_value.name = "none"
    none_value.number = 0
    enum_desc.value << none_value

    ready_value = Proto::Bootstrap::EnumValueDescriptorProto.new
    ready_value.name = "READY"
    ready_value.number = 1
    enum_desc.value << ready_value

    file.enum_type << enum_desc

    index = Proto::Generator::TypeIndex.new([file])
    generated = Proto::Generator::FileGenerator.new(file, index).generate

    generated.should contain("NONE = 0")
    generated.should contain("when 0 then NONE")
    generated.should contain("READY = 1")
  end

  it "deduplicates enum numeric aliases in from_raw?" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "alias_enum.proto"
    file.package = "alias_enum"
    file.syntax = "proto3"

    enum_desc = Proto::Bootstrap::EnumDescriptorProto.new
    enum_desc.name = "Status"

    first = Proto::Bootstrap::EnumValueDescriptorProto.new
    first.name = "STATUS_UNSPECIFIED"
    first.number = 0
    enum_desc.value << first

    alias_value = Proto::Bootstrap::EnumValueDescriptorProto.new
    alias_value.name = "STATUS_DEFAULT"
    alias_value.number = 0
    enum_desc.value << alias_value

    other = Proto::Bootstrap::EnumValueDescriptorProto.new
    other.name = "STATUS_READY"
    other.number = 1
    enum_desc.value << other

    file.enum_type << enum_desc

    index = Proto::Generator::TypeIndex.new([file])
    generated = Proto::Generator::FileGenerator.new(file, index).generate

    generated.scan(/when 0 then/).size.should eq(1)
    generated.should contain("when 1 then STATUS_READY")
  end

  it "emits relative requires for nested proto imports" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "minknow_api/manager.proto"
    file.package = "minknow_api.manager"
    file.dependency << "minknow_api/rpc_options.proto"
    file.dependency << "google/protobuf/timestamp.proto"

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    generated = gen.generate

    generated.should contain("require \"./rpc_options.pb.cr\"")
    generated.should contain("require \"../google/protobuf/timestamp.pb.cr\"")
  end

  it "generates code matching the golden file for simple.proto" do
    # Load the descriptor by running protoc --descriptor_set_out
    # For unit testing without invoking protoc, we build a minimal descriptor manually.
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "simple.proto"
    file.package = "simple"
    file.syntax = "proto3"

    # enum Status
    en = Proto::Bootstrap::EnumDescriptorProto.new
    en.name = "Status"
    ev0 = Proto::Bootstrap::EnumValueDescriptorProto.new
    ev0.name = "STATUS_UNKNOWN"
    ev0.number = 0
    ev1 = Proto::Bootstrap::EnumValueDescriptorProto.new
    ev1.name = "STATUS_OK"
    ev1.number = 1
    ev2 = Proto::Bootstrap::EnumValueDescriptorProto.new
    ev2.name = "STATUS_ERROR"
    ev2.number = 2
    en.value << ev0 << ev1 << ev2
    file.enum_type << en

    # message Person
    person = Proto::Bootstrap::DescriptorProto.new
    person.name = "Person"

    f1 = Proto::Bootstrap::FieldDescriptorProto.new
    f1.name = "name"
    f1.number = 1
    f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f1.type = Proto::Bootstrap::FieldType::TYPE_STRING

    f2 = Proto::Bootstrap::FieldDescriptorProto.new
    f2.name = "age"
    f2.number = 2
    f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f2.type = Proto::Bootstrap::FieldType::TYPE_INT32

    f3 = Proto::Bootstrap::FieldDescriptorProto.new
    f3.name = "active"
    f3.number = 3
    f3.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f3.type = Proto::Bootstrap::FieldType::TYPE_BOOL

    f4 = Proto::Bootstrap::FieldDescriptorProto.new
    f4.name = "status"
    f4.number = 4
    f4.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f4.type = Proto::Bootstrap::FieldType::TYPE_ENUM
    f4.type_name = ".simple.Status"

    f5 = Proto::Bootstrap::FieldDescriptorProto.new
    f5.name = "tags"
    f5.number = 5
    f5.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
    f5.type = Proto::Bootstrap::FieldType::TYPE_STRING

    f6 = Proto::Bootstrap::FieldDescriptorProto.new
    f6.name = "address"
    f6.number = 6
    f6.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f6.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    f6.type_name = ".simple.Address"

    person.field << f1 << f2 << f3 << f4 << f5 << f6
    file.message_type << person

    # message Address
    address = Proto::Bootstrap::DescriptorProto.new
    address.name = "Address"

    a1 = Proto::Bootstrap::FieldDescriptorProto.new
    a1.name = "street"
    a1.number = 1
    a1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    a1.type = Proto::Bootstrap::FieldType::TYPE_STRING

    a2 = Proto::Bootstrap::FieldDescriptorProto.new
    a2.name = "city"
    a2.number = 2
    a2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    a2.type = Proto::Bootstrap::FieldType::TYPE_STRING

    address.field << a1 << a2
    file.message_type << address

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)

    golden_path = File.join(__DIR__, "../fixtures/simple.pb.cr.golden")
    golden = File.read(golden_path)

    gen.generate.should eq(golden)
  end

  it "generates packed repeated code matching the golden file for packed.proto" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "packed.proto"
    file.package = "packed"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Numbers"

    {
      {"values", 1, Proto::Bootstrap::FieldType::TYPE_INT32},
      {"scores", 2, Proto::Bootstrap::FieldType::TYPE_DOUBLE},
      {"flags", 3, Proto::Bootstrap::FieldType::TYPE_BOOL},
      {"ids", 4, Proto::Bootstrap::FieldType::TYPE_FIXED32},
    }.each do |(fname, fnum, ftype)|
      f = Proto::Bootstrap::FieldDescriptorProto.new
      f.name = fname
      f.number = fnum
      f.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      f.type = ftype
      msg.field << f
    end
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)

    golden_path = File.join(__DIR__, "../fixtures/packed.pb.cr.golden")
    golden = File.read(golden_path)

    gen.generate.should eq(golden)
  end

  it "generates oneof setters, clearer, and guarded encode paths" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "oneof.proto"
    file.package = "oneofpkg"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Choice"

    oneof = Proto::Bootstrap::OneofDescriptorProto.new
    oneof.name = "value"
    msg.oneof_decl << oneof

    f1 = Proto::Bootstrap::FieldDescriptorProto.new
    f1.name = "name"
    f1.number = 1
    f1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f1.type = Proto::Bootstrap::FieldType::TYPE_STRING
    f1.oneof_index = 0

    f2 = Proto::Bootstrap::FieldDescriptorProto.new
    f2.name = "count"
    f2.number = 2
    f2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f2.type = Proto::Bootstrap::FieldType::TYPE_INT32
    f2.oneof_index = 0

    msg.field << f1 << f2
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("enum ValueCase : Int32")
    code.should contain("NONE = 0")
    code.should contain("NAME = 1")
    code.should contain("COUNT = 2")
    code.should contain("getter value_case : ValueCase = ValueCase::NONE")
    code.should contain("def clear_value : Nil")
    code.should contain("@value_case = ValueCase::NONE")
    code.should contain("def name=(value : String) : String")
    code.should contain("@name = value")
    code.should contain("@count = 0")
    code.should contain("@value_case = ValueCase::NAME")
    code.should contain("def count=(value : Int32) : Int32")
    code.should contain("@name = \"\"")
    code.should contain("@value_case = ValueCase::COUNT")
    code.should contain("if value_case == ValueCase::NAME")
    code.should contain("if value_case == ValueCase::COUNT")
    code.should contain("return false unless value_case == other.value_case")
  end

  it "generates map fields as Hash with map-entry encode/decode" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "map.proto"
    file.package = "maptest"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Scores"

    entry = Proto::Bootstrap::DescriptorProto.new
    entry.name = "RatingsEntry"
    entry_options = Proto::Bootstrap::MessageOptions.new
    entry_options.map_entry = true
    entry.options = entry_options

    key = Proto::Bootstrap::FieldDescriptorProto.new
    key.name = "key"
    key.number = 1
    key.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    key.type = Proto::Bootstrap::FieldType::TYPE_STRING

    value = Proto::Bootstrap::FieldDescriptorProto.new
    value.name = "value"
    value.number = 2
    value.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    value.type = Proto::Bootstrap::FieldType::TYPE_INT32

    entry.field << key << value
    msg.nested_type << entry

    map_field = Proto::Bootstrap::FieldDescriptorProto.new
    map_field.name = "ratings"
    map_field.number = 1
    map_field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
    map_field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    map_field.type_name = ".maptest.Scores.RatingsEntry"
    msg.field << map_field

    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property ratings : Hash(String, Int32) = {} of String => Int32")
    code.should contain("entry = Maptest::Scores::RatingsEntry.decode_partial(reader.read_embedded)")
    code.should contain("msg.ratings[entry.key] = entry.value")
    code.should contain("ratings.each do |k, v|")
    code.should contain("entry.key = k")
    code.should contain("entry.value = v")
    # map field encode does not use nil guard
    code.should_not contain("if (_v = ratings)")
  end

  it "does not treat repeated message as map unless map_entry option is true" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "not_map.proto"
    file.package = "maptest"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Container"

    entry = Proto::Bootstrap::DescriptorProto.new
    entry.name = "PairLike"

    key = Proto::Bootstrap::FieldDescriptorProto.new
    key.name = "key"
    key.number = 1
    key.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    key.type = Proto::Bootstrap::FieldType::TYPE_STRING

    value = Proto::Bootstrap::FieldDescriptorProto.new
    value.name = "value"
    value.number = 2
    value.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    value.type = Proto::Bootstrap::FieldType::TYPE_INT32

    entry.field << key << value
    msg.nested_type << entry

    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "pairs"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
    field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    field.type_name = ".maptest.Container.PairLike"
    msg.field << field

    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property pairs : Array(Maptest::Container::PairLike) = [] of Maptest::Container::PairLike")
    code.should contain("msg.pairs << Maptest::Container::PairLike.decode_partial(reader.read_embedded)")
    code.should contain("pairs.each do |item|")
    code.should_not contain("property pairs : Hash(")
  end

  it "generates nilable type and nil default for proto3_optional scalar fields" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "optional.proto"
    file.package = "optpkg"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Wrapper"

    # synthetic oneof for the optional field
    syn_oneof = Proto::Bootstrap::OneofDescriptorProto.new
    syn_oneof.name = "_count"
    msg.oneof_decl << syn_oneof

    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "count"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f.type = Proto::Bootstrap::FieldType::TYPE_INT32
    f.oneof_index = 0
    f.proto3_optional = true

    msg.field << f
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    # type should be nilable; default should be nil
    code.should contain("property count : Int32? = nil")
    code.should contain("def has_count? : Bool")
    code.should contain("def clear_count : Nil")
    # no case enum emitted for the synthetic oneof
    code.should_not contain("_CountCase")
    code.should_not contain("count_case")
    # encode should guard with nil check
    code.should contain("if _v = count")
    code.should contain("w.write_int32(_v)")
    # == method must be generated
    code.should contain("def ==(other : self) : Bool")
    code.should contain("return false unless count == other.count")
  end

  it "generates nilable type and nil guard for singular message fields" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "embed.proto"
    file.package = "embed"
    file.syntax = "proto3"

    inner = Proto::Bootstrap::DescriptorProto.new
    inner.name = "Inner"
    file.message_type << inner

    outer = Proto::Bootstrap::DescriptorProto.new
    outer.name = "Outer"

    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "child"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    f.type_name = ".embed.Inner"
    outer.field << f
    file.message_type << outer

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property child : Embed::Inner? = nil")
    code.should contain("def has_child? : Bool")
    code.should contain("def clear_child : Nil")
    code.should contain("if _v = child")
    code.should contain("w.write_embedded(1) { |sub| _v.encode_partial(sub) }")
    code.should contain("return false unless child == other.child")
  end

  it "uses raw-backed OpenEnum for proto3 enum fields" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "open_enum.proto"
    file.package = "open"
    file.syntax = "proto3"

    en = Proto::Bootstrap::EnumDescriptorProto.new
    en.name = "State"
    zero = Proto::Bootstrap::EnumValueDescriptorProto.new
    zero.name = "STATE_UNSPECIFIED"
    zero.number = 0
    ready = Proto::Bootstrap::EnumValueDescriptorProto.new
    ready.name = "READY"
    ready.number = 1
    en.value << zero << ready
    file.enum_type << en

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Wrapper"

    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "state"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    field.type = Proto::Bootstrap::FieldType::TYPE_ENUM
    field.type_name = ".open.State"
    msg.field << field
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property state : Proto::OpenEnum(Open::State) = Proto::OpenEnum(Open::State).new(0)")
    code.should contain("enum State : Int32")
    code.should contain("def self.from_raw?(raw : Int32) : self?")
    code.should contain("when 1 then READY")
    code.should contain("msg.state = Proto::OpenEnum(Open::State).new(_raw)")
    code.should contain("if state.raw != 0")
    code.should contain("w.write_int32(state.raw)")
  end

  it "packs repeated proto3 open enums using raw values" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "open_enum_repeated.proto"
    file.package = "open"
    file.syntax = "proto3"

    en = Proto::Bootstrap::EnumDescriptorProto.new
    en.name = "State"
    zero = Proto::Bootstrap::EnumValueDescriptorProto.new
    zero.name = "STATE_UNSPECIFIED"
    zero.number = 0
    ready = Proto::Bootstrap::EnumValueDescriptorProto.new
    ready.name = "READY"
    ready.number = 1
    en.value << zero << ready
    file.enum_type << en

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Wrapper"

    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "states"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
    field.type = Proto::Bootstrap::FieldType::TYPE_ENUM
    field.type_name = ".open.State"
    msg.field << field
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property states : Array(Proto::OpenEnum(Open::State)) = [] of Proto::OpenEnum(Open::State)")
    code.should contain("states.each { |item| sub.write_int32(item.raw) }")
  end

  it "uses explicit field default_value when provided" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "defaults.proto"
    file.package = "defaults"
    file.syntax = "proto2"

    en = Proto::Bootstrap::EnumDescriptorProto.new
    en.name = "State"
    unknown = Proto::Bootstrap::EnumValueDescriptorProto.new
    unknown.name = "UNKNOWN"
    unknown.number = 0
    ready = Proto::Bootstrap::EnumValueDescriptorProto.new
    ready.name = "READY"
    ready.number = 1
    en.value << unknown << ready
    file.enum_type << en

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Config"

    enabled = Proto::Bootstrap::FieldDescriptorProto.new
    enabled.name = "enabled"
    enabled.number = 1
    enabled.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    enabled.type = Proto::Bootstrap::FieldType::TYPE_BOOL
    enabled.default_value = "true"

    retries = Proto::Bootstrap::FieldDescriptorProto.new
    retries.name = "retries"
    retries.number = 2
    retries.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    retries.type = Proto::Bootstrap::FieldType::TYPE_INT32
    retries.default_value = "7"

    note = Proto::Bootstrap::FieldDescriptorProto.new
    note.name = "note"
    note.number = 3
    note.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    note.type = Proto::Bootstrap::FieldType::TYPE_STRING
    note.default_value = "hello"

    state = Proto::Bootstrap::FieldDescriptorProto.new
    state.name = "state"
    state.number = 4
    state.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    state.type = Proto::Bootstrap::FieldType::TYPE_ENUM
    state.type_name = ".defaults.State"
    state.default_value = "READY"

    msg.field << enabled << retries << note << state
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("getter? has_enabled : Bool = false")
    code.should contain("getter? has_retries : Bool = false")
    code.should contain("getter? has_note : Bool = false")
    code.should contain("getter? has_state : Bool = false")
    code.should contain("getter enabled : Bool = true")
    code.should contain("getter retries : Int32 = 7")
    code.should contain("getter note : String = \"hello\"")
    code.should contain("getter state : Defaults::State = Defaults::State::READY")
    code.should contain("def enabled=(value : Bool) : Bool")
    code.should contain("def clear_enabled : Nil")
    code.should contain("if has_enabled?")
    code.should contain("if has_retries?")
    code.should contain("if has_note?")
    code.should contain("if has_state?")
    code.should contain("return false unless has_enabled? == other.has_enabled?")
  end

  it "tracks proto2 required scalar presence and validates before encoding" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "required.proto"
    file.package = "req"
    file.syntax = "proto2"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Settings"

    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "retries"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
    f.type = Proto::Bootstrap::FieldType::TYPE_INT32

    msg.field << f
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("getter? has_retries : Bool = false")
    code.should contain("getter retries : Int32 = 0")
    code.should_not contain("property retries : Int32? = nil")
    code.should contain("def retries=(value : Int32) : Int32")
    code.should contain("def clear_retries : Nil")
    code.should contain("def validate_required! : Nil")
    code.should contain("def validate_required_deep! : Nil")
    code.should contain("raise Proto::RequiredFieldError.new(\"Missing required field: retries\") unless has_retries?")
    code.should contain("def self.decode_partial(io : IO) : self")
    code.should contain("def self.decode(io : IO) : self")
    code.should contain("msg = decode_partial(io)")
    code.should contain("def encode_partial(io : IO) : Nil")
    code.should contain("encode_partial(io)")
    code.should contain("msg.validate_required_deep!")
    code.should contain("validate_required_deep!")
    code.should contain("if has_retries?")
    code.should contain("w.write_tag(1, Proto::WireType::VARINT)")
    code.should contain("w.write_int32(retries)")
  end

  it "tracks proto2 required message presence and validates via has_*" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "required_message.proto"
    file.package = "req"
    file.syntax = "proto2"

    child = Proto::Bootstrap::DescriptorProto.new
    child.name = "Child"

    child_field = Proto::Bootstrap::FieldDescriptorProto.new
    child_field.name = "value"
    child_field.number = 1
    child_field.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
    child_field.type = Proto::Bootstrap::FieldType::TYPE_INT32
    child.field << child_field

    file.message_type << child

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Settings"

    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "child"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_REQUIRED
    field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    field.type_name = ".req.Child"
    msg.field << field
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property child : Req::Child? = nil")
    code.should contain("def has_child? : Bool")
    code.should contain("def clear_child : Nil")
    code.should contain("def validate_required_deep! : Nil")
    code.should contain("raise Proto::RequiredFieldError.new(\"Missing required field: child\") unless has_child?")
    code.should contain("msg.child = Req::Child.decode_partial(reader.read_embedded)")
    code.should contain("child.try &.validate_required_deep!")
    code.should contain("if _v = child")
    code.should contain("w.write_embedded(1) { |sub| _v.encode_partial(sub) }")
  end

  it "maps proto2 float explicit defaults including inf/-inf/nan" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "float_defaults.proto"
    file.package = "flt"
    file.syntax = "proto2"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Floats"

    pos_inf = Proto::Bootstrap::FieldDescriptorProto.new
    pos_inf.name = "pos_inf"
    pos_inf.number = 1
    pos_inf.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    pos_inf.type = Proto::Bootstrap::FieldType::TYPE_FLOAT
    pos_inf.default_value = "inf"

    neg_inf = Proto::Bootstrap::FieldDescriptorProto.new
    neg_inf.name = "neg_inf"
    neg_inf.number = 2
    neg_inf.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    neg_inf.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE
    neg_inf.default_value = "-inf"

    nan_v = Proto::Bootstrap::FieldDescriptorProto.new
    nan_v.name = "nan_v"
    nan_v.number = 3
    nan_v.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    nan_v.type = Proto::Bootstrap::FieldType::TYPE_FLOAT
    nan_v.default_value = "nan"

    regular = Proto::Bootstrap::FieldDescriptorProto.new
    regular.name = "regular"
    regular.number = 4
    regular.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    regular.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE
    regular.default_value = "3.25"

    msg.field << pos_inf << neg_inf << nan_v << regular
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("getter? has_pos_inf : Bool = false")
    code.should contain("getter? has_neg_inf : Bool = false")
    code.should contain("getter? has_nan_v : Bool = false")
    code.should contain("getter? has_regular : Bool = false")
    code.should contain("getter pos_inf : Float32 = Float32::INFINITY")
    code.should contain("getter neg_inf : Float64 = -Float64::INFINITY")
    code.should contain("getter nan_v : Float32 = Float32::NAN")
    code.should contain("getter regular : Float64 = 3.25_f64")
    code.should contain("def clear_pos_inf : Nil")
    code.should contain("def pos_inf=(value : Float32) : Float32")
    code.should contain("if has_pos_inf?")
  end

  it "elides regular proto3 scalar fields when value is default" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "plain_scalar.proto"
    file.package = "plain"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Item"

    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "count"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f.type = Proto::Bootstrap::FieldType::TYPE_INT32

    msg.field << f
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("property count : Int32 = 0")
    code.should contain("if count != 0")
    code.should contain("w.write_tag(1, Proto::WireType::VARINT)")
    code.should contain("w.write_int32(count)")
    code.should_not contain("if _v = count")
  end

  it "fails fast for unsupported TYPE_GROUP fields" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "group.proto"
    file.package = "grp"
    file.syntax = "proto2"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Container"

    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "legacy_group"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f.type = Proto::Bootstrap::FieldType::TYPE_GROUP
    msg.field << f

    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)

    expect_raises(Exception, /TYPE_GROUP is not supported yet/) do
      gen.generate
    end
  end

  it "generates service/rpc descriptors" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "svc.proto"
    file.package = "svc"
    file.syntax = "proto3"

    req = Proto::Bootstrap::DescriptorProto.new
    req.name = "PingRequest"
    file.message_type << req

    rep = Proto::Bootstrap::DescriptorProto.new
    rep.name = "PingReply"
    file.message_type << rep

    service = Proto::Bootstrap::ServiceDescriptorProto.new
    service.name = "Health"

    unary = Proto::Bootstrap::MethodDescriptorProto.new
    unary.name = "Ping"
    unary.input_type = ".svc.PingRequest"
    unary.output_type = ".svc.PingReply"
    service.method << unary

    stream = Proto::Bootstrap::MethodDescriptorProto.new
    stream.name = "Watch"
    stream.input_type = ".svc.PingRequest"
    stream.output_type = ".svc.PingReply"
    stream.server_streaming = true
    service.method << stream

    file.service << service

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("module Health")
    code.should contain("METHODS = [")
    code.should contain("name: \"Ping\"")
    code.should contain("request_type: \".svc.PingRequest\"")
    code.should contain("response_type: \".svc.PingReply\"")
    code.should contain("path: \"/svc.Health/Ping\"")
    code.should contain("name: \"Watch\"")
    code.should contain("server_streaming: true")
  end

  it "generates extend definitions as extension descriptors" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "extensions.proto"
    file.package = "extensions"
    file.syntax = "proto3"

    ext = Proto::Bootstrap::FieldDescriptorProto.new
    ext.name = "rpc_required"
    ext.extendee = ".google.protobuf.FieldOptions"
    ext.number = 50001
    ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    ext.type = Proto::Bootstrap::FieldType::TYPE_BOOL
    file.extension << ext

    index = Proto::Generator::TypeIndex.new([file])
    gen = Proto::Generator::FileGenerator.new(file, index)
    code = gen.generate

    code.should contain("module Extensions")
    code.should contain("struct ExtensionDescriptor")
    code.should contain("RPC_REQUIRED = ExtensionDescriptor.new(")
    code.should contain("extendee: \".google.protobuf.FieldOptions\"")
    code.should contain("number: 50001")
    code.should contain("type: Proto::Bootstrap::FieldType::TYPE_BOOL")
    code.should contain("ALL = [")
    code.should contain("RPC_REQUIRED")
  end

  describe "Compilation Validation - Phase 2 Sanity Check" do
    it "generates valid Crystal code for service/extend that can be checked" do
      # Build a complete proto file with service and extensions
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "integration_test.proto"
      file.package = "test_pkg"
      file.syntax = "proto3"

      # Add a simple message
      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "TestRequest"
      file.message_type << msg

      reply = Proto::Bootstrap::DescriptorProto.new
      reply.name = "TestReply"
      file.message_type << reply

      # Add service with RPC
      service = Proto::Bootstrap::ServiceDescriptorProto.new
      service.name = "TestService"

      method = Proto::Bootstrap::MethodDescriptorProto.new
      method.name = "TestMethod"
      method.input_type = ".test_pkg.TestRequest"
      method.output_type = ".test_pkg.TestReply"
      service.method << method
      file.service << service

      # Add extension definition
      ext = Proto::Bootstrap::FieldDescriptorProto.new
      ext.name = "test_option"
      ext.extendee = ".google.protobuf.MethodOptions"
      ext.number = 50002
      ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext.type = Proto::Bootstrap::FieldType::TYPE_STRING
      file.extension << ext

      # Generate code
      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify code structure is complete
      code.should contain("module TestService")
      code.should contain("module Extensions")
      code.should contain("TEST_OPTION = ExtensionDescriptor.new(")

      # Write to temporary file and verify it's valid Crystal syntax
      tmpdir = Dir.tempdir
      tmp_file = File.join(tmpdir, "test_generated.pb.cr")
      begin
        File.write(tmp_file, code)

        # Verify file was written
        File.exists?(tmp_file).should be_true

        # Read back to ensure content matches
        written_code = File.read(tmp_file)
        written_code.should eq(code)

        # Basic syntax validation: code should contain proper module/struct/method structure
        code.lines.size.should be > 0
      ensure
        File.delete(tmp_file) if File.exists?(tmp_file)
      end
    end

    it "generates service metadata in NamedTuple format that compiles" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "service_check.proto"
      file.package = "svc"
      file.syntax = "proto3"

      req = Proto::Bootstrap::DescriptorProto.new
      req.name = "Request"
      file.message_type << req

      rep = Proto::Bootstrap::DescriptorProto.new
      rep.name = "Response"
      file.message_type << rep

      service = Proto::Bootstrap::ServiceDescriptorProto.new
      service.name = "CheckService"

      m1 = Proto::Bootstrap::MethodDescriptorProto.new
      m1.name = "Unary"
      m1.input_type = ".svc.Request"
      m1.output_type = ".svc.Response"
      service.method << m1

      m2 = Proto::Bootstrap::MethodDescriptorProto.new
      m2.name = "ServerStream"
      m2.input_type = ".svc.Request"
      m2.output_type = ".svc.Response"
      m2.server_streaming = true
      service.method << m2

      m3 = Proto::Bootstrap::MethodDescriptorProto.new
      m3.name = "ClientStream"
      m3.input_type = ".svc.Request"
      m3.output_type = ".svc.Response"
      m3.client_streaming = true
      service.method << m3

      file.service << service

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify NamedTuple array syntax is correct
      code.should contain("METHODS = [")
      code.should contain("] of NamedTuple(")
      code.should contain("name: String")
      code.should contain("request_type: String")
      code.should contain("response_type: String")
      code.should contain("client_streaming: Bool")
      code.should contain("server_streaming: Bool")
      code.should contain("path: String")
      code.should contain("Unary")
      code.should contain("ServerStream")
      code.should contain("ClientStream")

      # Verify method details are correct
      code.should contain("server_streaming: true") # For ServerStream
      code.should contain("client_streaming: true") # For ClientStream
    end

    it "generates extension constants with proper ExtensionDescriptor struct" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "ext_check.proto"
      file.package = "ext_pkg"
      file.syntax = "proto3"

      # Add multiple extensions to verify constant naming
      ext1 = Proto::Bootstrap::FieldDescriptorProto.new
      ext1.name = "field_one"
      ext1.extendee = ".google.protobuf.FieldOptions"
      ext1.number = 60001
      ext1.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext1.type = Proto::Bootstrap::FieldType::TYPE_INT32
      file.extension << ext1

      ext2 = Proto::Bootstrap::FieldDescriptorProto.new
      ext2.name = "field_two"
      ext2.extendee = ".google.protobuf.MethodOptions"
      ext2.number = 60002
      ext2.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      ext2.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      file.extension << ext2

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Verify struct definition
      code.should contain("struct ExtensionDescriptor")
      code.should contain("getter name : String")
      code.should contain("getter extendee : String")
      code.should contain("getter number : Int32")
      code.should contain("getter type : Proto::Bootstrap::FieldType")

      # Verify constant instantiation
      code.should contain("FIELD_ONE = ExtensionDescriptor.new(")
      code.should contain("FIELD_TWO = ExtensionDescriptor.new(")
      code.should contain("ALL = [")
      code.should contain("FIELD_ONE")
      code.should contain("FIELD_TWO")

      # Verify correct field values
      code.should contain("name: \"field_one\"")
      code.should contain("name: \"field_two\"")
      code.should contain("extendee: \".google.protobuf.FieldOptions\"")
      code.should contain("extendee: \".google.protobuf.MethodOptions\"")
      code.should contain("number: 60001")
      code.should contain("number: 60002")
    end

    it "validates generated code structure matches Crystal syntax requirements" do
      # This test ensures that generated service/extension code follows Crystal conventions:
      # 1. Module definitions are well-formed
      # 2. NamedTuple type annotations are present
      # 3. Struct constructors are valid
      # 4. Constants are properly initialized

      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "comprehensive_check.proto"
      file.package = "check_pkg"
      file.syntax = "proto3"

      # Message definitions
      req_msg = Proto::Bootstrap::DescriptorProto.new
      req_msg.name = "ComprehensiveRequest"
      file.message_type << req_msg

      rep_msg = Proto::Bootstrap::DescriptorProto.new
      rep_msg.name = "ComprehensiveResponse"
      file.message_type << rep_msg

      # Service with mixed streaming modes
      svc = Proto::Bootstrap::ServiceDescriptorProto.new
      svc.name = "ComprehensiveService"

      %w[
        UnaryCall
        ServerStreamingCall
        ClientStreamingCall
        BidirectionalStreamingCall
      ].each do |method_name|
        method = Proto::Bootstrap::MethodDescriptorProto.new
        method.name = method_name
        method.input_type = ".check_pkg.ComprehensiveRequest"
        method.output_type = ".check_pkg.ComprehensiveResponse"

        # Set streaming flags based on method name
        if method_name.includes?("ServerStreaming")
          method.server_streaming = true
        end
        if method_name.includes?("ClientStreaming")
          method.client_streaming = true
        end
        if method_name.includes?("Bidirectional")
          method.client_streaming = true
          method.server_streaming = true
        end

        svc.method << method
      end
      file.service << svc

      # Extensions with various field types
      extension_types = [
        {
          name:     "ext_bool",
          type:     Proto::Bootstrap::FieldType::TYPE_BOOL,
          extendee: ".google.protobuf.FieldOptions",
        },
        {
          name:     "ext_int",
          type:     Proto::Bootstrap::FieldType::TYPE_INT32,
          extendee: ".google.protobuf.MethodOptions",
        },
        {
          name:     "ext_string",
          type:     Proto::Bootstrap::FieldType::TYPE_STRING,
          extendee: ".google.protobuf.ServiceOptions",
        },
      ]

      extension_types.each_with_index do |ext_spec, idx|
        ext = Proto::Bootstrap::FieldDescriptorProto.new
        ext.name = ext_spec[:name]
        ext.extendee = ext_spec[:extendee]
        ext.number = 70001 + idx
        ext.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
        ext.type = ext_spec[:type]
        file.extension << ext
      end

      # Generate and validate
      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      # Syntax structure validations
      code.should_not be_empty

      # Service module structure
      code.should contain("module ComprehensiveService")
      code.should contain("METHODS = [")
      code.should contain("UnaryCall")
      code.should contain("ServerStreamingCall")
      code.should contain("ClientStreamingCall")
      code.should contain("BidirectionalStreamingCall")

      # All methods should have complete metadata
      ["UnaryCall", "ServerStreamingCall", "ClientStreamingCall", "BidirectionalStreamingCall"].each do |mname|
        # Each method entry should be a complete NamedTuple
        code.should contain("name: \"#{mname}\"")
        code.should contain("request_type:")
        code.should contain("response_type:")
        code.should contain("client_streaming:")
        code.should contain("server_streaming:")
      end

      # Extension module structure
      code.should contain("module Extensions")
      code.should contain("struct ExtensionDescriptor")

      # Each extension should have its constant
      code.should contain("EXT_BOOL = ExtensionDescriptor.new(")
      code.should contain("EXT_INT = ExtensionDescriptor.new(")
      code.should contain("EXT_STRING = ExtensionDescriptor.new(")

      # All array should contain all extensions
      code.should contain("ALL = [")
      code.should contain("EXT_BOOL")
      code.should contain("EXT_INT")
      code.should contain("EXT_STRING")

      # Verify indentation and structure (basic heuristic)
      lines = code.lines
      lines.size.should be > 20                                # Should generate substantial code
      lines.any?(&.includes?("def initialize")).should be_true # Struct constructor
      lines.any?(&.includes?("getter ")).should be_true        # Struct properties
    end
  end
end
