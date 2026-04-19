module Proto
  module Generator
    module MessageStructure
      private def emit_oneof_case_enum(io : IO, msg : Bootstrap::DescriptorProto,
                                       oneof : Bootstrap::OneofDescriptorProto,
                                       index : Int32, indent : String) : Nil
        case_enum = oneof_case_enum_name(oneof.name)
        fields = oneof_fields(msg, index)

        io << "#{indent}enum #{case_enum} : Int32\n"
        io << "#{indent}  NONE = 0\n"
        fields.each do |field|
          io << "#{indent}  #{oneof_case_value_name(field.name)} = #{field.number}\n"
        end
        io << "#{indent}end\n\n"
      end

      private def oneof_case_enum_name(oneof_name : String) : String
        "#{NamingPolicy.camelize(oneof_name)}Case"
      end

      private def oneof_case_value_name(field_name : String) : String
        normalized = field_name
          .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
          .gsub(/[^A-Za-z\d]/, "_")
          .upcase
        normalized.empty? ? "FIELD" : normalized
      end

      private def oneof_fields(msg : Bootstrap::DescriptorProto, index : Int32) : Array(Bootstrap::FieldDescriptorProto)
        msg.field.select { |field_desc| field_desc.oneof_index == index }
      end

      private def emit_oneof_helpers(io : IO, msg : Bootstrap::DescriptorProto,
                                     oneof : Bootstrap::OneofDescriptorProto,
                                     index : Int32, indent : String) : Nil
        fields = oneof_fields(msg, index)
        case_enum = oneof_case_enum_name(oneof.name)
        case_prop = oneof_case_prop_name(oneof.name)
        clear_method = oneof_clear_method_name(oneof.name)

        io << "#{indent}def #{clear_method} : Nil\n"
        fields.each do |field|
          io << "#{indent}  @#{field_identifier(field)} = #{default_value_for(field)}\n"
        end
        io << "#{indent}  @#{case_prop} = #{case_enum}::NONE\n"
        io << "#{indent}end\n\n"

        fields.each do |field|
          fname = field_identifier(field)
          field_type = crystal_type_for(field)
          case_value = oneof_case_value_name(field.name)

          io << "#{indent}def #{fname}=(value : #{field_type}) : #{field_type}\n"
          if field_type.ends_with?("?")
            io << "#{indent}  if value.nil?\n"
            io << "#{indent}    #{clear_method}\n"
            io << "#{indent}    return value\n"
            io << "#{indent}  end\n"
          end
          io << "#{indent}  #{clear_method}\n"
          io << "#{indent}  @#{fname} = value\n"
          io << "#{indent}  @#{case_prop} = #{case_enum}::#{case_value}\n"
          io << "#{indent}  value\n"
          io << "#{indent}end\n\n"
        end
      end

      private def emit_tracked_presence_helpers(io : IO, fields : Array(Bootstrap::FieldDescriptorProto), indent : String) : Nil
        fields.each do |field|
          fname = field_identifier(field)
          field_type = crystal_type_for(field)
          default = default_value_for(field)
          clear_method = field_clear_method_name(field)
          has_ivar = "@#{field_presence_identifier(field)}"

          io << "#{indent}def #{clear_method} : Nil\n"
          io << "#{indent}  @#{fname} = #{default}\n"
          io << "#{indent}  #{has_ivar} = false\n"
          io << "#{indent}end\n\n"

          io << "#{indent}def #{fname}=(value : #{field_type}) : #{field_type}\n"
          io << "#{indent}  @#{fname} = value\n"
          io << "#{indent}  #{has_ivar} = true\n"
          io << "#{indent}  value\n"
          io << "#{indent}end\n\n"
        end
      end

      private def emit_derived_presence_helpers(io : IO, fields : Array(Bootstrap::FieldDescriptorProto), indent : String) : Nil
        fields.each do |field|
          fname = field_identifier(field)
          io << "#{indent}def #{field_presence_identifier(field)}? : Bool\n"
          io << "#{indent}  !#{fname}.nil?\n"
          io << "#{indent}end\n\n"

          io << "#{indent}def #{field_clear_method_name(field)} : Nil\n"
          io << "#{indent}  self.#{fname} = nil\n"
          io << "#{indent}end\n\n"
        end
      end

      private def emit_validation_methods(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        return unless emits_deep_required_validation?(msg)

        io << "#{indent}def validate_required! : Nil\n"
        msg.field.each do |field|
          next unless condition = required_validation_condition(field)
          io << "#{indent}  raise Proto::RequiredFieldError.new(\"Missing required field: #{field.name}\") unless #{condition}\n"
        end
        io << "#{indent}end\n\n"

        io << "#{indent}def validate_required_deep! : Nil\n"
        io << "#{indent}  validate_required!\n"
        emit_deep_required_validation_body(io, msg, indent)
        io << "#{indent}end\n\n"
      end

      private def emit_equality(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        io << "#{indent}def ==(other : self) : Bool\n"
        msg.oneof_decl.each_with_index do |oneof_desc, idx|
          next if synthetic_oneof?(msg, idx)
          case_prop = oneof_case_prop_name(oneof_desc.name)
          io << "#{indent}  return false unless #{case_prop} == other.#{case_prop}\n"
        end
        msg.field.each do |field|
          next unless tracked_presence_field?(field)
          has_name = field_presence_identifier(field)
          io << "#{indent}  return false unless #{has_name}? == other.#{has_name}?\n"
        end
        msg.field.each do |field|
          fname = field_identifier(field)
          io << "#{indent}  return false unless #{fname} == other.#{fname}\n"
        end
        io << "#{indent}  return false unless unknown_fields == other.unknown_fields\n"
        io << "#{indent}  true\n"
        io << "#{indent}end\n"
      end

      private def synthetic_oneof?(msg : Bootstrap::DescriptorProto, index : Int32) : Bool
        oneof_fields(msg, index).all?(&.proto3_optional?)
      end

      private def real_oneof_field?(field : Bootstrap::FieldDescriptorProto, msg : Bootstrap::DescriptorProto) : Bool
        oneof_index = field.oneof_index
        return false unless oneof_index
        !synthetic_oneof?(msg, oneof_index)
      end

      private def tracked_presence_field?(field : Bootstrap::FieldDescriptorProto) : Bool
        return false unless @file.syntax == "proto2"
        return false if field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        return false if field.oneof_index
        case field.type
        when Bootstrap::FieldType::TYPE_MESSAGE
          false
        else
          true
        end
      end

      private def derived_presence_field?(field : Bootstrap::FieldDescriptorProto) : Bool
        return false if field.label == Bootstrap::FieldLabel::LABEL_REPEATED
        return true if field.proto3_optional?
        return false if field.oneof_index
        field.type == Bootstrap::FieldType::TYPE_MESSAGE
      end

      private def emits_required_validation?(msg : Bootstrap::DescriptorProto) : Bool
        msg.field.any? { |field| !required_validation_condition(field).nil? }
      end

      private def emits_deep_required_validation?(msg : Bootstrap::DescriptorProto) : Bool
        emits_required_validation?(msg) ||
          msg.field.any? { |field| field_requires_deep_validation?(field) }
      end

      private def emit_deep_required_validation_body(io : IO, msg : Bootstrap::DescriptorProto, indent : String) : Nil
        msg.field.each do |field|
          fname = field_identifier(field)
          if map_entry = map_entry_descriptor_for(field)
            value_field = map_entry.field.find { |field_desc| field_desc.name == "value" }
            next unless value_field
            next unless value_field.type == Bootstrap::FieldType::TYPE_MESSAGE

            io << "#{indent}  #{fname}.each_value do |value|\n"
            io << "#{indent}    value.validate_required_deep!\n"
            io << "#{indent}  end\n"
            next
          end

          next unless field.type == Bootstrap::FieldType::TYPE_MESSAGE

          if field.label == Bootstrap::FieldLabel::LABEL_REPEATED
            io << "#{indent}  #{fname}.each do |item|\n"
            io << "#{indent}    item.validate_required_deep!\n"
            io << "#{indent}  end\n"
          else
            io << "#{indent}  #{fname}.try &.validate_required_deep!\n"
          end
        end
      end

      private def field_requires_deep_validation?(field : Bootstrap::FieldDescriptorProto) : Bool
        if map_entry = map_entry_descriptor_for(field)
          value_field = map_entry.field.find { |field_desc| field_desc.name == "value" }
          return value_field.try(&.type) == Bootstrap::FieldType::TYPE_MESSAGE
        end

        field.type == Bootstrap::FieldType::TYPE_MESSAGE
      end

      private def required_validation_condition(field : Bootstrap::FieldDescriptorProto) : String?
        return unless @file.syntax == "proto2"
        return unless field.label == Bootstrap::FieldLabel::LABEL_REQUIRED
        return if field.label == Bootstrap::FieldLabel::LABEL_REPEATED

        if tracked_presence_field?(field) || derived_presence_field?(field)
          "#{field_presence_identifier(field)}?"
        end
      end
    end
  end
end
