# Run: crystal build --release bench/merge.cr -o /tmp/proto-merge-bench
#      /tmp/proto-merge-bench
# The checked-in fixture must be regenerated after generator changes.
require "json"
require "../spec/fixtures/regressions.pb"

{500, 1_000, 2_000}.each do |count|
  wire = IO::Memory.new
  # Wrapper.nested occurs repeatedly; each occurrence appends one value.
  count.times { wire.write(Bytes[18, 2, 24, 1]) }
  input = wire.to_slice
  2.times { Regressions::Wrapper.decode(input) }
  iterations = 10
  GC.collect
  before = GC.stats.total_bytes
  started = Time.instant
  iterations.times do
    result = Regressions::Wrapper.decode(input)
    raise "incorrect merge" unless result.nested.not_nil!.values.size == count
  end
  elapsed_ns = (Time.instant - started).total_nanoseconds
  allocated = GC.stats.total_bytes - before
  puts({bench: "repeated_embedded_merge", occurrences: count,
        ns_per_decode: elapsed_ns / iterations,
        bytes_allocated_per_decode: allocated / iterations}.to_json)
end
