// Benchmark for Double operations

///|
/// Benchmark Double::to_string with various values
test "bench_double_to_string" (b : @bench.T) {
  b.bench(
    name="double_to_string_simple",
    fn() {
      b.keep(42.0.to_string())
    },
  )
  b.bench(
    name="double_to_string_decimal",
    fn() {
      b.keep(3.14159265358979.to_string())
    },
  )
  b.bench(
    name="double_to_string_scientific",
    fn() {
      b.keep(1.23e-100.to_string())
    },
  )
  b.bench(
    name="double_to_string_large",
    fn() {
      b.keep(1234567890123456.0.to_string())
    },
  )
}

///|
/// Benchmark Double::to_string batch
test "bench_double_to_string_batch" (b : @bench.T) {
  let values = [
    0.0, 1.0, -1.0, 3.14159, 2.71828, 1.0e10, 1.0e-10, 123.456789,
  ]
  b.bench(
    name="double_to_string_batch_8",
    fn() {
      for v in values {
        b.keep(v.to_string())
      }
    },
  )
}

///|
/// Benchmark Double arithmetic operations
test "bench_double_arithmetic" (b : @bench.T) {
  let a = 123.456
  let c = 789.012
  b.bench(
    name="double_add_1000",
    fn() {
      let mut result = 0.0
      for _ in 0..<1000 {
        result = result + a + c
      }
      b.keep(result)
    },
  )
  b.bench(
    name="double_mul_1000",
    fn() {
      let mut result = 1.0
      for _ in 0..<1000 {
        result = result * 1.001
      }
      b.keep(result)
    },
  )
}

///|
/// Benchmark Double comparison
test "bench_double_compare" (b : @bench.T) {
  let values = Array::makei(1000, fn(i) { i.to_double() })
  b.bench(
    name="double_compare_1000",
    fn() {
      let mut count = 0
      for i in 0..<999 {
        if values[i] < values[i + 1] {
          count += 1
        }
      }
      b.keep(count)
    },
  )
}
