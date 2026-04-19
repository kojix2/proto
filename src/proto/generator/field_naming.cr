module Proto
  module Generator
    module FieldNaming
      private def field_identifier(field : Bootstrap::FieldDescriptorProto) : String
        crystal_identifier(field.name)
      end

      private def field_presence_identifier(field : Bootstrap::FieldDescriptorProto) : String
        "has_#{field_identifier(field)}"
      end

      private def field_clear_method_name(field : Bootstrap::FieldDescriptorProto) : String
        "clear_#{field_identifier(field)}"
      end

      private def oneof_case_prop_name(oneof_name : String) : String
        "#{crystal_identifier(oneof_name)}_case"
      end

      private def oneof_clear_method_name(oneof_name : String) : String
        "clear_#{crystal_identifier(oneof_name)}"
      end

      private def crystal_identifier(name : String) : String
        ident = name
          .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
          .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
          .gsub(/[^A-Za-z0-9_]/, "_")
          .gsub(/_+/, "_")
          .sub(/^_+/, "")
          .sub(/_+$/, "")
          .downcase

        ident = "field" if ident.empty?
        ident = "field_#{ident}" if ident[0].ascii_number?
        crystal_keyword?(ident) ? "#{ident}_" : ident
      end

      private def crystal_keyword?(name : String) : Bool
        case name
        when "abstract", "alias", "annotation", "as", "asm", "begin", "break",
             "case", "class", "def", "do", "else", "elsif", "end", "ensure",
             "enum", "extend", "for", "fun", "if", "in", "include", "instance_sizeof",
             "is_a?", "lib", "macro", "module", "next", "nil", "nil?", "of", "out",
             "pointerof", "private", "protected", "require", "rescue", "responds_to?",
             "return", "select", "self", "sizeof", "struct", "super", "then", "type",
             "typeof", "uninitialized", "union", "unless", "until", "verbatim", "when",
             "while", "with", "yield"
          true
        else
          false
        end
      end
    end
  end
end
