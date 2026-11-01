require "../spec_helper"
require "../support/message_types"

describe Proto::Message do
  describe "presence" do
    it "distinguishes unset from explicit default" do
      msg = ProtoSpec::RequiredScalarMessage.new
      msg.has_count?.should be_false
      msg.count.should eq(7)

      msg.count = 7
      msg.has_count?.should be_true
      msg.count.should eq(7)

      msg.clear_count
      msg.has_count?.should be_false
      msg.count.should eq(7)
    end
  end

  describe "partial APIs" do
    it "allows partial decode and encode when explicitly requested" do
      partial = ProtoSpec::RequiredScalarMessage.decode_partial(Bytes.empty)
      partial.has_count?.should be_false
      partial.encode_partial.should eq(Bytes.empty)
    end

    it "allows a missing required message under partial APIs" do
      partial = ProtoSpec::RequiredMessageWrapper.decode_partial(Bytes.empty)
      partial.has_child?.should be_false
      partial.encode_partial.should eq(Bytes.empty)
    end

    it "keeps nested required fields partial under explicit partial APIs" do
      wrapper = ProtoSpec::RequiredMessageWrapper.new
      wrapper.child = ProtoSpec::RequiredChildMessage.new

      partial = ProtoSpec::RequiredMessageWrapper.decode_partial(wrapper.encode_partial)
      partial.has_child?.should be_true
      partial.child.should_not be_nil
      child = partial.child.as(ProtoSpec::RequiredChildMessage)
      child.has_value?.should be_false
    end
  end

  describe "strict validation" do
    it "raises on encode when a required field is missing" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: count") do
        ProtoSpec::RequiredScalarMessage.new.encode
      end
    end

    it "raises on decode when a required field is missing" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: count") do
        ProtoSpec::RequiredScalarMessage.decode(Bytes.empty)
      end
    end

    it "rejects a missing required message on decode" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: child") do
        ProtoSpec::RequiredMessageWrapper.decode(Bytes.empty)
      end
    end

    it "rejects a missing required message on encode" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: child") do
        ProtoSpec::RequiredMessageWrapper.new.encode
      end
    end

    it "raises on strict decode when a nested required field is missing" do
      wrapper = ProtoSpec::RequiredMessageWrapper.new
      wrapper.child = ProtoSpec::RequiredChildMessage.new

      expect_raises(Proto::RequiredFieldError, "Missing required field: value") do
        ProtoSpec::RequiredMessageWrapper.decode(wrapper.encode_partial)
      end
    end

    it "raises on strict encode when a nested required field is missing" do
      wrapper = ProtoSpec::RequiredMessageWrapper.new
      wrapper.child = ProtoSpec::RequiredChildMessage.new

      expect_raises(Proto::RequiredFieldError, "Missing required field: value") do
        wrapper.encode
      end
    end
  end

  describe "validation errors" do
    it "classifies required field failures separately from encode and decode errors" do
      Proto::RequiredFieldError.new("missing").should be_a(Proto::ValidationError)
    end
  end
end
