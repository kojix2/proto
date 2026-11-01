require "../spec_helper"

module ProtoSpec
  class PingMessage
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

  enum StrictMode : Int32
    UNKNOWN = 0
    ENABLED = 1

    def self.from_raw?(raw : Int32) : self?
      case raw
      when 0 then UNKNOWN
      when 1 then ENABLED
      end
    end
  end

  class StrictEnumMessage
    include Proto::Message

    property mode : StrictMode = StrictMode::UNKNOWN

    def self.decode(io : IO) : self
      msg = new
      reader = Proto::Wire::Reader.new(io)
      while tag = reader.read_tag
        fn, wt = tag
        case fn
        when 1
          raw_u64 = reader.read_uint64
          raw = Proto::Wire::Reader.int32_from_varint(raw_u64)
          begin
            msg.mode = StrictMode.from_value(raw)
          rescue ArgumentError
            msg.add_unknown_varint(fn, raw_u64)
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

  class RequiredScalarMessage
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

  class ChoiceMessage
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

  class RequiredChildMessage
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

  class RequiredMessageWrapper
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
end
