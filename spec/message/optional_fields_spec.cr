require "../spec_helper"
require "../fixtures/regressions.pb"

describe "generated optional bool fields" do
  it "omits an absent field" do
    Regressions::Wrapper.new.encode.should be_empty
  end

  it "preserves explicit false and its presence" do
    explicit_false = Regressions::Wrapper.new
    explicit_false.flag = false
    explicit_false.encode.should eq(Bytes[0x08, 0x00])
    decoded_false = Regressions::Wrapper.decode(explicit_false.encode)
    decoded_false.has_flag?.should be_true
    decoded_false.flag.should be_false
  end

  it "encodes explicit true" do
    explicit_true = Regressions::Wrapper.new
    explicit_true.flag = true
    explicit_true.encode.should eq(Bytes[0x08, 0x01])
  end
end
