// Test if Show trait pulls in Double::to_string
// Map[String, Double] with to_string usage

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
fn main {
  // Map with Double values
  let m : Map[String, Double] = {}
  m["pi"] = 3.14159
  m["e"] = 2.71828

  // This should pull in Double::to_string via Show trait
  console_log(m.to_string())

  // Also test HashMap
  let h : @hm.HashMap[String, Double] = @hm.new()
  h.set("tau", 6.28318)

  // Iterate and print
  console_log("HashMap values:")
}
