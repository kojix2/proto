require "../spec_helper"
require "../fixtures/regressions.pb"
require "../fixtures/packing_proto2.pb"

describe "generated messages" do
  describe "proto3 packing" do
    it "honors packed=false and the proto3 packed default" do
      message = Regressions::Wrapper.new
      message.unpacked = [1, 2]
      message.packed = [3, 4]
      message.encode.should eq(Bytes[0x20, 0x01, 0x20, 0x02, 0x2a, 0x02, 0x03, 0x04])
    end
  end

  describe "proto2 packing" do
    it "uses unpacked by default in proto2 and honors packed=true" do
      message = Regressions::Proto2Packing.new
      message.unpacked = [1, 2]
      message.packed = [3, 4]
      message.encode.should eq(Bytes[0x08, 0x01, 0x08, 0x02, 0x12, 0x02, 0x03, 0x04])
    end
  end
end
