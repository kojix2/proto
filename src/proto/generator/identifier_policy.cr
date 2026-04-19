module Proto
  module Generator
    module IdentifierPolicy
      extend self

      def field_identifier(field_name : String) : String
        crystal_identifier(field_name)
      end

      def enum_member_name(name : String) : String
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

      def oneof_case_value_name(field_name : String) : String
        normalized = field_name
          .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
          .gsub(/[^A-Za-z\d]/, "_")
          .upcase
        normalized.empty? ? "FIELD" : normalized
      end

      def crystal_identifier(name : String) : String
        ident = name
        crystal_keyword?(ident) ? "#{ident}_" : ident
      end

      def crystal_keyword?(name : String) : Bool
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
