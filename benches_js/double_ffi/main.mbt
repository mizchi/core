// JS Benchmark for Double::to_string using JS FFI
// This tests the bundle size reduction when using native JS toString

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

// JS FFI implementation of Double::to_string
// This replaces the Ryu algorithm with native JavaScript
///|
extern "js" fn double_to_string_js(d : Double) -> String =
  #| (x) => {
  #|   if (Object.is(x, -0)) return "-0";
  #|   return String(x);
  #| }

///|
fn bench(name : String, iterations : Int, f : () -> Unit) -> Unit {
  let start = performance_now()
  for _ in 0..<iterations {
    f()
  }
  let end = performance_now()
  let total_ms = end - start
  let per_op_us = total_ms * 1000.0 / iterations.to_double()
  console_log("\{name}: \{double_to_string_js(per_op_us)} us/op (total: \{double_to_string_js(total_ms)} ms)")
}

///|
fn main {
  console_log("=== Double::to_string JS FFI Benchmark ===")

  // Benchmark: simple number
  bench("double_to_string_simple", 10000, fn() {
    ignore(double_to_string_js(42.0))
  })

  // Benchmark: decimal number
  bench("double_to_string_decimal", 10000, fn() {
    ignore(double_to_string_js(3.14159265358979))
  })

  // Benchmark: scientific notation
  bench("double_to_string_scientific", 10000, fn() {
    ignore(double_to_string_js(1.23e-100))
  })

  // Benchmark: large number
  bench("double_to_string_large", 10000, fn() {
    ignore(double_to_string_js(1234567890123456.0))
  })

  // Benchmark: special values
  bench("double_to_string_special", 10000, fn() {
    ignore(double_to_string_js(0.0 / 0.0)) // NaN
    ignore(double_to_string_js(1.0 / 0.0)) // Infinity
    ignore(double_to_string_js(-1.0 / 0.0)) // -Infinity
    ignore(double_to_string_js(-0.0)) // -0
  })

  // Test output correctness
  console_log("")
  console_log("=== Correctness Tests ===")
  console_log("42.0 => " + double_to_string_js(42.0))
  console_log("3.14159 => " + double_to_string_js(3.14159))
  console_log("1.23e-100 => " + double_to_string_js(1.23e-100))
  console_log("-0.0 => " + double_to_string_js(-0.0))
  console_log("NaN => " + double_to_string_js(0.0 / 0.0))
  console_log("Infinity => " + double_to_string_js(1.0 / 0.0))
  console_log("-Infinity => " + double_to_string_js(-1.0 / 0.0))

  console_log("")
  console_log("=== Done ===")
}
