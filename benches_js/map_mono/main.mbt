// Test monomorphization: Multiple Map types
// Check if Map[String, Int], Map[Int, String], Map[String, String] cause code duplication

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
fn main {
  // Type 1: Map[String, Int]
  let m1 : Map[String, Int] = {}
  m1["a"] = 1

  // Type 2: Map[Int, String]
  let m2 : Map[Int, String] = {}
  m2[1] = "one"

  // Type 3: Map[String, String]
  let m3 : Map[String, String] = {}
  m3["key"] = "value"

  // Type 4: HashMap[String, Int]
  let h1 : @hm.HashMap[String, Int] = @hm.new()
  h1.set("x", 10)

  // Type 5: HashMap[Int, Int]
  let h2 : @hm.HashMap[Int, Int] = @hm.new()
  h2.set(1, 100)

  console_log("m1 size: \{m1.length().to_string()}")
  console_log("m2 size: \{m2.length().to_string()}")
  console_log("m3 size: \{m3.length().to_string()}")
  console_log("h1 size: \{h1.length().to_string()}")
  console_log("h2 size: \{h2.length().to_string()}")
}
