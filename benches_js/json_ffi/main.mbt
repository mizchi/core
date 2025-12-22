// JS Benchmark for JSON using JS FFI (native JSON.parse/stringify)
// This tests the bundle size reduction when using native JavaScript JSON

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
extern "js" fn double_to_string_js(d : Double) -> String =
  #| (x) => String(x)

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
  console_log("=== JSON JS FFI Benchmark (using native JSON.parse/stringify) ===")

  // Test strings
  let simple_json = "{\"name\": \"test\", \"value\": 42}"
  let array_json = "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  let nested_json = "{\"user\": {\"name\": \"Alice\", \"age\": 30, \"active\": true}}"

  // Benchmark: parse simple object
  bench("json_parse_ffi_simple", 1000, fn() {
    ignore(parse_ffi(simple_json))
  })

  // Benchmark: parse array
  bench("json_parse_ffi_array", 1000, fn() {
    ignore(parse_ffi(array_json))
  })

  // Benchmark: parse nested object
  bench("json_parse_ffi_nested", 1000, fn() {
    ignore(parse_ffi(nested_json))
  })

  // Build large JSON for benchmark
  let mut large_json = "["
  for i in 0..<100 {
    if i > 0 {
      large_json = large_json + ", "
    }
    large_json = large_json + i.to_string()
  }
  large_json = large_json + "]"

  bench("json_parse_ffi_100_numbers", 100, fn() {
    ignore(parse_ffi(large_json))
  })

  // Benchmark: stringify
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string("test")
  obj["value"] = Json::number(42.0)
  obj["active"] = Json::boolean(true)
  let json_obj = Json::object(obj)

  bench("json_stringify_ffi_object", 1000, fn() {
    ignore(stringify_ffi(json_obj))
  })

  let arr : Json = Json::array([
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
    Json::number(4.0),
    Json::number(5.0),
  ])
  bench("json_stringify_ffi_array", 1000, fn() {
    ignore(stringify_ffi(arr))
  })

  // Correctness tests
  console_log("")
  console_log("=== Correctness Tests ===")

  // parse null
  match parse_ffi("null") {
    Some(Null) => console_log("parse(null) => Null OK")
    _ => console_log("parse(null) => FAILED")
  }

  // parse number
  match parse_ffi("42") {
    Some(Number(n, ..)) => console_log("parse(42) => Number(\{double_to_string_js(n)}) OK")
    _ => console_log("parse(42) => FAILED")
  }

  // parse string
  match parse_ffi("\"hello\"") {
    Some(String(s)) => console_log("parse(\"hello\") => String(\{s}) OK")
    _ => console_log("parse(\"hello\") => FAILED")
  }

  // parse object
  match parse_ffi("{\"key\": \"value\"}") {
    Some(Object(obj)) => {
      match obj.get("key") {
        Some(String(v)) => console_log("parse object => Object with key=\{v} OK")
        _ => console_log("parse object => FAILED (key not found)")
      }
    }
    _ => console_log("parse object => FAILED")
  }

  // stringify
  let json = Json::object({
    "name": Json::string("test"),
    "count": Json::number(42.0),
  })
  let result = stringify_ffi(json)
  console_log("stringify object => \{result}")

  console_log("")
  console_log("=== Done ===")
}
