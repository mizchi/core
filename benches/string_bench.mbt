// Benchmark for String operations

///|
/// Benchmark String concatenation
test "bench_string_concat" (b : @bench.T) {
  b.bench(
    name="string_concat_10",
    fn() {
      let mut s = ""
      for _ in 0..<10 {
        s = s + "hello"
      }
      b.keep(s)
    },
  )
  b.bench(
    name="string_concat_100",
    fn() {
      let mut s = ""
      for _ in 0..<100 {
        s = s + "a"
      }
      b.keep(s)
    },
  )
}

///|
/// Benchmark StringBuilder
test "bench_stringbuilder" (b : @bench.T) {
  b.bench(
    name="stringbuilder_100",
    fn() {
      let sb = StringBuilder::new()
      for _ in 0..<100 {
        sb.write_string("hello")
      }
      b.keep(sb.to_string())
    },
  )
  b.bench(
    name="stringbuilder_1000",
    fn() {
      let sb = StringBuilder::new()
      for _ in 0..<1000 {
        sb.write_char('a')
      }
      b.keep(sb.to_string())
    },
  )
}

///|
/// Benchmark String length
test "bench_string_length" (b : @bench.T) {
  let short = "hello"
  let long = String::make(1000, 'x')
  b.bench(
    name="string_length_short",
    fn() {
      b.keep(short.length())
    },
  )
  b.bench(
    name="string_length_long",
    fn() {
      b.keep(long.length())
    },
  )
}

///|
/// Benchmark String iteration
test "bench_string_iter" (b : @bench.T) {
  let s = String::make(100, 'a')
  b.bench(
    name="string_iter_100",
    fn() {
      let mut count = 0
      for _ in s {
        count += 1
      }
      b.keep(count)
    },
  )
}

///|
/// Benchmark String comparison
test "bench_string_compare" (b : @bench.T) {
  let s1 = "hello world"
  let s2 = "hello world"
  let s3 = "hello worle"
  b.bench(
    name="string_eq_same",
    fn() {
      b.keep(s1 == s2)
    },
  )
  b.bench(
    name="string_eq_diff",
    fn() {
      b.keep(s1 == s3)
    },
  )
}
