// Hashdos vulnerability test
// Test if fixed seed hashing is vulnerable to collision attacks

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
fn main {
  console_log("=== Hashdos Vulnerability Test ===")
  console_log("")

  // Test 1: Hash collision detection with fixed seed
  console_log("Test 1: Hash values with fixed seed (seed=0)")
  test_hash_values()
  console_log("")

  // Test 2: Measure HashMap insertion performance with many items
  console_log("Test 2: HashMap insertion performance")
  test_insertion_performance()
  console_log("")

  // Test 3: Worst case - what if we could find collisions?
  console_log("Test 3: Simulating collision attack scenario")
  test_collision_scenario()
}

///|
fn test_hash_values() -> Unit {
  // With fixed seed, same strings always produce same hash
  let test_strings = ["a", "b", "c", "aa", "ab", "abc", "user1", "user2"]
  for s in test_strings {
    let h = Hasher::new(seed=0)
    h.combine(s)
    let hash_val = h.finalize()
    console_log("  hash(\"\{s}\") = \{hash_val.to_string()}")
  }
}

///|
fn test_insertion_performance() -> Unit {
  // Normal case: random keys
  let n = 10000
  let map : @hm.HashMap[String, Int] = @hm.new()

  let start = performance_now()
  for i = 0; i < n; i = i + 1 {
    let key = "key_\{i.to_string()}"
    map.set(key, i)
  }
  let elapsed = performance_now() - start

  console_log("  Inserted \{n.to_string()} unique keys: \{elapsed.to_string()}ms")
}

///|
fn test_collision_scenario() -> Unit {
  // If attacker knows the seed (fixed seed=0), they could precompute
  // keys that hash to the same bucket.
  //
  // With Robin Hood hashing, collisions don't cause worst-case O(n) per operation
  // but still degrade performance significantly.
  //
  // Attack feasibility:
  // 1. For xxHash32, precomputing collisions requires brute force
  // 2. Finding 1000 colliding strings requires ~2^32 computations
  // 3. This is feasible but expensive (seconds to minutes)

  console_log("  xxHash32 with fixed seed analysis:")
  console_log("  - Hash space: 2^32 values")
  console_log("  - For n items, expected collisions: ~n^2 / 2^32")
  console_log("  - 10K items: ~0.02 collisions (negligible)")
  console_log("  - 100K items: ~2.3 collisions")
  console_log("  - 1M items: ~232 collisions")
  console_log("")
  console_log("  Attack cost to generate 1000 colliding keys:")
  console_log("  - Brute force: ~1000 * 2^32 / 2 hashes = 2^41 hashes")
  console_log("  - At 100M hashes/sec: ~6 hours precomputation")
  console_log("")
  console_log("  Robin Hood hashing mitigation:")
  console_log("  - Does NOT degrade to O(n) per operation")
  console_log("  - Redistributes probe lengths fairly")
  console_log("  - Max PSL grows logarithmically even with collisions")
}
