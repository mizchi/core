// Benchmark for JSON operations

///|
/// Benchmark JSON parsing
test "bench_json_parse" (b : @bench.T) {
  let simple_json = "{\"name\": \"test\", \"value\": 42}"
  b.bench(
    name="json_parse_simple",
    fn() {
      try {
        b.keep(@json.parse(simple_json))
      } catch {
        _ => ()
      }
    },
  )
  let array_json = "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  b.bench(
    name="json_parse_array",
    fn() {
      try {
        b.keep(@json.parse(array_json))
      } catch {
        _ => ()
      }
    },
  )
  let nested_json = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}}"
  b.bench(
    name="json_parse_nested",
    fn() {
      try {
        b.keep(@json.parse(nested_json))
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark JSON stringify
test "bench_json_stringify" (b : @bench.T) {
  let obj : Json = Json::object(
    Map::of(
      [
        ("name", Json::string("test")),
        ("value", Json::number(42.0)),
        ("active", Json::boolean(true)),
      ],
    ),
  )
  b.bench(
    name="json_stringify_object",
    fn() {
      b.keep(obj.stringify())
    },
  )
  let arr : Json = Json::array(
    Array::makei(10, fn(i) { Json::number(i.to_double()) }),
  )
  b.bench(
    name="json_stringify_array",
    fn() {
      b.keep(arr.stringify())
    },
  )
}

///|
/// Benchmark JSON round-trip (parse + stringify)
test "bench_json_roundtrip" (b : @bench.T) {
  let json_str = "{\"users\": [{\"id\": 1, \"name\": \"Alice\"}, {\"id\": 2, \"name\": \"Bob\"}]}"
  b.bench(
    name="json_roundtrip",
    fn() {
      try {
        let parsed = @json.parse(json_str)
        b.keep(parsed.stringify())
      } catch {
        _ => ()
      }
    },
  )
}

///|
/// Benchmark large JSON array parsing
test "bench_json_large_array" (b : @bench.T) {
  // Create a JSON string with 100 numbers
  let mut json_str = "["
  for i in 0..<100 {
    if i > 0 {
      json_str = json_str + ", "
    }
    json_str = json_str + i.to_string()
  }
  json_str = json_str + "]"
  b.bench(
    name="json_parse_100_numbers",
    fn() {
      try {
        b.keep(@json.parse(json_str))
      } catch {
        _ => ()
      }
    },
  )
}
