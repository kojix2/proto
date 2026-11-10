module Proto
  # Limits applied to a generated message and its nested fields.
  struct DecodeOptions
    getter max_message_size : Int64
    getter max_field_length : Int32
    getter max_recursion_depth : Int32

    def initialize(@max_message_size : Int64 = 64_i64 * 1024 * 1024,
                   @max_field_length : Int32 = 8_i32 * 1024 * 1024,
                   @max_recursion_depth : Int32 = 100)
      raise ArgumentError.new("max_message_size must be positive") unless @max_message_size > 0
      raise ArgumentError.new("max_field_length must be positive") unless @max_field_length > 0
      raise ArgumentError.new("max_recursion_depth must be nonnegative") unless @max_recursion_depth >= 0
    end
  end

  struct EncodeOptions
    getter max_field_length : Int32

    def initialize(@max_field_length : Int32 = 8_i32 * 1024 * 1024)
      raise ArgumentError.new("max_field_length must be positive") unless @max_field_length > 0
    end
  end
end
