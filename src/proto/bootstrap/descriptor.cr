require "../wire/reader"
require "../wire/writer"
require "../wire_type"
require "../unknown_field"

# Stage-0 bootstrap: hand-written Crystal representations of
# google/protobuf/descriptor.proto and google/protobuf/compiler/plugin.proto.
#
# These are used by the protoc plugin generator before the generator itself
# is capable of producing Crystal from .proto files.  Only the fields
# relevant to code generation are decoded; everything else is captured as
# unknown fields so wire round-trip is preserved.

module Proto
  module Bootstrap
    # -------------------------------------------------------------------------
    # Scalar helpers shared by all bootstrap message classes
    # -------------------------------------------------------------------------

    private macro decode_loop(io, &blk)
      _reader = ::Proto::Wire::Reader.new({{ io }})
      while _tag = _reader.read_tag
        _field_number, _wire_type = _tag
        case _field_number
        {{ yield }}
        else
          capture_unknown_field(_reader, _field_number, _wire_type)
        end
      end
    end

    # -------------------------------------------------------------------------
    # FieldDescriptorProto
    # -------------------------------------------------------------------------

    enum FieldLabel : Int32
      LABEL_OPTIONAL = 1
      LABEL_REQUIRED = 2
      LABEL_REPEATED = 3
    end

    enum FieldType : Int32
      TYPE_DOUBLE   =  1
      TYPE_FLOAT    =  2
      TYPE_INT64    =  3
      TYPE_UINT64   =  4
      TYPE_INT32    =  5
      TYPE_FIXED64  =  6
      TYPE_FIXED32  =  7
      TYPE_BOOL     =  8
      TYPE_STRING   =  9
      TYPE_GROUP    = 10
      TYPE_MESSAGE  = 11
      TYPE_BYTES    = 12
      TYPE_UINT32   = 13
      TYPE_ENUM     = 14
      TYPE_SFIXED32 = 15
      TYPE_SFIXED64 = 16
      TYPE_SINT32   = 17
      TYPE_SINT64   = 18
    end

    class FieldDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property extendee : String = ""
      property number : Int32 = 0
      property label : FieldLabel = FieldLabel::LABEL_OPTIONAL
      property type : FieldType = FieldType::TYPE_STRING
      property type_name : String = ""
      property default_value : String = ""
      property oneof_index : Int32? = nil
      property json_name : String = ""
      property? proto3_optional : Bool = false

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when  1 then msg.name = reader.read_string
          when  2 then msg.extendee = reader.read_string
          when  3 then msg.number = reader.read_int32
          when  4 then msg.label = FieldLabel.from_value(reader.read_int32)
          when  5 then msg.type = FieldType.from_value(reader.read_int32)
          when  6 then msg.type_name = reader.read_string
          when  7 then msg.default_value = reader.read_string
          when  9 then msg.oneof_index = reader.read_int32
          when 10 then msg.json_name = reader.read_string
          when 17 then msg.proto3_optional = reader.read_bool
          else         msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        w.write_string_field(2, extendee)
        w.write_int32_field(3, number)
        w.write_tag(4, WireType::VARINT)
        w.write_int32(label.value)
        w.write_tag(5, WireType::VARINT)
        w.write_int32(type.value)
        w.write_string_field(6, type_name)
        w.write_string_field(7, default_value)
        if oi = oneof_index
          w.write_tag(9, WireType::VARINT)
          w.write_int32(oi)
        end
        w.write_string_field(10, json_name)
        w.write_bool_field(17, proto3_optional?)
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # OneofDescriptorProto
    # -------------------------------------------------------------------------

    class OneofDescriptorProto
      include HasUnknownFields

      property name : String = ""

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # EnumValueDescriptorProto
    # -------------------------------------------------------------------------

    class EnumValueDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property number : Int32 = 0

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          when 2 then msg.number = reader.read_int32
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        w.write_tag(2, WireType::VARINT)
        w.write_int32(number)
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # EnumDescriptorProto
    # -------------------------------------------------------------------------

    class EnumDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property value : Array(EnumValueDescriptorProto) = [] of EnumValueDescriptorProto

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          when 2 then msg.value << EnumValueDescriptorProto.decode(reader.read_embedded)
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        value.each do |v|
          w.write_embedded(2) { |sub| v.encode(sub) }
        end
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # DescriptorProto (forward declaration needed for recursive nesting)
    # -------------------------------------------------------------------------

    class MessageOptions
      include HasUnknownFields

      # descriptor.proto: MessageOptions.map_entry = 7
      property? map_entry : Bool = false

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 7 then msg.map_entry = reader.read_bool
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_bool_field(7, map_entry?)
        write_unknown_fields(w)
      end
    end

    class DescriptorProto
      include HasUnknownFields

      property name : String = ""
      property field : Array(FieldDescriptorProto) = [] of FieldDescriptorProto
      property extension : Array(FieldDescriptorProto) = [] of FieldDescriptorProto
      property nested_type : Array(DescriptorProto) = [] of DescriptorProto
      property enum_type : Array(EnumDescriptorProto) = [] of EnumDescriptorProto
      property options : MessageOptions? = nil
      property oneof_decl : Array(OneofDescriptorProto) = [] of OneofDescriptorProto

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          when 2 then msg.field << FieldDescriptorProto.decode(reader.read_embedded)
          when 6 then msg.extension << FieldDescriptorProto.decode(reader.read_embedded)
          when 3 then msg.nested_type << DescriptorProto.decode(reader.read_embedded)
          when 4 then msg.enum_type << EnumDescriptorProto.decode(reader.read_embedded)
          when 7 then msg.options = MessageOptions.decode(reader.read_embedded)
          when 8 then msg.oneof_decl << OneofDescriptorProto.decode(reader.read_embedded)
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        field.each { |field_desc| w.write_embedded(2) { |sub| field_desc.encode(sub) } }
        extension.each { |extension_desc| w.write_embedded(6) { |sub| extension_desc.encode(sub) } }
        nested_type.each { |nested_msg| w.write_embedded(3) { |sub| nested_msg.encode(sub) } }
        enum_type.each { |enum_desc| w.write_embedded(4) { |sub| enum_desc.encode(sub) } }
        if opts = options
          w.write_embedded(7) { |sub| opts.encode(sub) }
        end
        oneof_decl.each { |oneof_desc| w.write_embedded(8) { |sub| oneof_desc.encode(sub) } }
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # MethodDescriptorProto
    # -------------------------------------------------------------------------

    class MethodDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property input_type : String = ""
      property output_type : String = ""
      property? client_streaming : Bool = false
      property? server_streaming : Bool = false

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          when 2 then msg.input_type = reader.read_string
          when 3 then msg.output_type = reader.read_string
          when 5 then msg.client_streaming = reader.read_bool
          when 6 then msg.server_streaming = reader.read_bool
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        w.write_string_field(2, input_type)
        w.write_string_field(3, output_type)
        w.write_bool_field(5, client_streaming?)
        w.write_bool_field(6, server_streaming?)
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # ServiceDescriptorProto
    # -------------------------------------------------------------------------

    class ServiceDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property method : Array(MethodDescriptorProto) = [] of MethodDescriptorProto

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when 1 then msg.name = reader.read_string
          when 2 then msg.method << MethodDescriptorProto.decode(reader.read_embedded)
          else        msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        method.each { |method_desc| w.write_embedded(2) { |sub| method_desc.encode(sub) } }
        write_unknown_fields(w)
      end
    end

    # -------------------------------------------------------------------------
    # FileDescriptorProto
    # -------------------------------------------------------------------------

    class FileDescriptorProto
      include HasUnknownFields

      property name : String = ""
      property package : String = ""
      property dependency : Array(String) = [] of String
      property message_type : Array(DescriptorProto) = [] of DescriptorProto
      property enum_type : Array(EnumDescriptorProto) = [] of EnumDescriptorProto
      property extension : Array(FieldDescriptorProto) = [] of FieldDescriptorProto
      property service : Array(ServiceDescriptorProto) = [] of ServiceDescriptorProto
      property syntax : String = ""

      def self.decode(io : IO) : self
        msg = new
        reader = Wire::Reader.new(io)
        while tag = reader.read_tag
          fn, wt = tag
          case fn
          when  1 then msg.name = reader.read_string
          when  2 then msg.package = reader.read_string
          when  3 then msg.dependency << reader.read_string
          when  4 then msg.message_type << DescriptorProto.decode(reader.read_embedded)
          when  5 then msg.enum_type << EnumDescriptorProto.decode(reader.read_embedded)
          when  7 then msg.extension << FieldDescriptorProto.decode(reader.read_embedded)
          when  6 then msg.service << ServiceDescriptorProto.decode(reader.read_embedded)
          when 12 then msg.syntax = reader.read_string
          else         msg.capture_unknown_field(reader, fn, wt)
          end
        end
        msg
      end

      def encode(io : IO) : Nil
        w = Wire::Writer.new(io)
        w.write_string_field(1, name)
        w.write_string_field(2, package)
        dependency.each { |dependency_name| w.write_string_field(3, dependency_name) }
        message_type.each { |message_desc| w.write_embedded(4) { |sub| message_desc.encode(sub) } }
        enum_type.each { |enum_desc| w.write_embedded(5) { |sub| enum_desc.encode(sub) } }
        extension.each { |extension_desc| w.write_embedded(7) { |sub| extension_desc.encode(sub) } }
        service.each { |svc| w.write_embedded(6) { |sub| svc.encode(sub) } }
        w.write_string_field(12, syntax)
        write_unknown_fields(w)
      end
    end
  end
end
