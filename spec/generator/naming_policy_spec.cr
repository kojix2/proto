require "../spec_helper"

describe Proto::Generator::NamingPolicy do
  describe ".package_to_module" do
    it "converts dot-separated package to Crystal module path" do
      Proto::Generator::NamingPolicy.package_to_module("foo.bar_baz").should eq("Foo::BarBaz")
    end

    it "returns nil for empty package" do
      Proto::Generator::NamingPolicy.package_to_module("").should be_nil
    end

    it "handles single-component package" do
      Proto::Generator::NamingPolicy.package_to_module("simple").should eq("Simple")
    end
  end

  describe ".fq_type_to_crystal" do
    it "converts fully-qualified type name to Crystal name" do
      Proto::Generator::NamingPolicy.fq_type_to_crystal(".simple.Person").should eq("Simple::Person")
    end

    it "handles nested type names" do
      Proto::Generator::NamingPolicy.fq_type_to_crystal(".foo.bar.Outer.Inner").should eq("Foo::Bar::Outer::Inner")
    end
  end

  describe ".camelize" do
    it "converts snake_case to CamelCase" do
      Proto::Generator::NamingPolicy.camelize("hello_world").should eq("HelloWorld")
    end

    it "leaves already CamelCase strings alone" do
      Proto::Generator::NamingPolicy.camelize("Hello").should eq("Hello")
    end
  end
end
