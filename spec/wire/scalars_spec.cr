require "../spec_helper"
require "../support/wire_helpers"

describe "Proto wire format" do
  describe "bool" do
    it "encodes true as 1" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(true)
      io.to_slice.should eq Bytes[1]
    end

    it "encodes false as 0" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(false)
      io.to_slice.should eq Bytes[0]
    end

    it "round-trips true" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(true)
      io.rewind
      Proto::Wire::Reader.new(io).read_bool.should be_true
    end

    it "round-trips false" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bool(false)
      io.rewind
      Proto::Wire::Reader.new(io).read_bool.should be_false
    end
  end

  describe "fixed32 / sfixed32" do
    it "round-trips fixed32 0" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed32(0_u32)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed32.should eq 0_u32
    end

    it "round-trips fixed32 UInt32::MAX" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed32(UInt32::MAX)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed32.should eq UInt32::MAX
    end

    it "round-trips sfixed32 -1" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed32(-1_i32)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed32.should eq -1_i32
    end

    it "round-trips sfixed32 Int32::MIN" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed32(Int32::MIN)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed32.should eq Int32::MIN
    end

    it "raises on truncated fixed32" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0xAA, 0xBB, 0xCC]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_fixed32
      end
    end
  end

  describe "fixed64 / sfixed64" do
    it "round-trips fixed64 UInt64::MAX" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_fixed64(UInt64::MAX)
      io.rewind
      Proto::Wire::Reader.new(io).read_fixed64.should eq UInt64::MAX
    end

    it "round-trips sfixed64 Int64::MIN" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_sfixed64(Int64::MIN)
      io.rewind
      Proto::Wire::Reader.new(io).read_sfixed64.should eq Int64::MIN
    end

    it "raises on truncated fixed64" do
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x01, 0x02, 0x03, 0x04, 0x05]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_fixed64
      end
    end
  end

  describe "float / double" do
    it "round-trips float 3.14" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_float(3.14_f32)
      io.rewind
      Proto::Wire::Reader.new(io).read_float.should be_close(3.14_f32, 1e-6_f32)
    end

    it "round-trips double 3.141592653589793" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_double(3.141592653589793_f64)
      io.rewind
      Proto::Wire::Reader.new(io).read_double.should be_close(3.141592653589793_f64, 1e-15_f64)
    end
  end

  describe "bytes / string" do
    it "round-trips empty bytes" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bytes(Bytes.empty)
      io.rewind
      Proto::Wire::Reader.new(io).read_bytes.should eq Bytes.empty
    end

    it "round-trips bytes" do
      data = Bytes[0x00, 0xFF, 0x42, 0x7F]
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_bytes(data)
      io.rewind
      Proto::Wire::Reader.new(io).read_bytes.should eq data
    end

    it "round-trips empty string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq ""
    end

    it "round-trips ASCII string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("hello world")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq "hello world"
    end

    it "round-trips UTF-8 string" do
      io = IO::Memory.new
      Proto::Wire::Writer.new(io).write_string("こんにちは")
      io.rewind
      Proto::Wire::Reader.new(io).read_string.should eq "こんにちは"
    end

    it "raises on truncated length-delimited payload" do
      # length prefix says 5 bytes, but only 2 bytes follow.
      reader = Proto::Wire::Reader.new(IO::Memory.new(Bytes[0x05, 0x41, 0x42]))
      expect_raises(Proto::DecodeError, /unexpected EOF/) do
        reader.read_string
      end
    end
  end
end
