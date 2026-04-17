module Proto
  module Generator
    abstract class TypeNameResolver
      abstract def resolve(proto_type : String, current_package : String) : String

      def self.build(parameter : String,
                     files : Array(Bootstrap::FileDescriptorProto)) : TypeNameResolver
        index = TypeIndex.new(files)
        map = parse_type_map(parameter)
        return CanonicalTypeNameResolver.new(index) if map.empty?

        TypeMapNameResolver.new(map)
      end

      private def self.parse_type_map(parameter : String) : Hash(String, String)
        return {} of String => String if parameter.empty?

        map = {} of String => String

        parameter.split(',').each do |token|
          key, value = split_once(token, '=')
          key = key.strip
          value = value.strip
          next if key.empty? || key != "type_map" || value.empty?

          value.split(';').each do |entry|
            proto_name, crystal_name = split_once(entry, '=')
            proto_name = proto_name.strip
            crystal_name = crystal_name.strip
            next if proto_name.empty? || crystal_name.empty?

            normalized = proto_name.starts_with?('.') ? proto_name : ".#{proto_name}"
            map[normalized] = crystal_name
          end
        end

        map
      end

      private def self.split_once(text : String, delimiter : Char) : {String, String}
        idx = text.index(delimiter)
        return {text, ""} unless idx

        {text[0, idx], text[idx + 1, text.bytesize - idx - 1]}
      end
    end

    class CanonicalTypeNameResolver < TypeNameResolver
      def initialize(@index : TypeIndex? = nil)
      end

      def resolve(proto_type : String, current_package : String) : String
        resolved = if index = @index
                     if entry = index.resolve(proto_type)
                       entry.crystal_name
                     else
                       NamingPolicy.fq_type_to_crystal(proto_type)
                     end
                   else
                     NamingPolicy.fq_type_to_crystal(proto_type)
                   end
        return resolved if current_package.empty?

        package_module = NamingPolicy.package_to_module(current_package)
        return resolved unless package_module

        prefix = "#{package_module}::"
        return resolved unless resolved.starts_with?(prefix)

        resolved[prefix.size, resolved.bytesize - prefix.size]
      end
    end

    class TypeMapNameResolver < TypeNameResolver
      def initialize(@map : Hash(String, String))
      end

      def resolve(proto_type : String, current_package : String) : String
        if mapped = @map[proto_type]?
          return mapped
        end

        raise ArgumentError.new("Missing type_map entry for #{proto_type}")
      end
    end
  end
end
