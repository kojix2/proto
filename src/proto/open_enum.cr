module Proto
  struct OpenEnum(T)
    getter raw : Int32

    def initialize(value : Int32 | T)
      @raw = value.is_a?(T) ? value.value : value
    end

    def known : T?
      T.from_raw?(@raw)
    end

    def known? : Bool
      !known.nil?
    end

    def value : Int32
      @raw
    end

    def ==(other : self) : Bool
      raw == other.raw
    end

    def ==(other : T) : Bool
      raw == other.value
    end

    def hash(hasher)
      raw.hash(hasher)
    end

    def to_s(io : IO) : Nil
      if known_value = known
        known_value.to_s(io)
      else
        raw.to_s(io)
      end
    end

    def inspect(io : IO) : Nil
      io << "Proto::OpenEnum("
      io << {{ T.resolve.stringify }}
      io << ").new("
      if known_value = known
        io << known_value
      else
        io << raw
      end
      io << ')'
    end
  end
end
