require "../bootstrap/descriptor"

module Proto
  module Generator
    # NamingPolicy converts proto identifiers to Crystal identifiers.
    #
    # Rules (matching protoc-gen-go / protoc-gen-python conventions adapted for Crystal):
    #   - package "foo.bar_baz" → module Foo::BarBaz
    #   - message "HelloRequest" → class HelloRequest  (already CamelCase)
    #   - enum "Status" → enum Status
    #   - enum value "STATUS_OK" → STATUS_OK  (kept as-is, Crystal enums use SCREAMING_SNAKE)
    #   - field "my_field" → property my_field  (snake_case, kept)
    module NamingPolicy
      # Convert a proto package string to a Crystal module path.
      # "foo.bar_baz" → "Foo::BarBaz"
      # "" → nil
      def self.package_to_module(package : String) : String?
        return if package.empty?
        package.split('.').map { |part| camelize(part) }.join("::")
      end

      # Convert a proto message/enum name (already CamelCase) to a Crystal class/enum name.
      # Nested names are NOT joined here — the caller passes the leaf name.
      def self.message_name(name : String) : String
        name
      end

      # proto fully-qualified type ".foo.bar.Baz.Inner" → "Foo::Bar::Baz::Inner"
      def self.fq_type_to_crystal(fq : String) : String
        # Strip leading dot
        s = fq.lstrip('.')
        parts = s.split('.')
        # Last N parts that start with uppercase are type names; preceding parts are the package.
        # Strategy: scan right-to-left for the package boundary.
        # Simple heuristic: if a part starts with uppercase it's a type name,
        # otherwise it's a package component.
        pkg_parts = [] of String
        type_parts = [] of String
        parts.each do |part_name|
          if type_parts.empty? && part_name[0]?.try &.lowercase?
            pkg_parts << camelize(part_name)
          else
            type_parts << part_name
          end
        end
        (pkg_parts + type_parts).join("::")
      end

      # snake_case → CamelCase
      def self.camelize(s : String) : String
        s.split('_').map(&.capitalize).join
      end
    end

    # TypeIndex builds a flat index of all types defined in the proto files
    # being compiled, keyed by fully-qualified proto name (e.g. ".foo.bar.HelloRequest").
    # Used by the code generator to resolve field type_names.
    class TypeIndex
      enum Kind
        Message
        Enum
      end

      record Entry,
        fq_name : String,      # ".foo.bar.HelloRequest"
        crystal_name : String, # "Foo::Bar::HelloRequest"
        kind : Kind,
        file : Bootstrap::FileDescriptorProto

      getter entries : Hash(String, Entry) = {} of String => Entry

      def initialize(files : Array(Bootstrap::FileDescriptorProto))
        files.each { |file_desc| index_file(file_desc) }
      end

      def resolve(fq_name : String) : Entry?
        @entries[fq_name]?
      end

      private def index_file(file : Bootstrap::FileDescriptorProto) : Nil
        pkg = file.package
        module_prefix = NamingPolicy.package_to_module(pkg)

        file.message_type.each { |message_desc| index_message(message_desc, pkg, module_prefix, file) }
        file.enum_type.each { |enum_desc| index_enum(enum_desc, pkg, module_prefix, file) }
      end

      private def index_message(
        msg : Bootstrap::DescriptorProto,
        pkg : String,
        crystal_prefix : String?,
        file : Bootstrap::FileDescriptorProto,
      ) : Nil
        fq = ".#{pkg.empty? ? "" : pkg + "."}#{msg.name}"
        fq = fq.lstrip('.')
        fq = ".#{fq}"

        crystal = crystal_prefix ? "#{crystal_prefix}::#{msg.name}" : msg.name

        @entries[fq] = Entry.new(fq, crystal, Kind::Message, file)

        # Nested messages and enums
        msg.nested_type.each { |nested_msg| index_nested_message(nested_msg, fq, crystal, file) }
        msg.enum_type.each { |enum_desc| index_nested_enum(enum_desc, fq, crystal, file) }
      end

      private def index_enum(
        en : Bootstrap::EnumDescriptorProto,
        pkg : String,
        crystal_prefix : String?,
        file : Bootstrap::FileDescriptorProto,
      ) : Nil
        fq = ".#{pkg.empty? ? "" : pkg + "."}#{en.name}"
        fq = fq.lstrip('.')
        fq = ".#{fq}"
        crystal = crystal_prefix ? "#{crystal_prefix}::#{en.name}" : en.name
        @entries[fq] = Entry.new(fq, crystal, Kind::Enum, file)
      end

      private def index_nested_message(
        msg : Bootstrap::DescriptorProto,
        parent_fq : String,
        parent_crystal : String,
        file : Bootstrap::FileDescriptorProto,
      ) : Nil
        fq = "#{parent_fq}.#{msg.name}"
        crystal = "#{parent_crystal}::#{msg.name}"
        @entries[fq] = Entry.new(fq, crystal, Kind::Message, file)
        msg.nested_type.each { |nested_msg| index_nested_message(nested_msg, fq, crystal, file) }
        msg.enum_type.each { |enum_desc| index_nested_enum(enum_desc, fq, crystal, file) }
      end

      private def index_nested_enum(
        en : Bootstrap::EnumDescriptorProto,
        parent_fq : String,
        parent_crystal : String,
        file : Bootstrap::FileDescriptorProto,
      ) : Nil
        fq = "#{parent_fq}.#{en.name}"
        crystal = "#{parent_crystal}::#{en.name}"
        @entries[fq] = Entry.new(fq, crystal, Kind::Enum, file)
      end
    end
  end
end
