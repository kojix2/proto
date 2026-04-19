require "./spec_helper"

# Minimal hand-written message used to test the Proto::Message mixin.
private class PingMessage
  include Proto::Message

  property value : Int32 = 0

  def self.decode(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        msg.value = reader.read_int32
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    w.write_tag(1, Proto::WireType::VARINT)
    w.write_int32(value)
    write_unknown_fields(w)
  end
end

private enum StrictMode : Int32
  UNKNOWN = 0
  ENABLED = 1

  def self.from_raw?(raw : Int32) : self?
    case raw
    when 0 then UNKNOWN
    when 1 then ENABLED
    end
  end
end

private class StrictEnumMessage
  include Proto::Message

  property mode : StrictMode = StrictMode::UNKNOWN

  def self.decode(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        raw = reader.read_int32
        begin
          msg.mode = StrictMode.from_value(raw)
        rescue ArgumentError
          msg.add_unknown_varint(fn, raw.to_u64!)
        end
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    w.write_tag(1, Proto::WireType::VARINT)
    w.write_int32(mode.value)
    write_unknown_fields(w)
  end
end

private class RequiredScalarMessage
  include Proto::Message

  getter? has_count : Bool = false
  getter count : Int32 = 7

  def clear_count : Nil
    @count = 7
    @has_count = false
  end

  def count=(value : Int32) : Int32
    @count = value
    @has_count = true
    value
  end

  def validate_required! : Nil
    raise Proto::RequiredFieldError.new("Missing required field: count") unless has_count?
  end

  def self.decode(io : IO) : self
    msg = decode_partial(io)
    msg.validate_required_deep!
    msg
  end

  def self.decode_partial(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        msg.count = reader.read_int32
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    validate_required_deep!
    encode_partial(io)
  end

  def encode_partial(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    if has_count?
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(count)
    end
    write_unknown_fields(w)
  end
end

private class ChoiceMessage
  include Proto::Message

  enum ValueCase : Int32
    NONE  = 0
    NAME  = 1
    COUNT = 2
  end

  getter value_case : ValueCase = ValueCase::NONE
  getter name : String = ""
  getter count : Int32 = 0

  def clear_value : Nil
    @name = ""
    @count = 0
    @value_case = ValueCase::NONE
  end

  def name=(value : String) : String
    clear_value
    @name = value
    @value_case = ValueCase::NAME
    value
  end

  def count=(value : Int32) : Int32
    clear_value
    @count = value
    @value_case = ValueCase::COUNT
    value
  end

  def self.decode(io : IO) : self
    decode_partial(io)
  end

  def self.decode_partial(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        msg.name = reader.read_string
      when 2
        msg.count = reader.read_int32
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    encode_partial(io)
  end

  def encode_partial(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    if value_case == ValueCase::NAME
      w.write_tag(1, Proto::WireType::LENGTH_DELIMITED)
      w.write_string(name)
    end
    if value_case == ValueCase::COUNT
      w.write_tag(2, Proto::WireType::VARINT)
      w.write_int32(count)
    end
    write_unknown_fields(w)
  end

  def ==(other : self) : Bool
    return false unless value_case == other.value_case
    return false unless name == other.name
    return false unless count == other.count
    true
  end
end

private class RequiredChildMessage
  include Proto::Message

  getter? has_value : Bool = false
  getter value : Int32 = 0

  def clear_value : Nil
    @value = 0
    @has_value = false
  end

  def value=(new_value : Int32) : Int32
    @value = new_value
    @has_value = true
    new_value
  end

  def validate_required! : Nil
    raise Proto::RequiredFieldError.new("Missing required field: value") unless has_value?
  end

  def self.decode(io : IO) : self
    msg = decode_partial(io)
    msg.validate_required_deep!
    msg
  end

  def self.decode_partial(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        msg.value = reader.read_int32
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    validate_required_deep!
    encode_partial(io)
  end

  def encode_partial(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    if has_value?
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(value)
    end
    write_unknown_fields(w)
  end
end

private class RequiredMessageWrapper
  include Proto::Message

  property child : RequiredChildMessage? = nil

  def has_child? : Bool
    !child.nil?
  end

  def clear_child : Nil
    self.child = nil
  end

  def validate_required! : Nil
    raise Proto::RequiredFieldError.new("Missing required field: child") unless has_child?
  end

  def validate_required_deep! : Nil
    validate_required!
    child.try &.validate_required_deep!
  end

  def self.decode(io : IO) : self
    msg = decode_partial(io)
    msg.validate_required_deep!
    msg
  end

  def self.decode_partial(io : IO) : self
    msg = new
    reader = Proto::Wire::Reader.new(io)
    while tag = reader.read_tag
      fn, wt = tag
      case fn
      when 1
        msg.child = RequiredChildMessage.decode_partial(reader.read_embedded)
      else
        msg.capture_unknown_field(reader, fn, wt)
      end
    end
    msg
  end

  def encode(io : IO) : Nil
    validate_required_deep!
    encode_partial(io)
  end

  def encode_partial(io : IO) : Nil
    w = Proto::Wire::Writer.new(io)
    if _v = child
      w.write_embedded(1) { |sub| _v.encode_partial(sub) }
    end
    write_unknown_fields(w)
  end
end

describe Proto::Message do
  describe "#encode" do
    it "serializes a message to bytes" do
      msg = PingMessage.new
      msg.value = 42
      msg.encode.should_not be_empty
    end

    it "round-trips through encode/decode(io)" do
      msg = PingMessage.new
      msg.value = 42
      decoded = PingMessage.decode(IO::Memory.new(msg.encode))
      decoded.value.should eq(42)
    end
  end

  describe ".decode" do
    it "decodes from bytes" do
      msg = PingMessage.new
      msg.value = 99
      decoded = PingMessage.decode(msg.encode)
      decoded.value.should eq(99)
    end

    it "returns a zero-value message for empty bytes" do
      decoded = PingMessage.decode(Bytes.empty)
      decoded.value.should eq(0)
    end
  end

  describe "canonical proto API" do
    it "round-trips correctly via encode/decode" do
      msg = PingMessage.new
      msg.value = 123
      decoded = PingMessage.decode(msg.encode)
      decoded.value.should eq(123)
    end

    it "is stable across repeated encode/decode" do
      msg = PingMessage.new
      msg.value = 55
      bytes = msg.encode
      PingMessage.decode(bytes).value.should eq(PingMessage.decode(bytes).value)
    end
  end

  describe "unknown enum compatibility" do
    it "keeps unknown enum numeric values as unknown fields" do
      io = IO::Memory.new
      w = Proto::Wire::Writer.new(io)
      w.write_tag(1, Proto::WireType::VARINT)
      w.write_int32(123)

      decoded = StrictEnumMessage.decode(IO::Memory.new(io.to_slice))
      decoded.mode.should eq(StrictMode::UNKNOWN)
      decoded.unknown_fields.size.should eq(1)
      decoded.unknown_fields[0].field_number.should eq(1)
      decoded.unknown_fields[0].wire_type.should eq(Proto::WireType::VARINT)
      decoded.unknown_fields[0].data.should eq(123_u64)

      reencoded = decoded.encode
      parsed = StrictEnumMessage.decode(IO::Memory.new(reencoded))
      parsed.unknown_fields.size.should eq(1)
      parsed.unknown_fields[0].data.should eq(123_u64)
    end
  end

  describe "extension access helpers" do
    it "reads a bool extension from unknown varint fields" do
      msg = PingMessage.new
      msg.add_unknown_varint(50_001, 1_u64)

      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_001
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_BOOL

      msg.has_extension?(extension).should be_true
      msg.extension_value?(extension).should be_true
    end

    it "returns repeated extension values in wire order" do
      msg = PingMessage.new
      msg.add_unknown_varint(50_002, 10_u64)
      msg.add_unknown_varint(50_002, 20_u64)

      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_002
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      extension.type = Proto::Bootstrap::FieldType::TYPE_INT32

      values = msg.extension_values(extension)
      values.size.should eq(2)
      values[0].should eq(10)
      values[1].should eq(20)
      msg.extension_value?(extension).should eq(20)
    end

    it "reads string extensions from length-delimited unknown fields" do
      io = IO::Memory.new
      writer = Proto::Wire::Writer.new(io)
      writer.write_tag(50_003, Proto::WireType::LENGTH_DELIMITED)
      writer.write_string("demo")

      msg = PingMessage.decode(io.to_slice)
      extension = Proto::Bootstrap::FieldDescriptorProto.new
      extension.number = 50_003
      extension.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      extension.type = Proto::Bootstrap::FieldType::TYPE_STRING

      msg.has_extension?(extension).should be_true
      msg.extension_value?(extension).should eq("demo")
    end
  end

  describe "required field presence" do
    it "distinguishes unset from explicit default" do
      msg = RequiredScalarMessage.new
      msg.has_count?.should be_false
      msg.count.should eq(7)

      msg.count = 7
      msg.has_count?.should be_true
      msg.count.should eq(7)

      msg.clear_count
      msg.has_count?.should be_false
      msg.count.should eq(7)
    end

    it "raises on encode when a required field is missing" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: count") do
        RequiredScalarMessage.new.encode
      end
    end

    it "raises on decode when a required field is missing" do
      expect_raises(Proto::RequiredFieldError, "Missing required field: count") do
        RequiredScalarMessage.decode(Bytes.empty)
      end
    end

    it "allows partial decode and encode when explicitly requested" do
      partial = RequiredScalarMessage.decode_partial(Bytes.empty)
      partial.has_count?.should be_false
      partial.encode_partial.should eq(Bytes.empty)
    end

    it "supports strict and partial APIs for required message fields" do
      partial = RequiredMessageWrapper.decode_partial(Bytes.empty)
      partial.has_child?.should be_false
      partial.encode_partial.should eq(Bytes.empty)

      expect_raises(Proto::RequiredFieldError, "Missing required field: child") do
        RequiredMessageWrapper.decode(Bytes.empty)
      end

      expect_raises(Proto::RequiredFieldError, "Missing required field: child") do
        RequiredMessageWrapper.new.encode
      end
    end

    it "raises on strict decode when a nested required field is missing" do
      wrapper = RequiredMessageWrapper.new
      wrapper.child = RequiredChildMessage.new

      expect_raises(Proto::RequiredFieldError, "Missing required field: value") do
        RequiredMessageWrapper.decode(wrapper.encode_partial)
      end
    end

    it "raises on strict encode when a nested required field is missing" do
      wrapper = RequiredMessageWrapper.new
      wrapper.child = RequiredChildMessage.new

      expect_raises(Proto::RequiredFieldError, "Missing required field: value") do
        wrapper.encode
      end
    end

    it "keeps nested required fields partial under explicit partial APIs" do
      wrapper = RequiredMessageWrapper.new
      wrapper.child = RequiredChildMessage.new

      partial = RequiredMessageWrapper.decode_partial(wrapper.encode_partial)
      partial.has_child?.should be_true
      partial.child.should_not be_nil
      child = partial.child.as(RequiredChildMessage)
      child.has_value?.should be_false
    end
  end

  describe "validation errors" do
    it "classifies required field failures separately from encode and decode errors" do
      Proto::RequiredFieldError.new("missing").should be_a(Proto::ValidationError)
    end
  end

  describe "oneof setter semantics" do
    it "updates case and clears sibling fields on assignment" do
      msg = ChoiceMessage.new
      msg.name = "alice"

      msg.value_case.should eq(ChoiceMessage::ValueCase::NAME)
      msg.name.should eq("alice")
      msg.count.should eq(0)

      msg.count = 3

      msg.value_case.should eq(ChoiceMessage::ValueCase::COUNT)
      msg.name.should eq("")
      msg.count.should eq(3)
    end

    it "round-trips the active oneof branch only" do
      msg = ChoiceMessage.new
      msg.name = "alice"

      decoded = ChoiceMessage.decode(msg.encode)
      decoded.value_case.should eq(ChoiceMessage::ValueCase::NAME)
      decoded.name.should eq("alice")
      decoded.count.should eq(0)
    end
  end

  describe Proto::OpenEnum do
    it "keeps raw values for proto3-style open enums" do
      value = Proto::OpenEnum(StrictMode).new(123)
      value.raw.should eq(123)
      value.known?.should be_false
      value.known.should be_nil
    end

    it "recognizes known enum values" do
      value = Proto::OpenEnum(StrictMode).new(StrictMode::ENABLED)
      value.raw.should eq(1)
      value.known?.should be_true
      value.known.should eq(StrictMode::ENABLED)
    end

    it "accepts either raw ints or enum values during initialization" do
      Proto::OpenEnum(StrictMode).new(1).raw.should eq(1)
      Proto::OpenEnum(StrictMode).new(StrictMode::ENABLED).raw.should eq(1)
    end

    it "keeps hash consistent with the raw value" do
      values = {
        Proto::OpenEnum(StrictMode).new(StrictMode::ENABLED) => "known",
        Proto::OpenEnum(StrictMode).new(123)                 => "unknown",
      }

      values[Proto::OpenEnum(StrictMode).new(1)].should eq("known")
      values[Proto::OpenEnum(StrictMode).new(123)].should eq("unknown")
    end

    it "renders known and unknown values sensibly" do
      Proto::OpenEnum(StrictMode).new(StrictMode::ENABLED).to_s.should eq("ENABLED")
      Proto::OpenEnum(StrictMode).new(123).to_s.should eq("123")

      Proto::OpenEnum(StrictMode).new(StrictMode::ENABLED).inspect.should eq("Proto::OpenEnum(StrictMode).new(ENABLED)")
      Proto::OpenEnum(StrictMode).new(123).inspect.should eq("Proto::OpenEnum(StrictMode).new(123)")
    end
  end
end
