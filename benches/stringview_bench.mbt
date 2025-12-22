// Benchmark for StringView operations

///|
/// Benchmark StringView creation
test "bench_stringview_create" (b : @bench.T) {
  let s = "The quick brown fox jumps over the lazy dog"
  b.bench(
    name="stringview_full",
    fn() {
      b.keep(s[:])
    },
  )
  b.bench(
    name="stringview_slice",
    fn() {
      try {
        b.keep(s[10:20])
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark StringView iteration
test "bench_stringview_iter" (b : @bench.T) {
  let s = "Hello, World! This is a test string for benchmarking."
  let view = s[:]
  b.bench(
    name="stringview_iter",
    fn() {
      let mut count = 0
      for _ in view {
        count += 1
      }
      b.keep(count)
    },
  )
}

///|
/// Benchmark StringView length
test "bench_stringview_length" (b : @bench.T) {
  let s = "Hello, World! This is a test string for benchmarking."
  let view = s[:]
  b.bench(
    name="stringview_length",
    fn() {
      b.keep(view.length())
    },
  )
}

///|
/// Benchmark StringView to_string
test "bench_stringview_to_string" (b : @bench.T) {
  let s = "The quick brown fox jumps over the lazy dog"
  let view = try { s[10:30] } catch { _ => s[:] }
  b.bench(
    name="stringview_to_string",
    fn() {
      b.keep(view.to_string())
    },
  )
}

///|
/// Benchmark StringView comparison
test "bench_stringview_compare" (b : @bench.T) {
  let s1 = "Hello, World!"
  let s2 = "Hello, World!"
  let v1 = s1[:]
  let v2 = s2[:]
  b.bench(
    name="stringview_equal",
    fn() {
      b.keep(v1 == v2)
    },
  )
}

///|
/// Benchmark substring operations with StringView vs String
test "bench_stringview_vs_string_substring" (b : @bench.T) {
  let s = "The quick brown fox jumps over the lazy dog. This is additional text for testing."
  // Using StringView slice
  b.bench(
    name="stringview_slice_chain",
    fn() {
      try {
        let v1 = s[10:50]
        let v2 = v1[5:20]
        b.keep(v2.length())
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark StringView hash
test "bench_stringview_hash" (b : @bench.T) {
  let s = "Hello, World!"
  let view = s[:]
  b.bench(
    name="stringview_hash",
    fn() {
      b.keep(Hash::hash(view))
    },
  )
  b.bench(
    name="string_hash_compare",
    fn() {
      b.keep(Hash::hash(s))
    },
  )
}
