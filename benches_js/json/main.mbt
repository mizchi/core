// JS Benchmark for JSON
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
  console_log("=== JSON JS Benchmark ===")

  // Benchmark: JSON parse simple
  let simple_json = "{\"name\": \"test\", \"value\": 42}"
  bench("json_parse_simple", 1000, fn() {
    try {
      ignore(@js.parse(simple_json))
    } catch {
      _ => ()
    }
  })

  // Benchmark: JSON parse array
  let array_json = "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  bench("json_parse_array", 1000, fn() {
    try {
      ignore(@js.parse(array_json))
    } catch {
      _ => ()
    }
  })

  // Benchmark: JSON stringify
  let obj : Json = Json::object(
    Map::of([
      ("name", Json::string("test")),
      ("value", Json::number(42.0)),
      ("active", Json::boolean(true)),
    ])
  )
  bench("json_stringify_object", 1000, fn() {
    ignore(obj.stringify())
  })

  // Benchmark: JSON parse large array
  let mut large_json = "["
  for i in 0..<100 {
    if i > 0 {
      large_json = large_json + ", "
    }
    large_json = large_json + i.to_string()
  }
  large_json = large_json + "]"
  bench("json_parse_100_numbers", 100, fn() {
    try {
      ignore(@js.parse(large_json))
    } catch {
      _ => ()
    }
  })

  console_log("=== Done ===")
}
