# JSON JS FFI Optimization Report

## Summary

Replaced the MoonBit JSON parser/serializer with JavaScript's native `JSON.parse`/`JSON.stringify` for the JS backend, achieving 90% bundle size reduction.

## Bundle Size Comparison

| Package | Before (Raw) | After (Raw) | Before (Gzip) | After (Gzip) | Reduction |
|---------|-------------|-------------|---------------|--------------|-----------|
| json    | 258 KB      | **23 KB**   | 29 KB         | **4 KB**     | **90% / 84%** |

### Size Breakdown

Original implementation:
- Lexer (lex_main, lex_number, lex_string, lex_misc): multiple files
- Parser (parse.mbt): ~120 lines
- Serializer (stringify in json.mbt): ~200 lines
- Type conversion (from_json.mbt): must be maintained

JS FFI implementation:
- FFI function definitions: ~15 functions
- Conversion layer: ~100 lines
- Total: ~150 lines

## Performance Comparison

| Test Case | Before (MoonBit) | After (JS FFI) | Speedup |
|-----------|-----------------|----------------|---------|
| parse simple object | 27.0 us | 10.2 us | **2.6x** |
| parse array | 5.9 us | 11.3 us | 0.5x (slower) |
| stringify object | 2.8 us | 0.8 us | **3.5x** |
| parse 100 numbers | 58.7 us | 16.8 us | **3.5x** |

Note: Array parsing is slower due to FFI overhead for converting to MoonBit Map.

## Test Results

- 19/19 tests passed
- Covers: null, boolean, number, string, array, object, nested structures
- Error handling: invalid JSON returns None

## Implementation Details

### Challenge 1: MoonBit Map Representation

MoonBit's Map is a LinkedHashMap with complex structure:

```moonbit
struct Map[K, V] {
  mut entries : FixedArray[Entry[K, V]?]
  mut size : Int
  mut capacity : Int
  mut capacity_mask : Int
  mut grow_at : Int
  mut head : Entry[K, V]?
  mut tail : Int
}
```

Strategy: Return entries as array from JS, convert to Map in MoonBit:

```moonbit
fn convert_object_entries(entries : JSObjectEntries) -> Map[String, Json] {
  let map : Map[String, Json] = {}
  for i in 0..<js_object_entries_length(entries) {
    let key = js_object_entries_key(entries, i)
    let value = convert_json_internal(js_object_entries_value(entries, i))
    map[key] = value
  }
  map
}
```

### Challenge 2: MoonBit Enum JS Representation

```javascript
// Singleton (Null, True, False)
{ $tag: 0 }

// With constructor (Number, String, Array, Object)
function JsonNumber(n, repr) { this._0 = n; this._1 = repr; }
JsonNumber.prototype.$tag = 3;
```

### Challenge 3: Error Handling

```javascript
try {
  return { ok: true, value: convert(JSON.parse(s)) };
} catch (e) {
  return { ok: false };
}
```

```moonbit
pub fn parse_ffi(input : String) -> Json? {
  let result = js_json_parse_raw(input)
  if js_parse_result_ok(result) {
    Some(convert_json_internal(js_parse_result_value(result)))
  } else {
    None
  }
}
```

## Known Limitations

### 1. No Detailed Error Information

```moonbit
// Original: detailed error with position
parse(input) // => raise InvalidChar({ line: 3, column: 5 }, 'x')

// FFI: success/failure only
parse_ffi(input) // => None
```

### 2. Number repr Field Loss

```moonbit
// Original: preserves representation
Number(1e100, repr=Some("1e100"))

// FFI: number only
Number(1e100, repr=None)
```

### 3. from_json Layer Must Be Maintained

Type conversion (`FromJson` trait implementations) must remain in MoonBit.

## V8 Subset Concern

Unlike Regex FFI, JSON FFI has minimal V8 subset issues:

1. **JSON spec stability**: RFC 8259 strictly defines JSON, minimal implementation differences
2. **Semantic consistency**: V8's JSON.parse follows ECMAScript specification
3. **Few edge cases**: Unlike regex, JSON interpretation has almost no ambiguity

Remaining concerns:
- Number precision for very large/small numbers
- Loss of detailed error position information
- Cannot support custom JSON syntax (comments, etc.)

## Files Created

```
benches_js/json_ffi/
├── moon.pkg.json       # Package configuration
├── main.mbt            # Benchmark code
├── json_parse.mbt      # FFI implementation
└── json_test.mbt       # Test cases (19 tests)
```

## FFI Functions Implemented

