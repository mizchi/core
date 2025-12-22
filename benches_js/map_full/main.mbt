// Full Map Bundle Size Test
// Includes both builtin Map (LinkedHashMap) and hashmap.HashMap

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
fn main {
  console_log("=== Full Map Bundle Test ===")

  // Use builtin Map (LinkedHashMap)
  let linked_map : Map[String, Int] = {}
  linked_map["a"] = 1
  linked_map["b"] = 2
  linked_map["c"] = 3
  console_log("LinkedHashMap size: \{linked_map.length().to_string()}")

  // Iterate to use more Map APIs
  let mut sum = 0
  linked_map.each(fn(k, v) {
    console_log("  \{k}: \{v.to_string()}")
    sum = sum + v
  })
  console_log("Sum: \{sum.to_string()}")

  // Use HashMap
  let hash_map : @hm.HashMap[String, Int] = @hm.new()
  hash_map.set("x", 10)
  hash_map.set("y", 20)
  hash_map.set("z", 30)
  console_log("HashMap size: \{hash_map.length().to_string()}")

  // Use more HashMap APIs
  let val = hash_map.get("x")
  match val {
    Some(v) => console_log("HashMap get x: \{v.to_string()}")
    None => console_log("HashMap get x: None")
  }

  // contains
  let has_y = hash_map.contains("y")
  console_log("HashMap contains y: \{has_y.to_string()}")

  // remove
  hash_map.remove("z")
  console_log("HashMap after remove z: \{hash_map.length().to_string()}")

  console_log("=== Done ===")
}
