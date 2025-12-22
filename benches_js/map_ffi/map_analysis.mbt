// Analysis: Can JS Map be used as a facade for MoonBit Map?
//
// This file investigates the feasibility of replacing MoonBit's Map with JS Map FFI.

// === JS Map FFI Test ===

///|
type JSMap

///|
extern "js" fn js_map_new() -> JSMap =
  #| () => new Map()

///|
extern "js" fn js_map_set_string_int(map : JSMap, key : String, value : Int) -> Unit =
  #| (map, key, value) => map.set(key, value)

///|
extern "js" fn js_map_get_string_int(map : JSMap, key : String) -> Int =
  #| (map, key) => map.get(key) ?? 0

///|
extern "js" fn js_map_has(map : JSMap, key : String) -> Bool =
  #| (map, key) => map.has(key)

///|
extern "js" fn js_map_size(map : JSMap) -> Int =
  #| (map) => map.size

///|
extern "js" fn js_map_delete(map : JSMap, key : String) -> Bool =
  #| (map, key) => map.delete(key)

// Test JS Map behavior
///|
pub fn test_js_map() -> Unit {
  let map = js_map_new()
  js_map_set_string_int(map, "a", 1)
  js_map_set_string_int(map, "b", 2)
  js_map_set_string_int(map, "c", 3)

  let size = js_map_size(map)
  console_log("JS Map size: \{size.to_string()}")
  let val_a = js_map_get_string_int(map, "a")
  console_log("JS Map get 'a': \{val_a.to_string()}")
  let has_b = js_map_has(map, "b")
  console_log("JS Map has 'b': \{has_b.to_string()}")
  let has_x = js_map_has(map, "x")
  console_log("JS Map has 'x': \{has_x.to_string()}")
}

// === Analysis of incompatibilities ===

// Problem 1: MoonBit Map internal structure
// MoonBit Map uses:
//   - FixedArray[Entry[K, V]?] for entries (indexed by hash)
//   - Entry has: prev, next, psl, hash, key, value
//   - Doubly-linked list via head/tail for insertion order
//   - Robin Hood hashing with PSL (probe sequence length)
//
// JS Map uses:
//   - Native internal structure (not accessible)
//   - Maintains insertion order internally
//   - Uses === equality (reference for objects, value for primitives)

// Problem 2: Hash trait requirement
// MoonBit Map[K, V] requires K : Hash + Eq
// JS Map uses === equality, which:
//   - Works for primitives (strings, numbers)
//   - Compares by reference for objects
//   - Cannot use custom Hash implementation

// Problem 3: Field access patterns
// MoonBit code directly accesses:
//   self.entries[idx]
//   self.head, self.tail
//   entry.psl, entry.prev, entry.next
// This cannot be replicated with JS Map

// Problem 4: Generic type constraint
// MoonBit: Map[K : Hash + Eq, V]
// JS Map: No type constraints, uses ===
// A JS Map facade would only work for:
//   - String keys
//   - Number keys (with caveats)
// Complex keys (structs) would not work properly

// === Hasher Analysis ===

// Current Hasher implementation: xxHash32
// - ~100 lines of core algorithm
// - Uses: rotl, consume4, consume1, avalanche
// - Magic constants: GPRIME1-5

// Potential optimization: JS has no built-in hash function
// Options:
// 1. Keep xxHash32 (current) - deterministic, cross-platform compatible
// 2. Use WeakMap with object identity - only works for object keys
// 3. Use String-based fallback - convert everything to string, hash that

///|
extern "js" fn js_string_hash(s : String) -> Int =
  #| (s) => {
  #|   // Simple djb2 hash
  #|   let hash = 5381;
  #|   for (let i = 0; i < s.length; i++) {
  #|     hash = ((hash << 5) + hash) + s.charCodeAt(i);
  #|     hash = hash | 0; // Convert to 32bit integer
  #|   }
  #|   return hash;
  #| }

///|
pub fn test_js_hash() -> Unit {
  let h1 = js_string_hash("hello")
  let h2 = js_string_hash("hello")
  let h3 = js_string_hash("world")
  console_log("Hash 'hello' (1): \{h1.to_string()}")
  console_log("Hash 'hello' (2): \{h2.to_string()}")
  console_log("Hash 'world': \{h3.to_string()}")
  console_log("Same hash for same string: \{(h1 == h2).to_string()}")
}