```moonbit
// Parse result access
extern "js" fn js_parse_result_ok(result : JSParseResult) -> Bool
extern "js" fn js_parse_result_value(result : JSParseResult) -> Json

// Object entries operations
extern "js" fn js_object_entries_length(entries : JSObjectEntries) -> Int
extern "js" fn js_object_entries_key(entries : JSObjectEntries, index : Int) -> String
extern "js" fn js_object_entries_value(entries : JSObjectEntries, index : Int) -> Json

// Main parse function
extern "js" fn js_json_parse_raw(input : String) -> JSParseResult

// Object detection
extern "js" fn js_is_object_entries(json : Json) -> Bool
extern "js" fn js_get_object_entries(json : Json) -> JSObjectEntries

// Stringify
extern "js" fn js_json_stringify_impl(json : Json) -> String
```

## Comparison with Other FFI Optimizations

| Aspect | Double FFI | JSON FFI | Regex FFI |
|--------|-----------|----------|-----------|
| Size Reduction | 97% | 90% | 97% |
| Performance | 22-133x faster | 0.5-3.5x | 19-79x faster |
| V8 Subset Risk | None | Low | High |
| Implementation | Simple | Medium | Simple |
| Recommendation | **Adopt** | **Adopt** | Careful consideration |

## Combined Bundle Size Analysis (Regex + JSON)

### Bundle Size Comparison

| Package | Size | Notes |
|---------|------|-------|
| `regex_ffi` (standalone) | **10.6 KB** | Minimal FFI-only implementation |
| `string/regex` (JS FFI integrated) | **61 KB** | With String ops, error handling |
| `json` | **259 KB** | Full JSON implementation |
| `regex + json` (combined) | **305 KB** | 15KB smaller than sum (320KB) |

### Benchmark Results (regex_json)

```
regex_parse_log:      9.66 us/op   (1000 iterations)
json_stringify:      15.77 us/op   (1000 iterations)
json_parse:          15.27 us/op   (1000 iterations)
regex_json_combined:  5.02 us/op   (500 iterations)
batch_process_logs:  27.95 us/op   (200 iterations)
```

### Key Findings

1. **Treeshaking works correctly**: VM/parser code is excluded from JS bundle
2. **Shared code optimization**: Combined bundle is 15KB smaller than individual sum
3. **JS FFI integration complete**: `string/regex` now uses native JS RegExp on JS target
4. **43 tests pass** on JS target, 124 tests pass on Wasm target

### File Structure (string/regex/internal/regexp)

```
top_ffi_js.mbt       # JS FFI implementation (JS target only)
top_nonjs.mbt        # MoonBit VM implementation (non-JS targets)
alias_js.mbt         # JS target aliases
alias_nonjs.mbt      # Non-JS target aliases
regex_test_js.mbt    # 43 JS-compatible tests (both targets)
regex_test.mbt       # 81 MoonBit-specific tests (non-JS only)
```

### moon.pkg.json targets configuration

```json
{
  "targets": {
    "top_ffi_js.mbt": ["js"],
    "top_nonjs.mbt": ["not", "js"],
    "alias_js.mbt": ["js"],
    "alias_nonjs.mbt": ["not", "js"],
    "regex_test.mbt": ["not", "js"],
    "regex_test_js.mbt": []  // runs on both
  }
}
```

## Conclusion

JS FFI JSON parser achieves **90% bundle size reduction**. Performance varies by operation but is generally equal or better.

Advantages over Regex FFI:
- JSON spec is stable, minimal V8 subset issues
- Almost no semantic differences
- Implementation is relatively simple

Adoption considerations:
- Effective when detailed error info is not needed
- Optimal for bundle-size-focused web applications
- from_json layer must be maintained in MoonBit

## Recommendations

1. **Opt-in approach**: Default to MoonBit pure implementation, allow JS FFI selection via `moon.pkg.json`
2. **Documentation**: Clearly document limitations (no error details, repr loss)
3. **Gradual adoption**: Start with parse FFI, consider stringify later

## Update Log

### 2024-12-22: JSON FFI Integration into Main Package

- Integrated JS FFI JSON parse into `json/parse_ffi_js.mbt`
- Configured `moon.pkg.json` targets to exclude lexer/parser on JS target
- Non-JS files: `parse.mbt`, `lex_*.mbt`, `internal_types.mbt`, `utils.mbt`
- JS-only files: `parse_ffi_js.mbt`

**Bundle Size Results (regex + json combined):**
| Metric | Before | After | Reduction |
|--------|--------|-------|-----------|
| Raw | 305 KB | **103 KB** | **66%** |
| Gzip | - | **14.5 KB** | - |

**Test Results:**
- Wasm target: 32/32 parse tests pass
- JS target: Benchmark runs correctly

### 2024-12-22: Regex + JSON Integration

- Integrated JS FFI regex implementation into `string/regex/internal/regexp`
- Added 43 JS-compatible tests (`regex_test_js.mbt`)
- Created `benches_js/regex_json` for combined bundle size measurement
- Verified treeshaking correctly excludes VM/parser code from JS bundle
- Combined regex+json bundle achieves 15KB code sharing optimization
