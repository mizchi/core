// JS Benchmark for string/regex
// This file is used to measure bundle size and JS FFI performance

///|
extern "js" fn performance_now() -> Double =
  #| () => performance.now()

///|
extern "js" fn console_log(msg : String) -> Unit =
  #| (msg) => console.log(msg)

///|
fn bench(name : String, iterations : Int, f : () -> Unit) -> Unit {
  let start = performance_now()
  for _ in 0..<iterations {
    f()
  }
  let end = performance_now()
  let total_ms = end - start
  let per_op_us = total_ms * 1000.0 / iterations.to_double()
  console_log("\{name}: \{per_op_us.to_string()} us/op (total: \{total_ms.to_string()} ms)")
}

///|
fn main {
  console_log("=== Regex JS Benchmark ===")

  // Compile regex patterns
  let simple_pattern = try {
    @re.compile("hello")
  } catch {
    _ => {
      console_log("Failed to compile simple pattern")
      return
    }
  }

  let email_pattern = try {
    @re.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")
  } catch {
    _ => {
      console_log("Failed to compile email pattern")
      return
    }
  }

  let number_pattern = try {
    @re.compile("-?[0-9]+(\\.[0-9]+)?")
  } catch {
    _ => {
      console_log("Failed to compile number pattern")
      return
    }
  }

  // Benchmark: simple match using execute
  let text : StringView = "hello world"
  bench("regex_execute_simple", 1000, fn() {
    ignore(simple_pattern.execute(text))
  })

  // Benchmark: email validation using execute
  let email : StringView = "test@example.com"
  bench("regex_execute_email", 1000, fn() {
    ignore(email_pattern.execute(email))
  })

  // Benchmark: number extraction using execute
  let number_text : StringView = "The value is 123.456"
  bench("regex_execute_number", 1000, fn() {
    ignore(number_pattern.execute(number_text))
  })

  // Benchmark: multiple matches (simulate find_all by repeated execute)
  let multi_text : StringView = "hello hello hello"
  bench("regex_find_multiple", 1000, fn() {
    let mut remaining = multi_text
    let mut count = 0
    while true {
      match simple_pattern.execute(remaining) {
        Some(result) => {
          count = count + 1
          remaining = result.after()
          if remaining.length() == 0 {
            break
          }
        }
        None => break
      }
    }
    ignore(count)
  })

  // Benchmark: regex compilation
  bench("regex_compile_simple", 100, fn() {
    try {
      ignore(@re.compile("hello"))
    } catch {
      _ => ()
    }
  })

  bench("regex_compile_complex", 100, fn() {
    try {
      ignore(@re.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"))
    } catch {
      _ => ()
    }
  })

  console_log("=== Done ===")
}
