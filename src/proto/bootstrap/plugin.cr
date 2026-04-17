require "./descriptor"

module Proto
  module Bootstrap
    # -------------------------------------------------------------------------
    # CodeGeneratorRequest  (plugin.proto field 1, 2, 3, 15)
    # -------------------------------------------------------------------------

    class CodeGeneratorRequest
      include HasUnknownFields

      property file_to_generate : Array(String) = [] of String
      property parameter : String = ""
      property proto_file : Array(FileDescriptorProto) = [] of FileDescriptorProto

      def self.read_proto(io : IO) : self
        decode(io)
      end

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when  1 then msg.file_to_generate << reader.read_string
          when  2 then msg.parameter = reader.read_string
          when 15 then msg.proto_file << FileDescriptorProto.decode(reader.read_embedded)
          else         msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        file_to_generate.each { |file_name| w.write_string_field(1, file_name) }
        w.write_string_field(2, parameter)
        proto_file.each { |file_desc| w.write_embedded(15) { |sub| file_desc.encode(sub) } }
        write_unknown_fields(w)
      end

      # Convenience: find the FileDescriptorProto for a given file name.
      def file_descriptor(name : String) : FileDescriptorProto?
        proto_file.find { |file_desc| file_desc.name == name }
      end
    end

    # -------------------------------------------------------------------------
    # CodeGeneratorResponse::File
    # -------------------------------------------------------------------------

    class CodeGeneratorResponseFile
      include HasUnknownFields

      property name : String = ""
      property insertion_point : String = ""
      property content : String = ""

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when  1 then msg.name = reader.read_string
          when  2 then msg.insertion_point = reader.read_string
          when 15 then msg.content = reader.read_string
          else         msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        w.write_string_field(2, insertion_point)
        w.write_string_field(15, content)
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # CodeGeneratorResponse
    # -------------------------------------------------------------------------

    # Feature flags (supported_features bitmask)
    FEATURE_NONE              = 0_u64
    FEATURE_PROTO3_OPTIONAL   = 1_u64
    FEATURE_SUPPORTS_EDITIONS = 2_u64

    class CodeGeneratorResponse
      include HasUnknownFields

      property error : String = ""
      property supported_features : UInt64 = FEATURE_NONE
      property file : Array(CodeGeneratorResponseFile) = [] of CodeGeneratorResponseFile

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when  1 then msg.error = reader.read_string
          when  2 then msg.supported_features = reader.read_uint64
          when 15 then msg.file << CodeGeneratorResponseFile.decode(reader.read_embedded)
          else         msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, error)
        w.write_uint64_field(2, supported_features)
        file.each { |response_file| w.write_embedded(15) { |sub| response_file.encode(sub) } }
        write_unknown_fields(w)
      end

      def encode : Bytes
        io = IO::Memory.new
        encode(io)
        io.to_slice
      end
    end
  end
end
