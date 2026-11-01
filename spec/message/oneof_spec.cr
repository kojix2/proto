require "../spec_helper"
require "../support/message_types"

describe Proto::Message do
  describe "oneof setter semantics" do
    it "updates case and clears sibling fields on assignment" do
      msg = ProtoSpec::ChoiceMessage.new
      msg.name = "alice"

      msg.value_case.should eq(ProtoSpec::ChoiceMessage::ValueCase::NAME)
      msg.name.should eq("alice")
      msg.count.should eq(0)

      msg.count = 3

      msg.value_case.should eq(ProtoSpec::ChoiceMessage::ValueCase::COUNT)
      msg.name.should eq("")
      msg.count.should eq(3)
    end

    it "round-trips the active oneof branch only" do
      msg = ProtoSpec::ChoiceMessage.new
      msg.name = "alice"

      decoded = ProtoSpec::ChoiceMessage.decode(msg.encode)
      decoded.value_case.should eq(ProtoSpec::ChoiceMessage::ValueCase::NAME)
      decoded.name.should eq("alice")
      decoded.count.should eq(0)
    end
  end
end
