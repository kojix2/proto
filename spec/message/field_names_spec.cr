require "../spec_helper"
require "../fixtures/regressions.pb"

describe "generated messages" do
  describe "reserved runtime field names" do
    it "escapes a schema field named unknown_fields" do
      message = Regressions::Wrapper.new
      message.unknown_fields_ = "schema value"
      decoded = Regressions::Wrapper.decode(message.encode)
      decoded.unknown_fields_.should eq("schema value")
      decoded.unknown_fields.should be_empty
    end
  end
end
