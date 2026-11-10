module Proto
  class Error < Exception
  end

  class DecodeError < Error
  end

  class DecodeLimitError < DecodeError
  end

  class EncodeError < Error
  end

  class EncodeLimitError < EncodeError
  end

  class ValidationError < Error
  end

  class RequiredFieldError < ValidationError
  end
end
