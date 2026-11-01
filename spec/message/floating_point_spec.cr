require "../spec_helper"
require "../fixtures/floats.pb"

describe "generated messages" do
  describe "floating-point fields" do
    it "omits positive floating-point zero values" do
      Regressions::Floats.new.encode.should be_empty
    end

    it "preserves negative floating-point zero without compatibility extensions" do
      message = Regressions::Floats.new
      message.ratio = -0.0_f32
      message.gain = -0.0_f64
      encoded = message.encode
      encoded.should eq(Bytes[0x0d, 0, 0, 0, 0x80, 0x11, 0, 0, 0, 0, 0, 0, 0, 0x80])

      decoded = Regressions::Floats.decode(encoded)
      decoded.ratio.zero?.should be_true
      decoded.ratio.sign_bit.should eq(-1)
      decoded.gain.zero?.should be_true
      decoded.gain.sign_bit.should eq(-1)
      decoded.encode.should eq(encoded)
    end

    [1.25_f32, -2.5_f32, Float32::INFINITY, -Float32::INFINITY, Float32::NAN].each do |value|
      it "round-trips floating-point value #{value}" do
        message = Regressions::Floats.new
        message.ratio = value
        message.gain = value.to_f64
        decoded = Regressions::Floats.decode(message.encode)
        if value.nan?
          decoded.ratio.nan?.should be_true
          decoded.gain.nan?.should be_true
        else
          decoded.ratio.should eq(value)
          decoded.gain.should eq(value.to_f64)
        end
      end
    end
  end
end
