// JS Benchmark for Regex using JS FFI (new RegExp)
// This tests the bundle size reduction when using native JavaScript RegExp

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
extern "js" fn double_to_string_js(d : Double) -> String =
  #| (x) => String(x)

// ================================
// JS FFI RegExp Implementation
// ================================

// Opaque type for JS RegExp object
///|
type JSRegExp

// Create a new RegExp from pattern string
///|
extern "js" fn js_regexp_new(pattern : String, flags : String) -> JSRegExp =
  #| (pattern, flags) => new RegExp(pattern, flags)

// Test if pattern matches (returns bool)
///|
extern "js" fn js_regexp_test(re : JSRegExp, input : String) -> Bool =
  #| (re, input) => re.test(input)

// Execute regex and return match as String? (null if no match)
///|
extern "js" fn js_regexp_exec_full(re : JSRegExp, input : String) -> String? =
  #| (re, input) => {
  #|   const m = re.exec(input);
  #|   return m ? m[0] : null;
  #| }

// Get first capture group
///|
extern "js" fn js_regexp_exec_group1(re : JSRegExp, input : String) -> String? =
  #| (re, input) => {
  #|   const m = re.exec(input);
  #|   return (m && m[1]) ? m[1] : null;
  #| }

// Get match index (start position)
///|
extern "js" fn js_regexp_exec_index(re : JSRegExp, input : String) -> Int =
  #| (re, input) => {
  #|   const m = re.exec(input);
  #|   return m ? m.index : -1;
  #| }

// Replace all matches
///|
extern "js" fn js_regexp_replace_all(re : JSRegExp, input : String, replacement : String) -> String =
  #| (re, input, replacement) => input.replaceAll(re, replacement)

// ================================
// Benchmarks
// ================================

///|
fn bench(name : String, iterations : Int, f : () -> Unit) -> Unit {
  let start = performance_now()
  for _ in 0..<iterations {
    f()
  }
  let end = performance_now()
  let total_ms = end - start
  let per_op_us = total_ms * 1000.0 / iterations.to_double()
  console_log("\{name}: \{double_to_string_js(per_op_us)} us/op (total: \{double_to_string_js(total_ms)} ms)")
}

///|
fn main {
  console_log("=== Regex JS FFI Benchmark (using native RegExp) ===")

  // Create regex patterns using JS FFI
  let simple_re = js_regexp_new("hello", "")
  let email_re = js_regexp_new("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "")
  let number_re = js_regexp_new("-?[0-9]+(\\.[0-9]+)?", "")
  let global_re = js_regexp_new("hello", "g")

  // Test strings
  let text = "hello world"
  let email = "test@example.com"
  let number_text = "The value is 123.456"
  let multi_text = "hello hello hello"

  // Benchmark: simple match test (boolean)
  bench("regex_test_simple", 1000, fn() {
    ignore(js_regexp_test(simple_re, text))
  })

  // Benchmark: email validation test
  bench("regex_test_email", 1000, fn() {
    ignore(js_regexp_test(email_re, email))
  })

  // Benchmark: exec for full match
  bench("regex_exec_simple", 1000, fn() {
    ignore(js_regexp_exec_full(simple_re, text))
  })

  // Benchmark: number extraction with exec
  bench("regex_exec_number", 1000, fn() {
    ignore(js_regexp_exec_full(number_re, number_text))
  })

  // Benchmark: get capture group
  bench("regex_exec_capture_group", 1000, fn() {
    ignore(js_regexp_exec_group1(number_re, number_text))
  })

  // Benchmark: replace all
  bench("regex_replace_all", 1000, fn() {
    ignore(js_regexp_replace_all(global_re, multi_text, "hi"))
  })

  // Benchmark: regex creation
  bench("regex_create_simple", 100, fn() {
    ignore(js_regexp_new("hello", ""))
  })

  bench("regex_create_complex", 100, fn() {
    ignore(js_regexp_new("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", ""))
  })

  // Correctness tests
  console_log("")
  console_log("=== Correctness Tests ===")

  // test()
  console_log("test('hello', 'hello world') => " + js_regexp_test(simple_re, text).to_string())
  console_log("test('hello', 'hi world') => " + js_regexp_test(simple_re, "hi world").to_string())

  // exec full match
  match js_regexp_exec_full(simple_re, text) {
    Some(m) => console_log("exec('hello', 'hello world')[0] => " + m)
    None => console_log("exec('hello', 'hello world')[0] => null")
  }

  // email match
  match js_regexp_exec_full(email_re, email) {
    Some(m) => console_log("exec(email_pattern, email) => " + m)
    None => console_log("exec(email_pattern, email) => null")
  }

  // capture group
  match js_regexp_exec_group1(number_re, number_text) {
    Some(m) => console_log("exec(number_pattern, text)[1] (decimal part) => " + m)
    None => console_log("exec(number_pattern, text)[1] => null")
  }

  // replace all
  console_log("replaceAll('hello', 'hi') => " + js_regexp_replace_all(global_re, multi_text, "hi"))

  // match index
  let idx = js_regexp_exec_index(simple_re, text)
  console_log("exec('hello', 'hello world').index => " + idx.to_string())

  console_log("")
  console_log("=== Done ===")
}
