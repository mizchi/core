// JS Benchmark for Double::to_string
// This file is used to measure bundle size and JS FFI performance

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
fn bench(name : String, iterations : Int, f : () -> Unit) -> Unit {
  let start = performance_now()
  for _ in 0..<iterations {
    f()
  }
  let end = performance_now()
  let total_ms = end - start
  let per_op_us = total_ms * 1000.0 / iterations.to_double()
  console_log("\{name}: \{per_op_us.to_string()} us/op (total: \{total_ms.to_string()} ms)")
}

///|
fn main {
  console_log("=== Double::to_string JS Benchmark ===")

  // Benchmark: simple number
  bench("double_to_string_simple", 10000, fn() {
    ignore(42.0.to_string())
  })

  // Benchmark: decimal number
  bench("double_to_string_decimal", 10000, fn() {
    ignore(3.14159265358979.to_string())
  })

  // Benchmark: scientific notation
  bench("double_to_string_scientific", 10000, fn() {
    ignore(1.23e-100.to_string())
  })

  // Benchmark: large number
  bench("double_to_string_large", 10000, fn() {
    ignore(1234567890123456.0.to_string())
  })

  // Benchmark: batch conversion
  let values = [0.0, 1.0, -1.0, 3.14159, 2.71828, 1.0e10, 1.0e-10, 123.456789]
  bench("double_to_string_batch_8", 1000, fn() {
    for v in values {
      ignore(v.to_string())
    }
  })

  console_log("=== Done ===")
}
