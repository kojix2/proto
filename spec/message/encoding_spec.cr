require "../spec_helper"
require "../support/message_types"

describe Proto::Message do
  describe "#encode" do
    it "serializes a message to bytes" do
      msg = ProtoSpec::PingMessage.new
      msg.value = 42
      msg.encode.should_not be_empty
    end

    it "round-trips through encode/decode(io)" do
      msg = ProtoSpec::PingMessage.new
      msg.value = 42
      decoded = ProtoSpec::PingMessage.decode(IO::Memory.new(msg.encode))
      decoded.value.should eq(42)
    end
  end

  describe ".decode" do
    it "decodes from bytes" do
      msg = ProtoSpec::PingMessage.new
      msg.value = 99
      decoded = ProtoSpec::PingMessage.decode(msg.encode)
      decoded.value.should eq(99)
    end

    it "returns a zero-value message for empty bytes" do
      decoded = ProtoSpec::PingMessage.decode(Bytes.empty)
      decoded.value.should eq(0)
    end
  end

  describe "canonical proto API" do
    it "round-trips correctly via encode/decode" do
      msg = ProtoSpec::PingMessage.new
      msg.value = 123
      decoded = ProtoSpec::PingMessage.decode(msg.encode)
      decoded.value.should eq(123)
    end

    it "is stable across repeated encode/decode" do
      msg = ProtoSpec::PingMessage.new
      msg.value = 55
      bytes = msg.encode
      ProtoSpec::PingMessage.decode(bytes).value.should eq(ProtoSpec::PingMessage.decode(bytes).value)
    end
  end
end
