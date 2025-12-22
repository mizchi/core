# Double::to_string JS FFI Optimization Report

## Summary

Replaced the Ryu algorithm implementation with JavaScript's native `String(x)` for the JS backend, achieving 97% bundle size reduction and significant performance improvement.

## Bundle Size Comparison

| Package | Before (Raw) | After (Raw) | Before (Gzip) | After (Gzip) | Reduction |
|---------|-------------|-------------|---------------|--------------|-----------|
| double  | 72 KB       | **2.3 KB**  | 12.5 KB       | **0.7 KB**   | **97%**   |

## Performance Comparison

| Test Case | Before (Ryu) | After (JS FFI) | Speedup |
|-----------|-------------|----------------|---------|
| simple (42.0) | 0.65 us | 0.03 us | **22x** |
| decimal (3.14159) | 1.81 us | 0.02 us | **90x** |
| scientific (1.23e-100) | 1.33 us | 0.01 us | **133x** |
| large number | 0.73 us | 0.01 us | **73x** |

## Implementation

### JS FFI (to_string_js.mbt)

```moonbit
pub fn Double::to_string(self : Double) -> String {
  js_double_to_string(self)
}

extern "js" fn js_double_to_string(d : Double) -> String =
  #| (x) => String(x)
```

### Non-JS (to_string_nonjs.mbt)

```moonbit
pub fn Double::to_string(self : Double) -> String {
  @ryu.ryu_to_string(self)
}
```

### Target Configuration (moon.pkg.json)

```json
"to_string_js.mbt": ["js"],
"to_string_nonjs.mbt": ["not", "js"]
```

## Test Results

- All 5197 tests passed
- JavaScript `String(-0)` returns `"0"`, matching Ryu behavior

## Files Changed

1. `double/to_string_js.mbt` (new)
2. `double/to_string_nonjs.mbt` (new)
3. `double/double.mbt` (removed to_string)
4. `double/moon.pkg.json` (added targets)
