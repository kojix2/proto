require "./spec_helper"
require "./fixtures/regressions.pb"
require "./fixtures/packing_proto2.pb"

describe "protobuf compatibility regressions" do
  it "preserves all three proto3 optional bool states" do
    Regressions::Wrapper.new.encode.should be_empty

    explicit_false = Regressions::Wrapper.new
    explicit_false.flag = false
    explicit_false.encode.should eq(Bytes[0x08, 0x00])
    decoded_false = Regressions::Wrapper.decode(explicit_false.encode)
    decoded_false.has_flag?.should be_true
    decoded_false.flag.should be_false

    explicit_true = Regressions::Wrapper.new
    explicit_true.flag = true
    explicit_true.encode.should eq(Bytes[0x08, 0x01])
  end

  it "merges repeated occurrences of a singular embedded message recursively" do
    io = IO::Memory.new
    writer = Proto::Wire::Writer.new(io)
    writer.write_embedded(2) do |nested_io|
      nested = Proto::Wire::Writer.new(nested_io)
      nested.write_int32_field(1, 7)
      nested.write_int32_field(3, 10)
      nested.write_embedded(4) { |child| Proto::Wire::Writer.new(child).write_string_field(1, "left") }
    end
    writer.write_embedded(2) do |nested_io|
      nested = Proto::Wire::Writer.new(nested_io)
      nested.write_string_field(2, "second")
      nested.write_int32_field(3, 20)
      nested.write_embedded(4) { |child| Proto::Wire::Writer.new(child).write_string_field(2, "right") }
    end

    nested_value = Regressions::Wrapper.decode(io.to_slice).nested
    nested_value.should_not be_nil
    nested = nested_value.as(Regressions::Nested)
    nested.first.should eq(7)
    nested.second.should eq("second")
    nested.values.should eq([10, 20])
    child_value = nested.child
    child_value.should_not be_nil
    child = child_value.as(Regressions::Nested::Child)
    child.left.should eq("left")
    child.right.should eq("right")
  end

  it "retains a message-valued map entry whose value is omitted" do
    io = IO::Memory.new
    Proto::Wire::Writer.new(io).write_embedded(3) do |entry_io|
      Proto::Wire::Writer.new(entry_io).write_string_field(1, "present")
    end

    entries = Regressions::Wrapper.decode(io.to_slice).entries
    entries.has_key?("present").should be_true
    entries["present"].should eq(Regressions::Nested.new)
  end

  it "honors packed=false and the proto3 packed default" do
    message = Regressions::Wrapper.new
    message.unpacked = [1, 2]
    message.packed = [3, 4]
    message.encode.should eq(Bytes[0x20, 0x01, 0x20, 0x02, 0x2a, 0x02, 0x03, 0x04])
  end

  it "uses unpacked by default in proto2 and honors packed=true" do
    message = Regressions::Proto2Packing.new
    message.unpacked = [1, 2]
    message.packed = [3, 4]
    message.encode.should eq(Bytes[0x08, 0x01, 0x08, 0x02, 0x12, 0x02, 0x03, 0x04])
  end

  it "escapes a schema field named unknown_fields" do
    message = Regressions::Wrapper.new
    message.unknown_fields_ = "schema value"
    decoded = Regressions::Wrapper.decode(message.encode)
    decoded.unknown_fields_.should eq("schema value")
    decoded.unknown_fields.should be_empty
  end
end
