require "./spec_helper"
require "./support/message_types"

describe Proto::OpenEnum do
  describe "construction" do
    it "accepts a raw integer during initialization" do
      Proto::OpenEnum(ProtoSpec::StrictMode).new(1).raw.should eq(1)
    end

    it "accepts an enum value during initialization" do
      Proto::OpenEnum(ProtoSpec::StrictMode).new(ProtoSpec::StrictMode::ENABLED).raw.should eq(1)
    end
  end

  describe "known and unknown values" do
    it "recognizes known enum values" do
      value = Proto::OpenEnum(ProtoSpec::StrictMode).new(ProtoSpec::StrictMode::ENABLED)
      value.raw.should eq(1)
      value.known?.should be_true
      value.known.should eq(ProtoSpec::StrictMode::ENABLED)
    end

    it "keeps raw values for proto3-style open enums" do
      value = Proto::OpenEnum(ProtoSpec::StrictMode).new(123)
      value.raw.should eq(123)
      value.known?.should be_false
      value.known.should be_nil
    end
  end

  describe "hashing" do
    it "keeps hash consistent with the raw value" do
      values = {
        Proto::OpenEnum(ProtoSpec::StrictMode).new(ProtoSpec::StrictMode::ENABLED) => "known",
        Proto::OpenEnum(ProtoSpec::StrictMode).new(123)                            => "unknown",
      }

      values[Proto::OpenEnum(ProtoSpec::StrictMode).new(1)].should eq("known")
      values[Proto::OpenEnum(ProtoSpec::StrictMode).new(123)].should eq("unknown")
    end
  end

  describe "display" do
    it "renders a known value using its enum name" do
      Proto::OpenEnum(ProtoSpec::StrictMode).new(ProtoSpec::StrictMode::ENABLED).to_s.should eq("ENABLED")
      Proto::OpenEnum(ProtoSpec::StrictMode).new(ProtoSpec::StrictMode::ENABLED).inspect.should eq("Proto::OpenEnum(ProtoSpec::StrictMode).new(ENABLED)")
    end

    it "renders an unknown value using its raw integer" do
      Proto::OpenEnum(ProtoSpec::StrictMode).new(123).to_s.should eq("123")
      Proto::OpenEnum(ProtoSpec::StrictMode).new(123).inspect.should eq("Proto::OpenEnum(ProtoSpec::StrictMode).new(123)")
    end
  end
end
