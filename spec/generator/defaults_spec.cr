require "../spec_helper"

describe Proto::Generator::FileGenerator do
  describe "defaults" do
    it "uses explicit field default_value when provided" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "defaults.proto"
      file.package = "defaults"
      file.syntax = "proto2"

      en = Proto::Bootstrap::EnumDescriptorProto.new
      en.name = "State"
      unknown = Proto::Bootstrap::EnumValueDescriptorProto.new
      unknown.name = "UNKNOWN"
      unknown.number = 0
      ready = Proto::Bootstrap::EnumValueDescriptorProto.new
      ready.name = "READY"
      ready.number = 1
      en.value << unknown << ready
      file.enum_type << en

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Config"

      enabled = Proto::Bootstrap::FieldDescriptorProto.new
      enabled.name = "enabled"
      enabled.number = 1
      enabled.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      enabled.type = Proto::Bootstrap::FieldType::TYPE_BOOL
      enabled.default_value = "true"

      retries = Proto::Bootstrap::FieldDescriptorProto.new
      retries.name = "retries"
      retries.number = 2
      retries.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      retries.type = Proto::Bootstrap::FieldType::TYPE_INT32
      retries.default_value = "7"

      note = Proto::Bootstrap::FieldDescriptorProto.new
      note.name = "note"
      note.number = 3
      note.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      note.type = Proto::Bootstrap::FieldType::TYPE_STRING
      note.default_value = "hello"

      state = Proto::Bootstrap::FieldDescriptorProto.new
      state.name = "state"
      state.number = 4
      state.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      state.type = Proto::Bootstrap::FieldType::TYPE_ENUM
      state.type_name = ".defaults.State"
      state.default_value = "READY"

      msg.field << enabled << retries << note << state
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("getter? has_enabled : Bool = false")
      code.should contain("getter? has_retries : Bool = false")
      code.should contain("getter? has_note : Bool = false")
      code.should contain("getter? has_state : Bool = false")
      code.should contain("getter enabled : Bool = true")
      code.should contain("getter retries : Int32 = 7")
      code.should contain("getter note : String = \"hello\"")
      code.should contain("getter state : Defaults::State = Defaults::State::READY")
      code.should contain("def enabled=(value : Bool) : Bool")
      code.should contain("def clear_enabled : Nil")
      code.should contain("if has_enabled?")
      code.should contain("if has_retries?")
      code.should contain("if has_note?")
      code.should contain("if has_state?")
      code.should contain("return false unless has_enabled? == other.has_enabled?")
    end

    it "maps proto2 float explicit defaults including inf/-inf/nan" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "float_defaults.proto"
      file.package = "flt"
      file.syntax = "proto2"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Floats"

      pos_inf = Proto::Bootstrap::FieldDescriptorProto.new
      pos_inf.name = "pos_inf"
      pos_inf.number = 1
      pos_inf.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      pos_inf.type = Proto::Bootstrap::FieldType::TYPE_FLOAT
      pos_inf.default_value = "inf"

      neg_inf = Proto::Bootstrap::FieldDescriptorProto.new
      neg_inf.name = "neg_inf"
      neg_inf.number = 2
      neg_inf.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      neg_inf.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE
      neg_inf.default_value = "-inf"

      nan_v = Proto::Bootstrap::FieldDescriptorProto.new
      nan_v.name = "nan_v"
      nan_v.number = 3
      nan_v.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      nan_v.type = Proto::Bootstrap::FieldType::TYPE_FLOAT
      nan_v.default_value = "nan"

      regular = Proto::Bootstrap::FieldDescriptorProto.new
      regular.name = "regular"
      regular.number = 4
      regular.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      regular.type = Proto::Bootstrap::FieldType::TYPE_DOUBLE
      regular.default_value = "3.25"

      msg.field << pos_inf << neg_inf << nan_v << regular
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)
      code = gen.generate

      code.should contain("getter? has_pos_inf : Bool = false")
      code.should contain("getter? has_neg_inf : Bool = false")
      code.should contain("getter? has_nan_v : Bool = false")
      code.should contain("getter? has_regular : Bool = false")
      code.should contain("getter pos_inf : Float32 = Float32::INFINITY")
      code.should contain("getter neg_inf : Float64 = -Float64::INFINITY")
      code.should contain("getter nan_v : Float32 = Float32::NAN")
      code.should contain("getter regular : Float64 = 3.25_f64")
      code.should contain("def clear_pos_inf : Nil")
      code.should contain("def pos_inf=(value : Float32) : Float32")
      code.should contain("if has_pos_inf?")
    end

    it "fails fast when explicit integer defaults are out of range" do
      file = Proto::Bootstrap::FileDescriptorProto.new
      file.name = "bad_defaults.proto"
      file.package = "defaults"
      file.syntax = "proto2"

      msg = Proto::Bootstrap::DescriptorProto.new
      msg.name = "Config"

      bad = Proto::Bootstrap::FieldDescriptorProto.new
      bad.name = "u32"
      bad.number = 1
      bad.label = Proto::Bootstrap::FieldLabel::LABEL_OPTIONAL
      bad.type = Proto::Bootstrap::FieldType::TYPE_UINT32
      bad.default_value = "4294967296"
      msg.field << bad
      file.message_type << msg

      index = Proto::Generator::TypeIndex.new([file])
      gen = Proto::Generator::FileGenerator.new(file, index)

      expect_raises(Exception, /out of range/) do
        gen.generate
      end
    end
  end
end
