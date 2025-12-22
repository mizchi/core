// JS Benchmark for HashMap
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
  console_log("=== HashMap JS Benchmark ===")

  // Benchmark: HashMap insert
  bench("hashmap_insert_1000", 100, fn() {
    let map : @hm.HashMap[Int, Int] = @hm.new()
    for i in 0..<1000 {
      map.set(i, i)
    }
  })

  // Benchmark: HashMap get
  let map : @hm.HashMap[Int, Int] = @hm.new()
  for i in 0..<1000 {
    map.set(i, i)
  }
  bench("hashmap_get_1000", 100, fn() {
    for i in 0..<1000 {
      ignore(map.get(i))
    }
  })

  // Benchmark: HashMap with string keys
  bench("hashmap_string_insert_100", 100, fn() {
    let smap : @hm.HashMap[String, Int] = @hm.new()
    for i in 0..<100 {
      smap.set("key_\{i}", i)
    }
  })

  console_log("=== Done ===")
}
