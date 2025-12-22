// PoC: Lazy seed initialization to avoid top-level side effects
// This pattern should eliminate treeshake-blocking top-level effects

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
extern "js" fn js_random_seed() -> Int =
  #|() => {
  #|  if (globalThis.crypto?.getRandomValues) {
  #|    const array = new Uint32Array(1);
  #|    globalThis.crypto.getRandomValues(array);
  #|    return array[0] | 0;
  #|  } else {
  #|    return Math.floor(Math.random() * 0x100000000) | 0;
  #|  }
  #|}

// Approach 1: Using mutable Option (requires initialization check on every access)
let lazy_seed : Ref[Int?] = { val: None }

///|
fn get_lazy_seed() -> Int {
  match lazy_seed.val {
    Some(s) => s
    None => {
      let s = js_random_seed()
      lazy_seed.val = Some(s)
      s
    }
  }
}

// Approach 2: Using sentinel value (-1 or 0 as "uninitialized" is problematic)
// Not ideal for hash seeds since any value is valid

// Custom Hasher with lazy seed
const GPRIME5 : UInt = 0x165667B1

///|
struct LazyHasher {
  mut acc : UInt
}

///|
fn LazyHasher::new(seed? : Int) -> LazyHasher {
  let actual_seed = match seed {
    Some(s) => s
    None => get_lazy_seed()
  }
  { acc: actual_seed.reinterpret_as_uint() + GPRIME5 }
}

///|
fn main {
  console_log("=== Lazy Seed Initialization Test ===")

  // First use - should trigger lazy initialization
  let h1 = LazyHasher::new()
  console_log("Hasher 1 created with lazy seed")

  // Second use - should reuse cached seed
  let h2 = LazyHasher::new()
  console_log("Hasher 2 created with cached seed")

  // Explicit seed - should not use lazy seed
  let h3 = LazyHasher::new(seed=42)
  console_log("Hasher 3 created with explicit seed")

  console_log("Done")
}
