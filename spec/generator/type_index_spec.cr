require "../spec_helper"

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
