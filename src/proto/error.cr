module Proto
  class Error < Exception
  end

  class DecodeError < Error
  end

  class EncodeError < Error
  end

  class ValidationError < Error
  end

  class RequiredFieldError < ValidationError
  end
end
