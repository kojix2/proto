require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "map fields" do
    it "generates map fields as Hash with map-entry encode/decode" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "map.proto"
      file.package = "maptest"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Scores"

      entry = Proto::Bootstrap::DescriptorProto.new
      entry.name = "RatingsEntry"
      entry_options = Proto::Bootstrap::MessageOptions.new
      entry_options.map_entry = true
      entry.options = entry_options

      key = Proto::Bootstrap::FieldDescriptorProto.new
      key.name = "key"
      key.number = 1
      key.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      key.type = Proto::Bootstrap::FieldType::TYPE_STRING

      value = Proto::Bootstrap::FieldDescriptorProto.new
      value.name = "value"
      value.number = 2
      value.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      value.type = Proto::Bootstrap::FieldType::TYPE_INT32

      entry.field << key << value
      msg.nested_type << entry

      map_field = Proto::Bootstrap::FieldDescriptorProto.new
      map_field.name = "ratings"
      map_field.number = 1
      map_field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      map_field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      map_field.type_name = ".maptest.Scores.RatingsEntry"
      msg.field << map_field

      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property ratings : Hash(String, Int32) = {} of String => Int32")
      code.should contain("entry = reader.read_embedded(1, wt) { |sub| Maptest::Scores::RatingsEntry.decode_partial(sub) }")
      code.should contain("msg.ratings[entry.key] = entry.value")
      code.should contain("ratings.each do |k, v|")
      code.should contain("entry.key = k")
      code.should contain("entry.value = v")
      # map field encode does not use nil guard
      code.should_not contain("if (_v = ratings)")
    end

    it "guards nil decode for message-valued map entries" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "message_map.proto"
      file.package = "maptest"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Settings"

      value_message = Proto::Bootstrap::DescriptorProto.new
      value_message.name = "FlagValue"

      enabled = Proto::Bootstrap::FieldDescriptorProto.new
      enabled.name = "enabled"
      enabled.number = 1
      enabled.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      enabled.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      value_message.field << enabled

      entry = Proto::Bootstrap::DescriptorProto.new
      entry.name = "FlagsEntry"
      entry_options = Proto::Bootstrap::MessageOptions.new
      entry_options.map_entry = true
      entry.options = entry_options

      key = Proto::Bootstrap::FieldDescriptorProto.new
      key.name = "key"
      key.number = 1
      key.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      key.type = Proto::Bootstrap::FieldType::TYPE_STRING

      value = Proto::Bootstrap::FieldDescriptorProto.new
      value.name = "value"
      value.number = 2
      value.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      value.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      value.type_name = ".maptest.Settings.FlagValue"

      entry.field << key << value
      msg.nested_type << value_message
      msg.nested_type << entry

      map_field = Proto::Bootstrap::FieldDescriptorProto.new
      map_field.name = "flags"
      map_field.number = 1
      map_field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      map_field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      map_field.type_name = ".maptest.Settings.FlagsEntry"
      msg.field << map_field

      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property flags : Hash(String, Maptest::Settings::FlagValue) = {} of String => Maptest::Settings::FlagValue")
      code.should contain("entry = reader.read_embedded(1, wt) { |sub| Maptest::Settings::FlagsEntry.decode_partial(sub) }")
      code.should contain("msg.flags[entry.key] = entry.value || Maptest::Settings::FlagValue.new")
    end

    it "does not treat repeated message as map unless map_entry option is true" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "not_map.proto"
      file.package = "maptest"
      file.syntax = "proto3"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Container"

      entry = Proto::Bootstrap::DescriptorProto.new
      entry.name = "PairLike"

      key = Proto::Bootstrap::FieldDescriptorProto.new
      key.name = "key"
      key.number = 1
      key.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      key.type = Proto::Bootstrap::FieldType::TYPE_STRING

      value = Proto::Bootstrap::FieldDescriptorProto.new
      value.name = "value"
      value.number = 2
      value.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      value.type = Proto::Bootstrap::FieldType::TYPE_INT32

      entry.field << key << value
      msg.nested_type << entry

      field = Proto::Bootstrap::FieldDescriptorProto.new
      field.name = "pairs"
      field.number = 1
      field.label = Proto::Bootstrap::FieldLabel::LABEL_REPEATED
      field.type = Proto::Bootstrap::FieldType::TYPE_MESSAGE
      field.type_name = ".maptest.Container.PairLike"
      msg.field << field

      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("property pairs : Array(Maptest::Container::PairLike) = [] of Maptest::Container::PairLike")
      code.should contain("msg.pairs << reader.read_embedded(1, wt) { |sub| Maptest::Container::PairLike.decode_partial(sub) }")
      code.should contain("pairs.each do |item|")
      code.should_not contain("property pairs : Hash(")
    end
  end
end
