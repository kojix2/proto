module Proto
  # Base module for generated message classes.
  #
  # Concrete generated classes include this module and implement:
  #   def encode(io : IO) : Nil
  #   def self.decode(io : IO) : self
  #
  # The Bytes convenience methods are provided here.
  module Message
    include HasUnknownFields

    def validate_required! : Nil
    end

    def validate_required_deep! : Nil
      validate_required!
    end

    def self.decode_partial(io : IO)
      raise NotImplementedError.new("#{self} must implement decode_partial(io)")
    end

    def encode(io : IO) : Nil
      raise NotImplementedError.new("#{self.class} must implement encode(io)")
    end

    def encode_partial(io : IO) : Nil
      raise NotImplementedError.new("#{self.class} must implement encode_partial(io)")
    end

    # Serialize this message to a byte slice.
    def encode : Bytes
      io = IO::Memory.new
      encode(io)
      io.to_slice
    end

    def encode_partial : Bytes
      io = IO::Memory.new
      encode_partial(io)
      io.to_slice
    end

    macro included
      # Decode a message from a raw byte slice.
      def self.decode(bytes : Bytes) : self
        decode(IO::Memory.new(bytes))
      end

      def self.decode_partial(bytes : Bytes) : self
        decode_partial(IO::Memory.new(bytes))
      end
    end
  end
end
