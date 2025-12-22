// Benchmark for Hasher operations

///|
/// Benchmark Hasher with integers
test "bench_hasher_int" (b : @bench.T) {
  b.bench(
    name="hasher_int_single",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_int(42)
      b.keep(hasher.finalize())
    },
  )
  b.bench(
    name="hasher_int_100",
    fn() {
      let hasher = Hasher::new(seed=0)
      for i in 0..<100 {
        hasher.combine_int(i)
      }
      b.keep(hasher.finalize())
    },
  )
}

///|
/// Benchmark Hasher with strings
test "bench_hasher_string" (b : @bench.T) {
  let short_str = "hello"
  let long_str = "The quick brown fox jumps over the lazy dog"
  b.bench(
    name="hasher_string_short",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_string(short_str)
      b.keep(hasher.finalize())
    },
  )
  b.bench(
    name="hasher_string_long",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_string(long_str)
      b.keep(hasher.finalize())
    },
  )
}

///|
/// Benchmark Hash trait
test "bench_hash_trait" (b : @bench.T) {
  b.bench(
    name="hash_trait_int",
    fn() {
      b.keep(Hash::hash(42))
    },
  )
  b.bench(
    name="hash_trait_string",
    fn() {
      b.keep(Hash::hash("hello world"))
    },
  )
}

///|
/// Benchmark Hasher with bytes
test "bench_hasher_bytes" (b : @bench.T) {
  let small_bytes = b"\x01\x02\x03\x04"
  let large_bytes = Bytes::make(256, b'\xFF')
  b.bench(
    name="hasher_bytes_4",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_bytes(small_bytes)
      b.keep(hasher.finalize())
    },
  )
  b.bench(
    name="hasher_bytes_256",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_bytes(large_bytes)
      b.keep(hasher.finalize())
    },
  )
}

///|
/// Benchmark composite hashing (like tuple)
test "bench_hasher_composite" (b : @bench.T) {
  b.bench(
    name="hasher_composite",
    fn() {
      let hasher = Hasher::new(seed=0)
      hasher.combine_int(1)
      hasher.combine_string("key")
      hasher.combine_double(3.14)
      hasher.combine_bool(true)
      b.keep(hasher.finalize())
    },
  )
}

///|
/// Compare seeded vs default hasher (JS randomness impact)
test "bench_hasher_seeded_vs_default" (b : @bench.T) {
  b.bench(
    name="hasher_fixed_seed",
    fn() {
      let hasher = Hasher::new(seed=42)
      hasher.combine_int(100)
      b.keep(hasher.finalize())
    },
  )
  b.bench(
    name="hasher_default_seed",
    fn() {
      let hasher = Hasher::new()
      hasher.combine_int(100)
      b.keep(hasher.finalize())
    },
  )
}
