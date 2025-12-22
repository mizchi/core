// JS Benchmark for string/regex + json bundle size measurement
// This file tests bundle size when using both regex and JSON together

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
struct LogEntry {
  timestamp : String
  level : String
  message : String
  user_id : Int?
  email : String?
} derive(ToJson, FromJson, Show)

///|
fn main {
  console_log("=== Regex + JSON Bundle Size Benchmark ===")

  // Compile regex patterns for log parsing
  let timestamp_pattern = try {
    @re.compile("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}")
  } catch {
    _ => {
      console_log("Failed to compile timestamp pattern")
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

  let log_level_pattern = try {
    @re.compile("\\[(INFO|WARN|ERROR|DEBUG)\\]")
  } catch {
    _ => {
      console_log("Failed to compile log level pattern")
      return
    }
  }

  // Sample log line
  let log_line : StringView = "2024-03-15T10:30:45 [INFO] User user@example.com logged in"

  // Benchmark: Parse log line with regex
  bench("regex_parse_log", 1000, fn() {
    let ts = timestamp_pattern.execute(log_line)
    let level = log_level_pattern.execute(log_line)
    let email = email_pattern.execute(log_line)
    ignore((ts, level, email))
  })

  // Create sample JSON data
  let entry = LogEntry::{
    timestamp: "2024-03-15T10:30:45",
    level: "INFO",
    message: "User logged in",
    user_id: Some(12345),
    email: Some("user@example.com"),
  }

  // Benchmark: JSON stringify
  bench("json_stringify", 1000, fn() {
    let json_str = entry.to_json().stringify()
    ignore(json_str)
  })

  // Benchmark: JSON parse
  let json_str2 = entry.to_json().stringify()
  bench("json_parse", 1000, fn() {
    try {
      let json = @json.parse(json_str2)
      let parsed : LogEntry = @json.from_json(json)
      ignore(parsed)
    } catch {
      _ => ()
    }
  })

  // Benchmark: Combined regex + JSON workflow
  bench("regex_json_combined", 500, fn() {
    // 1. Parse log line with regex
    let ts_result = timestamp_pattern.execute(log_line)
    let level_result = log_level_pattern.execute(log_line)
    let email_result = email_pattern.execute(log_line)

    // 2. Build structured entry
    let entry = LogEntry::{
      timestamp: match ts_result {
        Some(r) =>
          match r.group(0) {
            Some(s) => s.to_string()
            None => ""
          }
        None => ""
      },
      level: match level_result {
        Some(r) =>
          match r.group(1) {
            Some(s) => s.to_string()
            None => "UNKNOWN"
          }
        None => "UNKNOWN"
      },
      message: "User logged in",
      user_id: Some(12345),
      email: match email_result {
        Some(r) =>
          match r.group(0) {
            Some(s) => Some(s.to_string())
            None => None
          }
        None => None
      },
    }

    // 3. Convert to JSON
    let json_str = entry.to_json().stringify()
    ignore(json_str)
  })

  // Benchmark: Batch processing
  let log_lines = [
    "2024-03-15T10:30:45 [INFO] User user1@example.com logged in",
    "2024-03-15T10:31:00 [WARN] User user2@test.org failed login",
    "2024-03-15T10:31:15 [ERROR] Database connection failed",
    "2024-03-15T10:32:00 [DEBUG] Processing request from admin@site.io",
    "2024-03-15T10:33:00 [INFO] User user3@domain.com logged out",
  ]

  bench("batch_process_logs", 200, fn() {
    let entries : Array[LogEntry] = []
    for line in log_lines {
      let ts_result = timestamp_pattern.execute(line.view())
      let level_result = log_level_pattern.execute(line.view())
      let email_result = email_pattern.execute(line.view())

      let entry = LogEntry::{
        timestamp: match ts_result {
          Some(r) =>
            match r.group(0) {
              Some(s) => s.to_string()
              None => ""
            }
          None => ""
        },
        level: match level_result {
          Some(r) =>
            match r.group(1) {
              Some(s) => s.to_string()
              None => "UNKNOWN"
            }
          None => "UNKNOWN"
        },
        message: line,
        user_id: None,
        email: match email_result {
          Some(r) =>
            match r.group(0) {
              Some(s) => Some(s.to_string())
              None => None
            }
          None => None
        },
      }
      entries.push(entry)
    }

    // Convert all to JSON array
    let json_array = entries.map(fn(e) { e.to_json() })
    ignore(json_array)
  })

  console_log("=== Done ===")
}
