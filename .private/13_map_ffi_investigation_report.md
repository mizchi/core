# Map/HashMap/Hasher JS FFI Investigation Report

## Summary

Investigated feasibility of optimizing Map/HashMap/Hasher for JS backend using JS FFI. **Conclusion: NOT RECOMMENDED** - current implementation is optimal.

## Investigation Questions

### 1. Can JS Map be a facade for MoonBit Map?

**Answer: NO**

#### Structural Incompatibilities

| Aspect | MoonBit Map | JS Map |
|--------|-------------|--------|
| Internal Structure | FixedArray[Entry?] + linked list | Native hidden structure |
| Hashing | Robin Hood with PSL | Internal (V8 optimized) |
| Entry Fields | prev, next, psl, hash, key, value | Not accessible |
| Key Constraint | K: Hash + Eq | === equality |
| Object Keys | Custom hash function | Reference equality |

#### Code Patterns That Prevent Facade

```moonbit
// MoonBit Map directly accesses internal fields:
self.entries[idx]
self.head, self.tail
entry.psl, entry.prev, entry.next

// These cannot be replicated with JS Map
```

#### Type System Incompatibility

```moonbit
// MoonBit requires Hash trait
fn set[K : Hash + Eq, V](self : Map[K, V], key : K, value : V)

// JS Map uses === for all types, cannot implement:
// - Custom hash for Int, String, etc.
// - Struct key comparison by value
```

### 2. Can Hasher be optimized with low-level FFI?

**Answer: LIMITED BENEFIT**

#### Current Implementation Analysis

- xxHash32: ~100 lines of core algorithm
- Already efficient: rotl, consume4, consume1, avalanche
- Magic constants embedded (GPRIME1-5)

#### JS Hash Function Options

| Option | Pros | Cons |
|--------|------|------|
| Keep xxHash32 | Cross-platform consistent, well-tested | No size reduction |
| JS djb2/sdbm | Simpler | Different hash values, breaks tests |
| No built-in JS hash | - | JS has no standard hash function |

## Performance Benchmarks

```
js_map_insert_1000: 144 us/op
moonbit_map_insert_1000: 136 us/op  ← MoonBit 6% faster

js_map_get_1000: 29 us/op  ← JS 1.8x faster
moonbit_map_get_1000: 53 us/op
```

**Note:** Get performance difference is notable, but insert is comparable. The internal structure differences prevent direct optimization.

## Bundle Size Analysis

### Overall Size

| Build | Raw | Gzip | Notes |
|-------|-----|------|-------|
| map.js (HashMap only) | 18 KB | 3.1 KB | Current implementation |
| map_full.js (Map + HashMap) | 21 KB | 3.8 KB | Both Map types |
| map_ffi.js (+ JS Map FFI) | 22 KB | 4.4 KB | Adds FFI overhead |

**Observation:** Adding JS Map FFI actually increases bundle size by 22% due to:
- FFI wrapper functions
- Both implementations coexisting

### Detailed Breakdown (map_full.js = 21.2 KB)

| Category | Size | % | Notes |
|----------|------|---|-------|
| HashMap | 6.8 KB | 32.1% | hashmap package |
| builtin.Map | 5.3 KB | 25.0% | LinkedHashMap in builtin |
| Hasher | 2.1 KB | 9.9% | xxHash32 implementation |
| builtin.other | 1.7 KB | 8.2% | Logger, StringBuilder, etc. |
| string/int | 1.6 KB | 7.5% | String.sub, Int.to_string, etc. |
| other | 0.4 KB | 1.9% | Runtime helpers |

### Largest Functions

| Function | Size | Package |
|----------|------|---------|
| Map$set_with_hash | 1.2 KB | builtin |
| HashMap$set_with_hash | 1.2 KB | hashmap |
| String$sub (StringView) | 1.2 KB | string |
| HashMap$push_away | 1.0 KB | hashmap |
| Map$push_away | 1.0 KB | builtin |
| HashMap$grow | 0.9 KB | hashmap |
| Map$grow | 0.8 KB | builtin |
| HashMap$shift_back | 0.8 KB | hashmap |

