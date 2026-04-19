require "./naming"
require "./field_naming"
require "./message_structure"
require "../wire/reader"
require "../wire/writer"

module Proto
  module Generator
    # Maps proto scalar types to Crystal types.
    SCALAR_TYPE_MAP = {
      Bootstrap::FieldType::TYPE_DOUBLE   => "Float64",
      Bootstrap::FieldType::TYPE_FLOAT    => "Float32",
      Bootstrap::FieldType::TYPE_INT64    => "Int64",
      Bootstrap::FieldType::TYPE_UINT64   => "UInt64",
      Bootstrap::FieldType::TYPE_INT32    => "Int32",
      Bootstrap::FieldType::TYPE_FIXED64  => "UInt64",
      Bootstrap::FieldType::TYPE_FIXED32  => "UInt32",
      Bootstrap::FieldType::TYPE_BOOL     => "Bool",
      Bootstrap::FieldType::TYPE_STRING   => "String",
      Bootstrap::FieldType::TYPE_BYTES    => "Bytes",
      Bootstrap::FieldType::TYPE_UINT32   => "UInt32",
      Bootstrap::FieldType::TYPE_SFIXED32 => "Int32",
      Bootstrap::FieldType::TYPE_SFIXED64 => "Int64",
      Bootstrap::FieldType::TYPE_SINT32   => "Int32",
      Bootstrap::FieldType::TYPE_SINT64   => "Int64",
    }

    # Maps proto scalar field types to Wire::Reader read methods.
    SCALAR_READER_MAP = {
      Bootstrap::FieldType::TYPE_DOUBLE   => "read_double",
      Bootstrap::FieldType::TYPE_FLOAT    => "read_float",
      Bootstrap::FieldType::TYPE_INT64    => "read_int64",
      Bootstrap::FieldType::TYPE_UINT64   => "read_uint64",
      Bootstrap::FieldType::TYPE_INT32    => "read_int32",
      Bootstrap::FieldType::TYPE_FIXED64  => "read_fixed64",
      Bootstrap::FieldType::TYPE_FIXED32  => "read_fixed32",
      Bootstrap::FieldType::TYPE_BOOL     => "read_bool",
      Bootstrap::FieldType::TYPE_STRING   => "read_string",
      Bootstrap::FieldType::TYPE_BYTES    => "read_bytes",
      Bootstrap::FieldType::TYPE_UINT32   => "read_uint32",
      Bootstrap::FieldType::TYPE_SFIXED32 => "read_sfixed32",
      Bootstrap::FieldType::TYPE_SFIXED64 => "read_sfixed64",
      Bootstrap::FieldType::TYPE_SINT32   => "read_sint32",
      Bootstrap::FieldType::TYPE_SINT64   => "read_sint64",
    }

    # Maps proto scalar field types to Wire::Writer write methods.
    SCALAR_WRITER_MAP = {
      Bootstrap::FieldType::TYPE_DOUBLE   => "write_double",
      Bootstrap::FieldType::TYPE_FLOAT    => "write_float",
      Bootstrap::FieldType::TYPE_INT64    => "write_int64",
      Bootstrap::FieldType::TYPE_UINT64   => "write_uint64",
      Bootstrap::FieldType::TYPE_INT32    => "write_int32",
      Bootstrap::FieldType::TYPE_FIXED64  => "write_fixed64",
      Bootstrap::FieldType::TYPE_FIXED32  => "write_fixed32",
      Bootstrap::FieldType::TYPE_BOOL     => "write_bool",
      Bootstrap::FieldType::TYPE_STRING   => "write_string",
      Bootstrap::FieldType::TYPE_BYTES    => "write_bytes",
      Bootstrap::FieldType::TYPE_UINT32   => "write_uint32",
      Bootstrap::FieldType::TYPE_SFIXED32 => "write_sfixed32",
      Bootstrap::FieldType::TYPE_SFIXED64 => "write_sfixed64",
      Bootstrap::FieldType::TYPE_SINT32   => "write_sint32",
      Bootstrap::FieldType::TYPE_SINT64   => "write_sint64",
    }

    # Wire types for scalar field types.
    SCALAR_WIRE_TYPE_MAP = {
      Bootstrap::FieldType::TYPE_DOUBLE   => "Proto::WireType::FIXED64",
      Bootstrap::FieldType::TYPE_FLOAT    => "Proto::WireType::FIXED32",
      Bootstrap::FieldType::TYPE_INT64    => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_UINT64   => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_INT32    => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_FIXED64  => "Proto::WireType::FIXED64",
      Bootstrap::FieldType::TYPE_FIXED32  => "Proto::WireType::FIXED32",
      Bootstrap::FieldType::TYPE_BOOL     => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_STRING   => "Proto::WireType::LENGTH_DELIMITED",
      Bootstrap::FieldType::TYPE_BYTES    => "Proto::WireType::LENGTH_DELIMITED",
      Bootstrap::FieldType::TYPE_UINT32   => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_SFIXED32 => "Proto::WireType::FIXED32",
      Bootstrap::FieldType::TYPE_SFIXED64 => "Proto::WireType::FIXED64",
      Bootstrap::FieldType::TYPE_SINT32   => "Proto::WireType::VARINT",
      Bootstrap::FieldType::TYPE_SINT64   => "Proto::WireType::VARINT",
    }

    # Field types that are packable in proto3.
    PACKABLE_TYPES = Set{
      Bootstrap::FieldType::TYPE_DOUBLE,
      Bootstrap::FieldType::TYPE_FLOAT,
      Bootstrap::FieldType::TYPE_INT64,
      Bootstrap::FieldType::TYPE_UINT64,
      Bootstrap::FieldType::TYPE_INT32,
      Bootstrap::FieldType::TYPE_FIXED64,
      Bootstrap::FieldType::TYPE_FIXED32,
      Bootstrap::FieldType::TYPE_BOOL,
      Bootstrap::FieldType::TYPE_UINT32,
      Bootstrap::FieldType::TYPE_SFIXED32,
      Bootstrap::FieldType::TYPE_SFIXED64,
      Bootstrap::FieldType::TYPE_SINT32,
      Bootstrap::FieldType::TYPE_SINT64,
      Bootstrap::FieldType::TYPE_ENUM,
    }

    class FileGenerator
      include FieldNaming
      include MessageStructure

      def initialize(
        @file : Bootstrap::FileDescriptorProto,
        @index : TypeIndex,
        @type_resolver : TypeNameResolver? = nil,
      )
      end

      # Return the output file name for the given proto file.
      def output_name : String
        @file.name.sub(/\.proto$/, ".pb.cr")
      end

      # Generate and return the Crystal source code.
      def generate : String
        io = IO::Memory.new
        emit_header(io)
        emit_requires(io)
        emit_body(io)
        io.to_s
      end

      private def emit_header(io : IO) : Nil
        io << "# Code generated by protoc-gen-crystal. DO NOT EDIT.\n"
        io << "# source: #{@file.name}\n\n"
        io << "require \"proto\"\n\n"
      end

      private def emit_requires(io : IO) : Nil
        @file.dependency.each do |dep|
          io << "require \"#{relative_require_path(dep)}\"\n"
        end
        io << "\n" unless @file.dependency.empty?
      end

      private def relative_require_path(dep : String) : String
        target = dep.sub(/\.proto$/, ".pb.cr")
        current_dir = File.dirname(output_name)
        return "./#{target}" if current_dir == "."

        current_parts = current_dir.split('/')
        target_parts = target.split('/')

        while current_parts.present? && target_parts.present? && current_parts.first == target_parts.first
          current_parts.shift
          target_parts.shift
        end

        relative_parts = [] of String
        current_parts.size.times { relative_parts << ".." }
        relative_parts.concat(target_parts)

        relative = relative_parts.join('/')
        relative.starts_with?(".") ? relative : "./#{relative}"
      end

      private def emit_body(io : IO) : Nil
        mod = NamingPolicy.package_to_module(@file.package)
        indent = ""

        if mod
          mod.split("::").each do |part|
            io << "module #{part}\n"
          end
          indent = "  "
        end

        @file.enum_type.each { |enum_desc| emit_enum(io, enum_desc, indent) }
        @file.message_type.each { |message_desc| emit_message(io, message_desc, indent) }
        @file.service.each { |service_desc| emit_service(io, service_desc, indent) }
        emit_extensions(io, indent)

        if mod
          mod.split("::").size.times { io << "end\n" }
        end
      end

      private def emit_service(io : IO, service : Bootstrap::ServiceDescriptorProto, indent : String) : Nil
        full_service_name = @file.package.empty? ? service.name : "#{@file.package}.#{service.name}"

        io << "#{indent}module #{service.name}\n"
        io << "#{indent}  METHODS = [\n"
        service.method.each do |method_desc|
          method_path = "/#{full_service_name}/#{method_desc.name}"
          io << "#{indent}    {\n"
          io << "#{indent}      name: #{method_desc.name.inspect},\n"
          io << "#{indent}      request_type: #{method_desc.input_type.inspect},\n"
          io << "#{indent}      response_type: #{method_desc.output_type.inspect},\n"
          io << "#{indent}      client_streaming: #{method_desc.client_streaming?},\n"
          io << "#{indent}      server_streaming: #{method_desc.server_streaming?},\n"
          io << "#{indent}      path: #{method_path.inspect},\n"
          io << "#{indent}    },\n"
        end
        io << "#{indent}  ] of NamedTuple(name: String, request_type: String, response_type: String, client_streaming: Bool, server_streaming: Bool, path: String)\n"
        io << "#{indent}end\n\n"
      end

      private def emit_extensions(io : IO, indent : String) : Nil
        extension_fields = all_extension_fields
        return if extension_fields.empty?

        io << "#{indent}module Extensions\n"
        io << "#{indent}  struct ExtensionDescriptor\n"
        io << "#{indent}    getter name : String\n"
        io << "#{indent}    getter extendee : String\n"
        io << "#{indent}    getter number : Int32\n"
        io << "#{indent}    getter label : Proto::Bootstrap::FieldLabel\n"
        io << "#{indent}    getter type : Proto::Bootstrap::FieldType\n"
        io << "#{indent}    getter type_name : String\n\n"
        io << "#{indent}    def initialize(@name : String, @extendee : String, @number : Int32, @label : Proto::Bootstrap::FieldLabel, @type : Proto::Bootstrap::FieldType, @type_name : String)\n"
        io << "#{indent}    end\n"
        io << "#{indent}  end\n\n"

        constant_counts = Hash(String, Int32).new(0)
        extension_fields.each do |field|
          base_name = extension_constant_name(field.name)
          constant_counts[base_name] += 1
          suffix = constant_counts[base_name]
          const_name = suffix == 1 ? base_name : "#{base_name}_#{suffix}"
          io << "#{indent}  #{const_name} = ExtensionDescriptor.new(\n"
          io << "#{indent}    name: #{field.name.inspect},\n"
          io << "#{indent}    extendee: #{field.extendee.inspect},\n"
          io << "#{indent}    number: #{field.number},\n"
          io << "#{indent}    label: Proto::Bootstrap::FieldLabel::#{field.label},\n"
          io << "#{indent}    type: Proto::Bootstrap::FieldType::#{field.type},\n"
          io << "#{indent}    type_name: #{field.type_name.inspect},\n"
          io << "#{indent}  )\n\n"
        end

        io << "#{indent}  ALL = [\n"
        constant_counts.each do |base_name, count|
          if count == 1
            io << "#{indent}    #{base_name},\n"
          else
            (1..count).each do |idx|
              io << "#{indent}    #{base_name}_#{idx},\n"
            end
          end
        end
        io << "#{indent}  ] of ExtensionDescriptor\n"
        io << "#{indent}end\n\n"
      end

      private def all_extension_fields : Array(Bootstrap::FieldDescriptorProto)
        fields = [] of Bootstrap::FieldDescriptorProto
        fields.concat(@file.extension)
        @file.message_type.each do |message_desc|
          collect_message_extensions(message_desc, fields)
        end
        fields.select { |field| !field.extendee.empty? }
      end

      private def collect_message_extensions(msg : Bootstrap::DescriptorProto, fields : Array(Bootstrap::FieldDescriptorProto)) : Nil
        fields.concat(msg.extension)
        msg.nested_type.each do |nested_msg|
          collect_message_extensions(nested_msg, fields)
        end
      end

      private def extension_constant_name(field_name : String) : String
        oneof_case_value_name(field_name)
      end

      private def emit_enum(io : IO, en : Bootstrap::EnumDescriptorProto, indent : String) : Nil
        io << "#{indent}enum #{en.name} : Int32\n"
        en.value.each do |v|
          io << "#{indent}  #{enum_member_name(v.name)} = #{v.number}\n"
        end
        io << "\n"
        io << "#{indent}  def self.from_raw?(raw : Int32) : self?\n"
        io << "#{indent}    case raw\n"
        seen_numbers = Set(Int32).new
        en.value.each do |v|
          next if seen_numbers.includes?(v.number)
          seen_numbers.add(v.number)
          io << "#{indent}    when #{v.number} then #{enum_member_name(v.name)}\n"
        end
        io << "#{indent}    end\n"
        io << "#{indent}  end\n"
        io << "#{indent}end\n\n"
      end

      private def enum_member_name(name : String) : String
        normalized = name.gsub(/[^A-Za-z0-9_]/, "_")
        if normalized.empty?
          normalized = "VALUE"
        elsif normalized[0].ascii_number?
          normalized = "VALUE_#{normalized}"
        end

        if normalized[0].ascii_lowercase?
          normalized = normalized.upcase
        end

        normalized
      end

      private def emit_message(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        validate_supported_field_types!(msg)
        validate_identifier_collisions!(msg)

        io << "#{indent}class #{msg.name}\n"
        io << "#{indent}  include Proto::Message\n\n"

        # Nested enums first
        msg.enum_type.each { |enum_desc| emit_enum(io, enum_desc, indent + "  ") }

        # Nested messages
        msg.nested_type.each { |nested_msg| emit_message(io, nested_msg, indent + "  ") }

        # Oneof case enums (skip synthetic proto3_optional oneofs)
        msg.oneof_decl.each_with_index do |oneof_desc, oneof_index|
          next if synthetic_oneof?(msg, oneof_index)
          emit_oneof_case_enum(io, msg, oneof_desc, oneof_index, indent + "  ")
        end

        # Properties: real oneof case trackers first, then all fields
        real_oneof_indices = (0...msg.oneof_decl.size).reject { |idx| synthetic_oneof?(msg, idx) }
        unless real_oneof_indices.empty?
          real_oneof_indices.each do |idx|
            oneof_desc = msg.oneof_decl[idx]
            case_enum = oneof_case_enum_name(oneof_desc.name)
            case_prop = oneof_case_prop_name(oneof_desc.name)
            io << "#{indent}  getter #{case_prop} : #{case_enum} = #{case_enum}::NONE\n"
          end
          io << "\n"
        end

        tracked_presence_fields = msg.field.select { |field_desc| tracked_presence_field?(field_desc) }
        unless tracked_presence_fields.empty?
          tracked_presence_fields.each do |field_desc|
            io << "#{indent}  getter? #{field_presence_identifier(field_desc)} : Bool = false\n"
          end
          io << "\n"
        end
        msg.field.each { |field_desc| emit_property(io, field_desc, msg, indent + "  ") }

        helper_section_emitted = false

        unless real_oneof_indices.empty?
          io << "\n"
          real_oneof_indices.each do |idx|
            emit_oneof_helpers(io, msg, msg.oneof_decl[idx], idx, indent + "  ")
          end
          helper_section_emitted = true
        end

        unless tracked_presence_fields.empty?
          io << "\n" unless helper_section_emitted
          emit_tracked_presence_helpers(io, tracked_presence_fields, indent + "  ")
          helper_section_emitted = true
        end

        derived_presence_fields = msg.field.select { |field_desc| derived_presence_field?(field_desc) }
        unless derived_presence_fields.empty?
          io << "\n" unless helper_section_emitted
          emit_derived_presence_helpers(io, derived_presence_fields, indent + "  ")
          helper_section_emitted = true
        end

        if emits_deep_required_validation?(msg)
          io << "\n" unless helper_section_emitted
          emit_validation_methods(io, msg, indent + "  ")
        end

        io << "\n"

        # decode class method
        emit_decode(io, msg, indent + "  ")
        io << "\n"

        # encode instance method
        emit_encode(io, msg, indent + "  ")
        io << "\n"

        # == operator
        emit_equality(io, msg, indent + "  ")

        io << "#{indent}end\n"
      end

      private def validate_supported_field_types!(msg : Bootstrap::DescriptorProto) : Nil
        msg.field.each do |field|
          if field.type == Bootstrap::FieldType::TYPE_GROUP
            raise "TYPE_GROUP is not supported yet (#{msg.name}.#{field.name})"
          end
        end
      end

      private def emit_property(io : IO, field : Bootstrap::FieldDescriptorProto, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        fname = field_identifier(field)
        crystal_type = crystal_type_for(field)
        default = default_value_for(field)
        if real_oneof_field?(field, msg) || tracked_presence_field?(field)
          io << "#{indent}getter #{fname} : #{crystal_type} = #{default}\n"
        else
          io << "#{indent}property #{fname} : #{crystal_type} = #{default}\n"
        end
      end

      private def emit_decode(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        io << "#{indent}def self.decode_partial(io : IO) : self\n"
        emit_decode_body(io, msg, indent)
        io << "#{indent}end\n\n"

        io << "#{indent}def self.decode(io : IO) : self\n"
        io << "#{indent}  msg = decode_partial(io)\n"
        if emits_deep_required_validation?(msg)
          io << "#{indent}  msg.validate_required_deep!\n"
        end
        io << "#{indent}  msg\n"
        io << "#{indent}end\n"
      end

      private def emit_decode_body(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        io << "#{indent}  msg = new\n"
        io << "#{indent}  reader = Proto::Wire::Reader.new(io)\n"
        io << "#{indent}  while tag = reader.read_tag\n"
        io << "#{indent}    fn, wt = tag\n"
        io << "#{indent}    case fn\n"

        msg.field.each do |field_desc|
          io << "#{indent}    when #{field_desc.number}\n"
          emit_field_decode(io, field_desc, msg, indent + "      ")
        end

        io << "#{indent}    else\n"
        io << "#{indent}      msg.capture_unknown_field(reader, fn, wt)\n"
        io << "#{indent}    end\n"
        io << "#{indent}  end\n"
        io << "#{indent}  msg\n"
      end

      private def emit_field_decode(io : IO, field : Bootstrap::FieldDescriptorProto, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        fname = field_identifier(field)
        repeated = field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        type = field.type

        if map_entry_descriptor_for(field)
          emit_expected_wire_type_check(io, field.number, "Proto::WireType::LENGTH_DELIMITED", indent)
          entry_type = resolve_type(field.type_name)
          io << "#{indent}entry = #{entry_type}.decode_partial(reader.read_embedded)\n"
          io << "#{indent}msg.#{fname}[entry.key] = entry.value\n"
          return
        end

        if type == Bootstrap::FieldType::TYPE_MESSAGE
          emit_message_field_decode(io, field, repeated, indent)
        elsif type == Bootstrap::FieldType::TYPE_ENUM
          emit_enum_field_decode(io, field, repeated, indent)
        elsif repeated && PACKABLE_TYPES.includes?(type)
          reader_method = SCALAR_READER_MAP[type]? || "read_uint64"
          # Determine packed reader method
          packed_reader = packed_reader_for(type)
          unpacked_wire_type = SCALAR_WIRE_TYPE_MAP[type]? || "Proto::WireType::VARINT"
          io << "#{indent}if wt == Proto::WireType::LENGTH_DELIMITED\n"
          io << "#{indent}  reader.#{packed_reader} { |v| msg.#{fname} << #{packed_convert(type, "v")} }\n"
          io << "#{indent}elsif wt == #{unpacked_wire_type}\n"
          io << "#{indent}  msg.#{fname} << reader.#{reader_method}\n"
          io << "#{indent}else\n"
          emit_wire_type_mismatch(
            io,
            field.number,
            "Proto::WireType::LENGTH_DELIMITED or #{unpacked_wire_type}",
            indent + "  "
          )
          io << "#{indent}end\n"
        else
          expected_wire_type = SCALAR_WIRE_TYPE_MAP[type]? || "Proto::WireType::VARINT"
          emit_expected_wire_type_check(io, field.number, expected_wire_type, indent)
          reader_method = SCALAR_READER_MAP[type]? || "read_uint64"
          reader_call = "reader.#{reader_method}"
          if repeated
            io << "#{indent}msg.#{fname} << #{reader_call}\n"
          else
            io << "#{indent}msg.#{fname} = #{reader_call}\n"
          end
        end
      end

      private def emit_message_field_decode(io : IO, field : Bootstrap::FieldDescriptorProto, repeated : Bool, indent : String) : Nil
        fname = field_identifier(field)
        crystal_type = resolve_type(field.type_name)
        emit_expected_wire_type_check(io, field.number, "Proto::WireType::LENGTH_DELIMITED", indent)
        if repeated
          io << "#{indent}msg.#{fname} << #{crystal_type}.decode_partial(reader.read_embedded)\n"
        else
          io << "#{indent}msg.#{fname} = #{crystal_type}.decode_partial(reader.read_embedded)\n"
        end
      end

      private def emit_enum_field_decode(io : IO, field : Bootstrap::FieldDescriptorProto, repeated : Bool, indent : String) : Nil
        fname = field_identifier(field)
        crystal_type = resolve_type(field.type_name)
        if repeated
          io << "#{indent}if wt == Proto::WireType::LENGTH_DELIMITED\n"
          io << "#{indent}  reader.read_packed_varint do |v|\n"
          if open_enum_field?(field)
            io << "#{indent}    msg.#{fname} << #{open_enum_type_for(field)}.new(Proto::Wire::Reader.int32_from_varint(v))\n"
          else
            io << "#{indent}    begin\n"
            io << "#{indent}      msg.#{fname} << #{crystal_type}.from_value(Proto::Wire::Reader.int32_from_varint(v))\n"
            io << "#{indent}    rescue ArgumentError\n"
            io << "#{indent}      msg.add_unknown_varint(fn, v)\n"
            io << "#{indent}    end\n"
          end
          io << "#{indent}  end\n"
          io << "#{indent}elsif wt == Proto::WireType::VARINT\n"
          io << "#{indent}  _raw_u64 = reader.read_uint64\n"
          io << "#{indent}  _raw = Proto::Wire::Reader.int32_from_varint(_raw_u64)\n"
          if open_enum_field?(field)
            io << "#{indent}  msg.#{fname} << #{open_enum_type_for(field)}.new(_raw)\n"
          else
            io << "#{indent}  begin\n"
            io << "#{indent}    msg.#{fname} << #{crystal_type}.from_value(_raw)\n"
            io << "#{indent}  rescue ArgumentError\n"
            io << "#{indent}    msg.add_unknown_varint(fn, _raw_u64)\n"
            io << "#{indent}  end\n"
          end
          io << "#{indent}else\n"
          emit_wire_type_mismatch(
            io,
            field.number,
            "Proto::WireType::LENGTH_DELIMITED or Proto::WireType::VARINT",
            indent + "  "
          )
          io << "#{indent}end\n"
        else
          emit_expected_wire_type_check(io, field.number, "Proto::WireType::VARINT", indent)
          io << "#{indent}_raw_u64 = reader.read_uint64\n"
          io << "#{indent}_raw = Proto::Wire::Reader.int32_from_varint(_raw_u64)\n"
          if open_enum_field?(field)
            io << "#{indent}msg.#{fname} = #{open_enum_type_for(field)}.new(_raw)\n"
          else
            io << "#{indent}begin\n"
            io << "#{indent}  msg.#{fname} = #{crystal_type}.from_value(_raw)\n"
            io << "#{indent}rescue ArgumentError\n"
            io << "#{indent}  msg.add_unknown_varint(fn, _raw_u64)\n"
            io << "#{indent}end\n"
          end
        end
      end

      private def emit_expected_wire_type_check(io : IO, field_number : Int32, expected_wire_type : String, indent : String) : Nil
        io << "#{indent}unless wt == #{expected_wire_type}\n"
        emit_wire_type_mismatch(io, field_number, expected_wire_type, indent + "  ")
        io << "#{indent}end\n"
      end

      private def emit_wire_type_mismatch(io : IO, field_number : Int32, expected : String, indent : String) : Nil
        io << "#{indent}raise Proto::DecodeError.new(\"wire type mismatch for field #{field_number}: expected #{expected}, got \" + wt.to_s)\n"
      end

      # Returns the packed reader method name for a packable scalar type.
      private def packed_reader_for(type : Bootstrap::FieldType) : String
        case type
        when Bootstrap::FieldType::TYPE_FLOAT    then "read_packed_float"
        when Bootstrap::FieldType::TYPE_DOUBLE   then "read_packed_double"
        when Bootstrap::FieldType::TYPE_FIXED32  then "read_packed_fixed32"
        when Bootstrap::FieldType::TYPE_SFIXED32 then "read_packed_sfixed32"
        when Bootstrap::FieldType::TYPE_FIXED64  then "read_packed_fixed64"
        when Bootstrap::FieldType::TYPE_SFIXED64 then "read_packed_sfixed64"
        else
          "read_packed_varint"
        end
      end

      # Converts the raw value yielded by a packed reader to the correct Crystal type.
      # For typed packed readers (float, double, sfixed*) no conversion is needed.
      private def packed_convert(type : Bootstrap::FieldType, var : String) : String
        case type
        when Bootstrap::FieldType::TYPE_INT32  then "#{var}.to_i32!"
        when Bootstrap::FieldType::TYPE_INT64  then "#{var}.to_i64!"
        when Bootstrap::FieldType::TYPE_UINT32 then "#{var}.to_u32!"
        when Bootstrap::FieldType::TYPE_UINT64 then var
        when Bootstrap::FieldType::TYPE_BOOL   then "#{var} != 0_u64"
        when Bootstrap::FieldType::TYPE_SINT32
          "(#{var}.to_u32! >> 1).to_i32 ^ -(#{var}.to_u32! & 1_u32).to_i32"
        when Bootstrap::FieldType::TYPE_SINT64
          "(#{var} >> 1).to_i64 ^ -(#{var} & 1_u64).to_i64"
        else
          var # fixed32/sfixed32/fixed64/sfixed64/float/double: already correct type
        end
      end

      private def emit_encode(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        io << "#{indent}def encode_partial(io : IO) : Nil\n"
        emit_encode_body(io, msg, indent)
        io << "#{indent}end\n\n"

        io << "#{indent}def encode(io : IO) : Nil\n"
        if emits_deep_required_validation?(msg)
          io << "#{indent}  validate_required_deep!\n"
        end
        io << "#{indent}  encode_partial(io)\n"
        io << "#{indent}end\n"
      end

      private def emit_encode_body(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        io << "#{indent}  w = Proto::Wire::Writer.new(io)\n"

        msg.field.each do |field_desc|
          emit_field_encode(io, field_desc, msg, indent + "  ")
        end

        io << "#{indent}  write_unknown_fields(w)\n"
      end

      private def emit_field_encode(io : IO, field : Bootstrap::FieldDescriptorProto, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        if oneof_index = field.oneof_index
          # proto3_optional fields live in a synthetic oneof; skip the case guard
          # and let emit_field_encode_body handle nil-guarding via proto3_optional?.
          unless synthetic_oneof?(msg, oneof_index)
            if oneof = msg.oneof_decl[oneof_index]?
              case_enum = oneof_case_enum_name(oneof.name)
              case_prop = oneof_case_prop_name(oneof.name)
              case_value = oneof_case_value_name(field.name)
              io << "#{indent}if #{case_prop} == #{case_enum}::#{case_value}\n"
              emit_field_encode_body(io, field, indent + "  ")
              io << "#{indent}end\n"
              return
            end
          end
        end

        emit_field_encode_body(io, field, indent)
      end

      private def emit_field_encode_body(io : IO, field : Bootstrap::FieldDescriptorProto, indent : String) : Nil
        if field.proto3_optional?
          emit_proto3_optional_field_encode(io, field, indent)
        else
          emit_regular_field_encode(io, field, indent)
        end
      end

      private def emit_regular_field_encode(io : IO, field : Bootstrap::FieldDescriptorProto, indent : String) : Nil
        fname = field_identifier(field)
        repeated = field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        type = field.type
        num = field.number

        if map_entry_descriptor_for(field)
          entry_type = resolve_type(field.type_name)
          io << "#{indent}#{fname}.each do |k, v|\n"
          io << "#{indent}  entry = #{entry_type}.new\n"
          io << "#{indent}  entry.key = k\n"
          io << "#{indent}  entry.value = v\n"
          io << "#{indent}  w.write_embedded(#{num}) { |sub| entry.encode_partial(sub) }\n"
          io << "#{indent}end\n"
          return
        end

        if type == Bootstrap::FieldType::TYPE_MESSAGE
          if repeated
            io << "#{indent}#{fname}.each do |item|\n"
            io << "#{indent}  w.write_embedded(#{num}) { |sub| item.encode_partial(sub) }\n"
            io << "#{indent}end\n"
          else
            io << "#{indent}if _v = #{fname}\n"
            io << "#{indent}  w.write_embedded(#{num}) { |sub| _v.encode_partial(sub) }\n"
            io << "#{indent}end\n"
          end
        elsif type == Bootstrap::FieldType::TYPE_ENUM
          emit_enum_field_encode(io, field, repeated, num, indent)
        elsif repeated && PACKABLE_TYPES.includes?(type)
          # proto3: emit packed
          if type == Bootstrap::FieldType::TYPE_ENUM
            io << "#{indent}w.write_packed(#{num}) do |buf|\n"
            io << "#{indent}  sub = Proto::Wire::Writer.new(buf)\n"
            io << "#{indent}  #{fname}.each { |item| sub.write_int32(#{enum_encode_value_expr(field, "item")}) }\n"
            io << "#{indent}end\n"
          else
            writer_method = SCALAR_WRITER_MAP[type]? || "write_uint64"
            io << "#{indent}w.write_packed(#{num}) do |buf|\n"
            io << "#{indent}  sub = Proto::Wire::Writer.new(buf)\n"
            io << "#{indent}  #{fname}.each { |item| sub.#{writer_method}(item) }\n"
            io << "#{indent}end\n"
          end
        else
          emit_scalar_field_encode(io, field, repeated, num, indent)
        end
      end

      private def emit_enum_field_encode(io : IO, field : Bootstrap::FieldDescriptorProto, repeated : Bool, num : Int32, indent : String) : Nil
        fname = field_identifier(field)
        if repeated
          io << "#{indent}w.write_packed(#{num}) do |buf|\n"
          io << "#{indent}  sub = Proto::Wire::Writer.new(buf)\n"
          io << "#{indent}  #{fname}.each { |item| sub.write_int32(#{enum_encode_value_expr(field, "item")}) }\n"
          io << "#{indent}end\n"
        else
          if tracked_presence_field?(field)
            io << "#{indent}if #{field_presence_identifier(field)}?\n"
            io << "#{indent}  w.write_tag(#{num}, Proto::WireType::VARINT)\n"
            io << "#{indent}  w.write_int32(#{enum_encode_value_expr(field, fname)})\n"
            io << "#{indent}end\n"
          elsif proto3_implicit_presence_field?(field)
            io << "#{indent}if #{enum_encode_value_expr(field, fname)} != 0\n"
            io << "#{indent}  w.write_tag(#{num}, Proto::WireType::VARINT)\n"
            io << "#{indent}  w.write_int32(#{enum_encode_value_expr(field, fname)})\n"
            io << "#{indent}end\n"
          else
            io << "#{indent}w.write_tag(#{num}, Proto::WireType::VARINT)\n"
            io << "#{indent}w.write_int32(#{enum_encode_value_expr(field, fname)})\n"
          end
        end
      end

      private def crystal_type_for(field : Bootstrap::FieldDescriptorProto) : String
        if map_entry = map_entry_descriptor_for(field)
          key_field = map_entry.field.find { |field_desc| field_desc.name == "key" }
          value_field = map_entry.field.find { |field_desc| field_desc.name == "value" }
          if key_field && value_field
            key_type = base_crystal_type(key_field)
            value_type = base_crystal_type(value_field)
            return "Hash(#{key_type}, #{value_type})"
          end
        end

        repeated = field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        type = field.type

        base = if type == Bootstrap::FieldType::TYPE_MESSAGE
                 resolve_type(field.type_name)
               elsif type == Bootstrap::FieldType::TYPE_ENUM
                 open_enum_field?(field) ? open_enum_type_for(field) : resolve_type(field.type_name)
               else
                 SCALAR_TYPE_MAP[type]? || "Bytes"
               end

        if repeated
          "Array(#{base})"
        elsif field.proto3_optional? || type == Bootstrap::FieldType::TYPE_MESSAGE
          "#{base}?"
        else
          base
        end
      end

      private def default_value_for(field : Bootstrap::FieldDescriptorProto) : String
        return "nil" if field.proto3_optional?
        return "nil" if field.type == Bootstrap::FieldType::TYPE_MESSAGE &&
                        field.label != Bootstrap::FieldLabel::LABEL_REPEATED

        if map_default = map_default_value_for(field)
          return map_default
        end

        if field.label == Bootstrap::FieldLabel::LABEL_REPEATED
          return "[] of #{base_crystal_type(field)}"
        end

        if explicit = explicit_default_value_for(field)
          return explicit
        end

        fallback_default_value_for(field)
      end

      private def map_default_value_for(field : Bootstrap::FieldDescriptorProto) : String?
        map_entry = map_entry_descriptor_for(field)
        return unless map_entry

        key_field = map_entry.field.find { |field_desc| field_desc.name == "key" }
        value_field = map_entry.field.find { |field_desc| field_desc.name == "value" }
        return unless key_field && value_field

        key_type = base_crystal_type(key_field)
        value_type = base_crystal_type(value_field)
        "{} of #{key_type} => #{value_type}"
      end

      private def fallback_default_value_for(field : Bootstrap::FieldDescriptorProto) : String
        case field.type
        when Bootstrap::FieldType::TYPE_STRING then "\"\""
        when Bootstrap::FieldType::TYPE_BYTES  then "Bytes.empty"
        when Bootstrap::FieldType::TYPE_BOOL   then "false"
        when Bootstrap::FieldType::TYPE_FLOAT  then "0.0_f32"
        when Bootstrap::FieldType::TYPE_DOUBLE then "0.0_f64"
        when Bootstrap::FieldType::TYPE_MESSAGE
          crystal = resolve_type(field.type_name)
          "#{crystal}.new"
        when Bootstrap::FieldType::TYPE_ENUM
          if open_enum_field?(field)
            "#{open_enum_type_for(field)}.new(0)"
          else
            crystal = resolve_type(field.type_name)
            "#{crystal}.new(0)"
          end
        else
          "0"
        end
      end

      # Convert FieldDescriptorProto.default_value (text form) into a Crystal
      # expression for generated property initialization.
      private def explicit_default_value_for(field : Bootstrap::FieldDescriptorProto) : String?
        default_text = field.default_value
        return if default_text.empty?

        case field.type
        when Bootstrap::FieldType::TYPE_BOOL
          default_text == "true" ? "true" : "false"
        when Bootstrap::FieldType::TYPE_STRING
          default_text.inspect
        when Bootstrap::FieldType::TYPE_ENUM
          if open_enum_field?(field)
            "#{open_enum_type_for(field)}.new(#{resolve_type(field.type_name)}::#{default_text})"
          else
            "#{resolve_type(field.type_name)}::#{default_text}"
          end
        when Bootstrap::FieldType::TYPE_FLOAT
          float_default_literal(default_text, "f32")
        when Bootstrap::FieldType::TYPE_DOUBLE
          float_default_literal(default_text, "f64")
        else
          integer_default_literal_for(field.type, default_text)
        end
      end

      private def integer_default_literal_for(type : Bootstrap::FieldType, value : String) : String?
        case type
        when Bootstrap::FieldType::TYPE_INT32,
             Bootstrap::FieldType::TYPE_SINT32,
             Bootstrap::FieldType::TYPE_SFIXED32
          integer_default_literal(value, "Int32")
        when Bootstrap::FieldType::TYPE_INT64,
             Bootstrap::FieldType::TYPE_SINT64,
             Bootstrap::FieldType::TYPE_SFIXED64
          integer_default_literal(value, "Int64")
        when Bootstrap::FieldType::TYPE_UINT32,
             Bootstrap::FieldType::TYPE_FIXED32
          integer_default_literal(value, "UInt32")
        when Bootstrap::FieldType::TYPE_UINT64,
             Bootstrap::FieldType::TYPE_FIXED64
          integer_default_literal(value, "UInt64")
        end
      end

      private def float_default_literal(value : String, suffix : String) : String
        case value
        when "inf"
          "Float#{suffix == "f32" ? "32" : "64"}::INFINITY"
        when "-inf"
          "-Float#{suffix == "f32" ? "32" : "64"}::INFINITY"
        when "nan"
          "Float#{suffix == "f32" ? "32" : "64"}::NAN"
        else
          if suffix == "f32"
            value.to_f32
          else
            value.to_f64
          end
          "#{value}_#{suffix}"
        end
      rescue ArgumentError
        raise "invalid float default literal '#{value}'"
      rescue OverflowError
        raise "float default literal out of range '#{value}'"
      end

      private def integer_default_literal(value : String, kind : String) : String
        case kind
        when "Int32"
          parsed = value.to_i128
          if parsed < Int32::MIN || parsed > Int32::MAX
            raise "Int32 default literal out of range '#{value}'"
          end
          parsed.to_i32.to_s
        when "Int64"
          parsed = value.to_i128
          if parsed < Int64::MIN || parsed > Int64::MAX
            raise "Int64 default literal out of range '#{value}'"
          end
          parsed.to_i64.to_s
        when "UInt32"
          parsed = value.to_u128
          if parsed > UInt32::MAX
            raise "UInt32 default literal out of range '#{value}'"
          end
          parsed.to_u32.to_s
        when "UInt64"
          parsed = value.to_u128
          if parsed > UInt64::MAX
            raise "UInt64 default literal out of range '#{value}'"
          end
          parsed.to_u64.to_s
        else
          raise "unsupported integer default kind: #{kind}"
        end
      rescue ArgumentError
        raise "invalid #{kind} default literal '#{value}'"
      end

      private def base_crystal_type(field : Bootstrap::FieldDescriptorProto) : String
        type = field.type
        if type == Bootstrap::FieldType::TYPE_MESSAGE
          resolve_type(field.type_name)
        elsif type == Bootstrap::FieldType::TYPE_ENUM
          open_enum_field?(field) ? open_enum_type_for(field) : resolve_type(field.type_name)
        else
          SCALAR_TYPE_MAP[type]? || "Bytes"
        end
      end

      private def resolve_type(type_name : String) : String
        if resolver = @type_resolver
          return resolver.resolve(type_name, @file.package)
        end
        entry = @index.resolve(type_name)
        return entry.crystal_name if entry
        # Fallback: strip leading dot and convert dots to ::
        NamingPolicy.fq_type_to_crystal(type_name)
      end

      private def validate_identifier_collisions!(msg : Bootstrap::DescriptorProto) : Nil
        seen = Hash(String, String).new

        register_name = ->(name : String, detail : String) do
          if other = seen[name]?
            raise "identifier collision in #{msg.name}: '#{name}' (#{other} vs #{detail})"
          end
          seen[name] = detail
        end

        msg.field.each do |field|
          register_name.call(field_identifier(field), "field #{field.name}")
          register_name.call(field_clear_method_name(field), "clear helper for #{field.name}")
          if tracked_presence_field?(field) || derived_presence_field?(field)
            register_name.call(field_presence_identifier(field), "presence helper for #{field.name}")
          end
        end

        msg.oneof_decl.each_with_index do |oneof_desc, idx|
          next if synthetic_oneof?(msg, idx)
          register_name.call(oneof_case_prop_name(oneof_desc.name), "oneof case property #{oneof_desc.name}")
          register_name.call(oneof_clear_method_name(oneof_desc.name), "oneof clear helper #{oneof_desc.name}")
        end

        msg.enum_type.each do |enum_desc|
          enum_seen = Set(String).new
          enum_desc.value.each do |value|
            normalized = enum_member_name(value.name)
            if enum_seen.includes?(normalized)
              raise "enum member collision in #{msg.name}.#{enum_desc.name}: '#{normalized}'"
            end
            enum_seen.add(normalized)
          end
        end
      end

      private def map_entry_descriptor_for(field : Bootstrap::FieldDescriptorProto) : Bootstrap::DescriptorProto?
        return unless field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        return unless field.type == Bootstrap::FieldType::TYPE_MESSAGE

        descriptor = resolve_message_descriptor(field.type_name)
        return unless descriptor
        return unless descriptor.options.try(&.map_entry?)
        key = descriptor.field.find { |field_desc| field_desc.name == "key" && field_desc.number == 1 }
        value = descriptor.field.find { |field_desc| field_desc.name == "value" && field_desc.number == 2 }
        return unless key && value

        descriptor
      end

      private def resolve_message_descriptor(type_name : String) : Bootstrap::DescriptorProto?
        fq = type_name.starts_with?('.') ? type_name[1..] : type_name
        parts = fq.split('.')
        package_parts = @file.package.empty? ? [] of String : @file.package.split('.')

        idx = 0
        if !package_parts.empty? && parts.size >= package_parts.size && parts[0, package_parts.size] == package_parts
          idx = package_parts.size
        elsif !package_parts.empty?
          return
        end

        current = @file.message_type
        descriptor = nil.as(Bootstrap::DescriptorProto?)
        while idx < parts.size
          name = parts[idx]
          descriptor = current.find { |message_desc| message_desc.name == name }
          return unless descriptor
          current = descriptor.nested_type
          idx += 1
        end

        descriptor
      end

      private def emit_proto3_optional_field_encode(io : IO, field : Bootstrap::FieldDescriptorProto, indent : String) : Nil
        fname = field_identifier(field)
        type = field.type
        num = field.number
        io << "#{indent}if _v = #{fname}\n"
        if type == Bootstrap::FieldType::TYPE_MESSAGE
          io << "#{indent}  w.write_embedded(#{num}) { |sub| _v.encode_partial(sub) }\n"
        elsif type == Bootstrap::FieldType::TYPE_ENUM
          io << "#{indent}  w.write_tag(#{num}, Proto::WireType::VARINT)\n"
          io << "#{indent}  w.write_int32(#{enum_encode_value_expr(field, "_v")})\n"
        else
          writer_method = SCALAR_WRITER_MAP[type]? || "write_uint64"
          wire_const = SCALAR_WIRE_TYPE_MAP[type]? || "Proto::WireType::VARINT"
          io << "#{indent}  w.write_tag(#{num}, #{wire_const})\n"
          io << "#{indent}  w.#{writer_method}(_v)\n"
        end
        io << "#{indent}end\n"
      end

      private def emit_scalar_field_encode(io : IO, field : Bootstrap::FieldDescriptorProto,
                                           repeated : Bool, num : Int32, indent : String) : Nil
        fname = field_identifier(field)
        writer_method = SCALAR_WRITER_MAP[field.type]? || "write_uint64"
        wire_const = SCALAR_WIRE_TYPE_MAP[field.type]? || "Proto::WireType::VARINT"

        if repeated
          io << "#{indent}#{fname}.each do |item|\n"
          io << "#{indent}  w.write_tag(#{num}, #{wire_const})\n"
          io << "#{indent}  w.#{writer_method}(item)\n"
          io << "#{indent}end\n"
          return
        end

        if tracked_presence_field?(field)
          io << "#{indent}if #{field_presence_identifier(field)}?\n"
          io << "#{indent}  w.write_tag(#{num}, #{wire_const})\n"
          io << "#{indent}  w.#{writer_method}(#{fname})\n"
          io << "#{indent}end\n"
        elsif proto3_implicit_presence_field?(field)
          condition = non_default_encode_condition(field, fname)
          io << "#{indent}if #{condition}\n"
          io << "#{indent}  w.write_tag(#{num}, #{wire_const})\n"
          io << "#{indent}  w.#{writer_method}(#{fname})\n"
          io << "#{indent}end\n"
        else
          io << "#{indent}w.write_tag(#{num}, #{wire_const})\n"
          io << "#{indent}w.#{writer_method}(#{fname})\n"
        end
      end

      private def open_enum_field?(field : Bootstrap::FieldDescriptorProto) : Bool
        @file.syntax == "proto3" && field.type == Bootstrap::FieldType::TYPE_ENUM
      end

      private def open_enum_type_for(field : Bootstrap::FieldDescriptorProto) : String
        "Proto::OpenEnum(#{resolve_type(field.type_name)})"
      end

      private def enum_encode_value_expr(field : Bootstrap::FieldDescriptorProto, value_expr : String) : String
        open_enum_field?(field) ? "#{value_expr}.raw" : "#{value_expr}.value"
      end

      private def proto3_implicit_presence_field?(field : Bootstrap::FieldDescriptorProto) : Bool
        return false unless @file.syntax == "proto3"
        return false if field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        return false if field.proto3_optional?
        return false if field.oneof_index
        field.type != Bootstrap::FieldType::TYPE_MESSAGE
      end

      private def non_default_encode_condition(field : Bootstrap::FieldDescriptorProto, value_expr : String) : String
        case field.type
        when Bootstrap::FieldType::TYPE_STRING,
             Bootstrap::FieldType::TYPE_BYTES
          "!#{value_expr}.empty?"
        when Bootstrap::FieldType::TYPE_BOOL
          value_expr
        when Bootstrap::FieldType::TYPE_FLOAT,
             Bootstrap::FieldType::TYPE_DOUBLE
          "#{value_expr}.to_bits != 0"
        else
          "#{value_expr} != 0"
        end
      end
    end
  end
end
