// Benchmark for strconv operations

///|
/// Benchmark parse_int
test "bench_strconv_parse_int" (b : @bench.T) {
  let simple = "12345"
  let negative = "-98765"
  let hex = "0xFF"
  b.bench(
    name="parse_int_simple",
    fn() {
      try {
        b.keep(@strconv.parse_int(simple))
      } catch {
        _ => ()
      }
    },
  )
  b.bench(
    name="parse_int_negative",
    fn() {
      try {
        b.keep(@strconv.parse_int(negative))
      } catch {
        _ => ()
      }
    },
  )
  b.bench(
    name="parse_int_hex",
    fn() {
      try {
        b.keep(@strconv.parse_int(hex))
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark parse_int64
test "bench_strconv_parse_int64" (b : @bench.T) {
  let large = "9223372036854775807"
  b.bench(
    name="parse_int64_large",
    fn() {
      try {
        b.keep(@strconv.parse_int64(large))
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark parse_double
test "bench_strconv_parse_double" (b : @bench.T) {
  let simple = "3.14159"
  let scientific = "1.23e-10"
  let large = "123456789.987654321"
  b.bench(
    name="parse_double_simple",
    fn() {
      try {
        b.keep(@strconv.parse_double(simple))
      } catch {
        _ => ()
      }
    },
  )
  b.bench(
    name="parse_double_scientific",
    fn() {
      try {
        b.keep(@strconv.parse_double(scientific))
      } catch {
        _ => ()
      }
    },
  )
  b.bench(
    name="parse_double_large",
    fn() {
      try {
        b.keep(@strconv.parse_double(large))
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark parse_bool
test "bench_strconv_parse_bool" (b : @bench.T) {
  b.bench(
    name="parse_bool_true",
    fn() {
      try {
        b.keep(@strconv.parse_bool("true"))
      } catch {
        _ => ()
      }
    },
  )
  b.bench(
    name="parse_bool_false",
    fn() {
      try {
        b.keep(@strconv.parse_bool("false"))
      } catch {
        _ => ()
      }
    },
  )
}
