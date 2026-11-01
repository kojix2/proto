require "../spec_helper"
require "file_utils"
require "../../src/proto/bootstrap/plugin"

describe "protoc plugin integration" do
  it "plugin binary handles an empty request and emits a valid response" do
    # Ensure the plugin binary is built from the current source to avoid
    # stale artifacts causing false negatives.
    plugin_src = "#{__DIR__}/../../src/protoc-gen-crystal_main.cr"
    plugin_bin = "#{__DIR__}/../../bin/protoc-gen-crystal"
    FileUtils.mkdir_p(File.dirname(plugin_bin))
    build = Process.new(
      "crystal",
      ["build", plugin_src, "-o", plugin_bin],
      output: Process::Redirect::Close,
      error: Process::Redirect::Pipe,
    )
    build_err = build.error.gets_to_end
    build_status = build.wait
    build_status.success?.should(
      be_true,
      "failed to build plugin binary: #{build_err}"
    )

    # Build an empty CodeGeneratorRequest
    req = Proto::Bootstrap::CodeGeneratorRequest.new
    req_bytes = IO::Memory.new
    req.encode(req_bytes)

    # Run the plugin binary
    proc = Process.new(
      plugin_bin,
      input: IO::Memory.new(req_bytes.to_slice),
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Pipe,
    )
    resp_bytes = proc.output.gets_to_end.to_slice
    proc.wait

    resp = Proto::Bootstrap::CodeGeneratorResponse.decode(IO::Memory.new(resp_bytes))
    resp.error.should eq ""
    resp.supported_features.should eq Proto::Bootstrap::FEATURE_PROTO3_OPTIONAL
  end

  it "applies type_map from request parameter during generation" do
    plugin_src = "#{__DIR__}/../../src/protoc-gen-crystal_main.cr"
    plugin_bin = "#{__DIR__}/../../bin/protoc-gen-crystal"
    FileUtils.mkdir_p(File.dirname(plugin_bin))
    build = Process.new(
      "crystal",
      ["build", plugin_src, "-o", plugin_bin],
      output: Process::Redirect::Close,
      error: Process::Redirect::Pipe,
    )
    build_err = build.error.gets_to_end
    build_status = build.wait
    build_status.success?.should(
      be_true,
      "failed to build plugin binary: #{build_err}"
    )

    req = Proto::Bootstrap::CodeGeneratorRequest.new
    req.file_to_generate << "mapped.proto"
    req.parameter = "type_map=.google.protobuf.Empty=Custom::Empty"

    file = Proto::Bootstrap::FileDescriptorProto.new
    file.name = "mapped.proto"
    file.package = "mapped"
    file.syntax = "proto3"

    msg = Proto::Bootstrap::DescriptorProto.new
    msg.name = "Wrapper"
    f = Proto::Bootstrap::FieldDescriptorProto.new
    f.name = "payload"
    f.number = 1
    f.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
    f.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
    f.type_name = ".google.protobuf.Empty"
    msg.field << f
    file.message_type << msg

    req.proto_file << file

    req_io = IO::Memory.new
    req.encode(req_io)

    proc = Process.new(
      plugin_bin,
      input: IO::Memory.new(req_io.to_slice),
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Pipe,
    )
    resp_bytes = proc.output.gets_to_end.to_slice
    proc.wait

    resp = Proto::Bootstrap::CodeGeneratorResponse.decode(IO::Memory.new(resp_bytes))
    resp.error.should eq ""
    resp.file.size.should eq 1
    resp.file[0].content.should contain("property payload : Custom::Empty? = nil")
  end
end
