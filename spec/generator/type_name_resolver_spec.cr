require "../spec_helper"

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

  it "allows FileGenerator to resolve types via type_map resolver" do
    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "mapped.proto"
    file.package = "mypkg"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Wrapper"
    field = Proto::Bootstrap::FieldDescriptorProto.new
    field.name = "payload"
    field.number = 1
    field.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    field.type_name = ".google.protobuf.Empty"
    msg.field << field
    file.message_type << msg

    index = Proto::Generator::TypeIndex.new([file])
    resolver = Proto::Generator::TypeMapNameResolver.new({".google.protobuf.Empty" => "Custom::Empty"})

    code = Proto::Generator::FileGenerator.new(file, index, resolver).generate
    code.should contain("property payload : Custom::Empty? = nil")
    code.should contain("msg.payload = reader.read_embedded(1, wt) do |sub|")
    code.should contain("Custom::Empty.decode_partial(merged)")
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
