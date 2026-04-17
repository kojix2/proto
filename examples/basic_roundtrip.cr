require "../src/proto"

module Example
  class User
    include Proto::Message

    property id : Int32 = 0
    property name : String = ""

    def self.decode(io : IO) : self
      msg = new
      reader = Proto::Wire::Reader.new(io)
      while tag = reader.read_tag
        fn, wt = tag
        case fn
        when 1 then msg.id = reader.read_int32
        when 2 then msg.name = reader.read_string
        else
          msg.capture_unknown_field(reader, fn, wt)
        end
      end
      msg
    end

    def encode(io : IO) : Nil
      w = Proto::Wire::Writer.new(io)
      if id != 0
        w.write_tag(1, Proto::WireType::VARINT)
        w.write_int32(id)
      end
      w.write_string_field(2, name)
      write_unknown_fields(w)
    end
  end
end

user = Example::User.new
user.id = 42
user.name = "Alice"

encoded = user.encode
decoded = Example::User.decode(encoded)

puts "encoded bytes: #{encoded.size}"
puts "decoded id: #{decoded.id}"
puts "decoded name: #{decoded.name}"