### Key Findings

1. **HashMap and Map have near-identical code** - Both use Robin Hood hashing
2. **Hasher is compact** - Only 2.1 KB (10%) of bundle
3. **String$sub is unexpectedly large** - StringView creation with validation
4. **No obvious optimization target** - Code is already minimal

## Detailed Analysis

### Why Robin Hood Hashing Matters

MoonBit Map uses Robin Hood hashing with PSL (probe sequence length):

```moonbit
// Key lookup considers PSL
if psl > curr_entry.psl {
  // Entry would have been here, not found
  break None
}
```

This optimization cannot be replicated with JS Map.

### Why Linked List Order Matters

MoonBit Map maintains insertion order via linked list:

```moonbit
struct Entry[K, V] {
  mut prev : Int      // Previous entry index
  mut next : Entry?   // Next entry pointer
  // ...
}
```

While JS Map also maintains insertion order, the traversal patterns differ.

### Hash Trait Integration

Every MoonBit collection type that uses hashing depends on:

```moonbit
pub trait Hash {
  hash_combine(Self, Hasher) -> Unit
  hash(Self) -> Int
}
```

JS Map cannot use these custom hash implementations.

## Alternative Approaches Considered

### Option A: String-Only JSMap Type (New Type)

```moonbit
// Hypothetical specialized type
type JSStringMap[V]  // Only for String keys

extern "js" fn JSStringMap::new() -> JSStringMap[V]
extern "js" fn JSStringMap::set(self, key: String, value: V)
extern "js" fn JSStringMap::get(self, key: String) -> V?
```

**Verdict:** Would require parallel implementation, increased maintenance.

### Option B: Hasher Algorithm Replacement

```moonbit
// Replace xxHash32 with simpler hash for JS
#cfg(target="js")
extern "js" fn simple_hash(s: String) -> Int = #| djb2(s)
```

**Verdict:** Would break cross-platform hash consistency, break tests.

### Option C: Keep Current Implementation (Recommended)

- Current implementation is efficient
- Bundle size is already reasonable (3.1 KB gzip for Map)
- No compatibility issues

## Comparison with Other FFI Optimizations

| Package | FFI Optimization | Size Reduction | Feasibility |
|---------|------------------|----------------|-------------|
| Double::to_string | Replace Ryu | 97% | ✅ Adopted |
| Regex | Replace NFA VM | 97% | ✅ Adopted |
| JSON | Replace Parser | 90% | ✅ Adopted |
| Map/HashMap | Replace with JS Map | N/A | ❌ Not Feasible |
| Hasher | Replace xxHash32 | Minimal | ⚠️ Not Recommended |

## Recommendations

1. **Keep current Map/HashMap implementation** - No significant gains possible
2. **Keep current Hasher (xxHash32)** - Already optimal, cross-platform consistency important
3. **No action needed** - Map package is already efficiently sized (3.1 KB gzip)

## Files Created

```
benches_js/map_ffi/
├── moon.pkg.json       # Package configuration
├── main.mbt            # Benchmark and analysis runner
└── map_analysis.mbt    # FFI tests and compatibility analysis
```

## Conclusion

Unlike Double, Regex, and JSON where JS native APIs provide significant bundle size reduction, Map/HashMap cannot benefit from JS Map FFI because:

1. **Structural incompatibility** - MoonBit Map uses Robin Hood hashing with internal linked list
2. **Type system mismatch** - MoonBit requires Hash + Eq traits, JS uses === equality
3. **No bundle size benefit** - Adding FFI actually increases size
4. **Performance comparable** - MoonBit Map insert is faster, get is slower but acceptable

**Final Verdict: DO NOT ADOPT JS Map FFI for Map/HashMap/Hasher**
