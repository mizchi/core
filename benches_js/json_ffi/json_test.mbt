// Tests for JS FFI JSON parse implementation

///|
test "parse null" {
  let result = @json_ffi.parse_ffi("null")
  guard result is Some(Null)
}

///|
test "parse true" {
  let result = @json_ffi.parse_ffi("true")
  guard result is Some(True)
}

///|
test "parse false" {
  let result = @json_ffi.parse_ffi("false")
  guard result is Some(False)
}

///|
test "parse number" {
  let result = @json_ffi.parse_ffi("42")
  guard result is Some(Number(n, ..)) && n == 42.0
}

///|
test "parse negative number" {
  let result = @json_ffi.parse_ffi("-3.14")
  match result {
    Some(Number(n, ..)) => inspect(n, content="-3.14")
    _ => fail("expected number")
  }
}

///|
test "parse string" {
  let result = @json_ffi.parse_ffi("\"hello\"")
  guard result is Some(String(s)) && s == "hello"
}

///|
test "parse empty array" {
  let result = @json_ffi.parse_ffi("[]")
  match result {
    Some(Array(arr)) => inspect(arr.length(), content="0")
    _ => fail("expected array")
  }
}

///|
test "parse array" {
  let result = @json_ffi.parse_ffi("[1, 2, 3]")
  match result {
    Some(Array(arr)) => inspect(arr.length(), content="3")
    _ => fail("expected array")
  }
}

///|
test "parse empty object" {
  let result = @json_ffi.parse_ffi("{}")
  match result {
    Some(Object(obj)) => inspect(obj.length(), content="0")
    _ => fail("expected object")
  }
}

///|
test "parse object" {
  let result = @json_ffi.parse_ffi("{\"name\": \"test\", \"value\": 42}")
  match result {
    Some(Object(obj)) => {
      inspect(obj.length(), content="2")
      match obj.get("name") {
        Some(String(name)) => inspect(name, content="test")
        _ => fail("expected name string")
      }
      match obj.get("value") {
        Some(Number(value, ..)) => inspect(value, content="42")
        _ => fail("expected value number")
      }
    }
    _ => fail("expected object")
  }
}

///|
test "parse nested object" {
  let result = @json_ffi.parse_ffi("{\"user\": {\"name\": \"Alice\", \"age\": 30}}")
  match result {
    Some(Object(obj)) => {
      match obj.get("user") {
        Some(Object(user)) => {
          match user.get("name") {
            Some(String(name)) => inspect(name, content="Alice")
            _ => fail("expected name string")
          }
          match user.get("age") {
            Some(Number(age, ..)) => inspect(age, content="30")
            _ => fail("expected age number")
          }
        }
        _ => fail("expected user object")
      }
    }
    _ => fail("expected object")
  }
}

///|
test "parse mixed array" {
  let result = @json_ffi.parse_ffi("[1, \"hello\", true, null, {\"a\": 1}]")
  match result {
    Some(Array(arr)) => {
      inspect(arr.length(), content="5")
      guard arr.get(0) is Some(Number(_, ..))
      guard arr.get(1) is Some(String(_))
      guard arr.get(2) is Some(True)
      guard arr.get(3) is Some(Null)
      guard arr.get(4) is Some(Object(_))
    }
    _ => fail("expected array")
  }
}

///|
test "parse invalid json" {
  let result = @json_ffi.parse_ffi("invalid")
  guard result is None
}

///|
test "stringify null" {
  let json : Json = null
  inspect(@json_ffi.stringify_ffi(json), content="null")
}

///|
test "stringify boolean" {
  inspect(@json_ffi.stringify_ffi(Json::boolean(true)), content="true")
  inspect(@json_ffi.stringify_ffi(Json::boolean(false)), content="false")
}

///|
test "stringify number" {
  let json = Json::number(42.0)
  inspect(@json_ffi.stringify_ffi(json), content="42")
}

///|
test "stringify string" {
  let json = Json::string("hello")
  inspect(@json_ffi.stringify_ffi(json), content="\"hello\"")
}

///|
test "stringify array" {
  let json : Json = Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)])
  inspect(@json_ffi.stringify_ffi(json), content="[1,2,3]")
}

///|
test "stringify object" {
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string("test")
  obj["value"] = Json::number(42.0)
  let json = Json::object(obj)
  // Note: order may vary
  let result = @json_ffi.stringify_ffi(json)
  guard result.contains("\"name\":\"test\"")
  guard result.contains("\"value\":42")
}
