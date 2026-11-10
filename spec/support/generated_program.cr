require "../spec_helper"
require "file_utils"

module ProtoCompilationSpec
  # Compile freshly generated files against this checkout, not an installed or
  # committed fixture. Each example owns its temporary source and executable.
  def self.run(files : Array(Proto::Bootstrap::FileDescriptorProto), program : String,
               *, overrides : Hash(String, String) = {} of String => String) : String
    directory = File.tempname("proto-generated-program-")
    Dir.mkdir(directory)
    index = Proto::Generator::TypeIndex.new(files)
    files.each do |file|
      generator = Proto::Generator::FileGenerator.new(file, index)
      output = File.join(directory, generator.output_name)
      FileUtils.mkdir_p(File.dirname(output))
      File.write(output, overrides[generator.output_name]? || generator.generate)
    end
    source = File.join(directory, "main.cr")
    binary = File.join(directory, "generated-program")
    File.write(source, program)
    load_path = IO::Memory.new
    Process.run("crystal", ["env", "CRYSTAL_PATH"], output: load_path).success?.should be_true
    env = {"CRYSTAL_PATH" => "#{File.expand_path("../../src", __DIR__)}:#{load_path.to_s.strip}"}
    output = IO::Memory.new
    errors = IO::Memory.new
    built = Process.run("crystal", ["build", source, "-o", binary], env: env, output: output, error: errors)
    built.success?.should be_true, "generated program did not compile:\n#{errors}"
    result = IO::Memory.new
    executed = Process.run(binary, output: result, error: errors)
    executed.success?.should be_true, "generated program failed:\n#{errors}"
    result.to_s
  ensure
    FileUtils.rm_rf(directory) if directory
  end
end
