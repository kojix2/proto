require "../src/proto"

module Example
  class Child
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
      writer = Proto::Wire::Writer.new(io)
      if has_value?
        writer.write_tag(1, Proto::WireType::VARINT)
        writer.write_int32(value)
      end
      write_unknown_fields(writer)
    end
  end

  class Parent
    include Proto::Message

    property child : Child? = nil

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
          msg.child = Child.decode_partial(reader.read_embedded)
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
      writer = Proto::Wire::Writer.new(io)
      if current_child = child
        writer.write_embedded(1) { |sub| current_child.encode_partial(sub) }
      end
      write_unknown_fields(writer)
    end
  end
end

parent = Example::Parent.new
parent.child = Example::Child.new

begin
  parent.encode
rescue ex : Proto::RequiredFieldError
  puts "strict encode error: #{ex.message}"
end

partial_bytes = parent.encode_partial
puts "partial bytes: #{partial_bytes.size}"

begin
  Example::Parent.decode(partial_bytes)
rescue ex : Proto::RequiredFieldError
  puts "strict decode error: #{ex.message}"
end

partial = Example::Parent.decode_partial(partial_bytes)
puts "partial child present?: #{partial.has_child?}"
child = partial.child.as(Example::Child)
puts "partial child has_value?: #{child.has_value?}"
