require "../spec_helper"
require "../fixtures/regressions.pb"

describe "generated messages" do
  describe "singular message merging" do
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
  end

  describe "message-valued maps" do
    it "retains a message-valued map entry whose value is omitted" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_embedded(3) do |entry_io|
        Proto::Wire::Writer.new(entry_io).write_string_field(1, "present")
      end

      entries = Regressions::Wrapper.decode(io.to_slice).entries
      entries.has_key?("present").should be_true
      entries["present"].should eq(Regressions::Nested.new)
    end
  end
end
