// Map FFI Investigation
// Purpose: Analyze feasibility of using JS Map for MoonBit Map

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
  console_log("\{name}: \{double_to_string_js(per_op_us)} us/op")
}

///|
fn main {
  console_log("=== Map FFI Investigation ===")
  console_log("")

  // Test JS Map
  console_log("--- JS Map FFI Test ---")
  test_js_map()
  console_log("")

  // Test JS Hash
  console_log("--- JS Hash Test ---")
  test_js_hash()
  console_log("")

  // Benchmark comparison
  console_log("--- Performance Comparison ---")

  // JS Map insert
  bench("js_map_insert_1000", 100, fn() {
    let map = js_map_new()
    for i in 0..<1000 {
      js_map_set_string_int(map, "key_\{i}", i)
    }
  })

  // MoonBit Map insert (using builtin Map)
  bench("moonbit_map_insert_1000", 100, fn() {
    let map : Map[String, Int] = {}
    for i in 0..<1000 {
      map["key_\{i}"] = i
    }
  })

  // JS Map get
  let js_map = js_map_new()
  for i in 0..<1000 {
    js_map_set_string_int(js_map, "key_\{i}", i)
  }
  bench("js_map_get_1000", 100, fn() {
    for i in 0..<1000 {
      ignore(js_map_get_string_int(js_map, "key_\{i}"))
    }
  })

  // MoonBit Map get
  let mb_map : Map[String, Int] = {}
  for i in 0..<1000 {
    mb_map["key_\{i}"] = i
  }
  bench("moonbit_map_get_1000", 100, fn() {
    for i in 0..<1000 {
      ignore(mb_map.get("key_\{i}"))
    }
  })

  console_log("")
  console_log("=== Analysis Summary ===")
  console_log("")
  console_log("1. JS Map as Facade: NOT FEASIBLE")
  console_log("   - MoonBit Map uses Robin Hood hashing with PSL")
  console_log("   - MoonBit Map has complex Entry struct (prev/next/psl/hash)")
  console_log("   - MoonBit Map requires K: Hash + Eq trait bounds")
  console_log("   - JS Map uses === equality (reference for objects)")
  console_log("   - Field access patterns incompatible")
  console_log("")
  console_log("2. Hasher FFI Optimization: LIMITED BENEFIT")
  console_log("   - xxHash32 is already ~100 lines of code")
  console_log("   - JS has no built-in hash function")
  console_log("   - Replacing would break cross-platform hash consistency")
  console_log("   - Current implementation is efficient")
  console_log("")
  console_log("3. Potential Alternative Approaches:")
  console_log("   - String-only Map with JS Map backend (new type)")
  console_log("   - Specialized HashMap[String, V] with JS Map")
  console_log("   - Keep current implementation (recommended)")
  console_log("")
  console_log("=== Done ===")
}
