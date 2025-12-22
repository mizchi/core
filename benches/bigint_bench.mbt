// Benchmark for BigInt operations

///|
/// Benchmark BigInt creation from string
test "bench_bigint_from_string" (b : @bench.T) {
  let small = "12345"
  let medium = "123456789012345678901234567890"
  let large = "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"
  b.bench(
    name="bigint_from_string_small",
    fn() {
      b.keep(@bigint.BigInt::from_string(small))
    },
  )
  b.bench(
    name="bigint_from_string_medium",
    fn() {
      b.keep(@bigint.BigInt::from_string(medium))
    },
  )
  b.bench(
    name="bigint_from_string_large",
    fn() {
      b.keep(@bigint.BigInt::from_string(large))
    },
  )
}

///|
/// Benchmark BigInt from Int64
test "bench_bigint_from_int64" (b : @bench.T) {
  b.bench(
    name="bigint_from_int64",
    fn() {
      b.keep(@bigint.BigInt::from_int64(9223372036854775807L))
    },
  )
}

///|
/// Benchmark BigInt addition
test "bench_bigint_add" (b : @bench.T) {
  let a = @bigint.BigInt::from_string("123456789012345678901234567890")
  let c = @bigint.BigInt::from_string("987654321098765432109876543210")
  b.bench(
    name="bigint_add",
    fn() {
      b.keep(a + c)
    },
  )
}

///|
/// Benchmark BigInt multiplication
test "bench_bigint_mul" (b : @bench.T) {
  let a = @bigint.BigInt::from_string("123456789012345678901234567890")
  let c = @bigint.BigInt::from_string("987654321")
  b.bench(
    name="bigint_mul_large_small",
    fn() {
      b.keep(a * c)
    },
  )
  let d = @bigint.BigInt::from_string("12345678901234567890")
  let e = @bigint.BigInt::from_string("98765432109876543210")
  b.bench(
    name="bigint_mul_medium_medium",
    fn() {
      b.keep(d * e)
    },
  )
}

///|
/// Benchmark BigInt to_string
test "bench_bigint_to_string" (b : @bench.T) {
  let small = @bigint.BigInt::from_int64(12345L)
  let large = @bigint.BigInt::from_string("123456789012345678901234567890123456789012345678901234567890")
  b.bench(
    name="bigint_to_string_small",
    fn() {
      b.keep(small.to_string())
    },
  )
  b.bench(
    name="bigint_to_string_large",
    fn() {
      b.keep(large.to_string())
    },
  )
}

///|
/// Benchmark BigInt comparison
test "bench_bigint_compare" (b : @bench.T) {
  let a = @bigint.BigInt::from_string("123456789012345678901234567890")
  let c = @bigint.BigInt::from_string("123456789012345678901234567891")
  b.bench(
    name="bigint_compare",
    fn() {
      b.keep(a < c)
    },
  )
  b.bench(
    name="bigint_equal",
    fn() {
      b.keep(a == a)
    },
  )
}
