// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Try to get this element as a Null
#deprecated("Suggestion: `if json is Null { Some(()) } else { None }`")
pub fn Json::as_null(self : Json) -> Unit? {
  guard self is Null else { return None }
  Some(())
}

///|
/// Try to get this element as a Boolean
#deprecated("Suggestion: `if json is True { Some(true) } else if json is False { Some(false) } else { None }`")
pub fn Json::as_bool(self : Json) -> Bool? {
  match self {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
/// Try to get this element as a Number
#deprecated("Suggestion: `if json is Number(n) { Some(n) } else { None }`")
pub fn Json::as_number(self : Json) -> Double? {
  guard self is Number(n, ..) else { return None }
  Some(n)
}

///|
/// Try to get this element as a String
#deprecated("Suggestion: `if json is String(s) { Some(s) } else { None }`")
pub fn Json::as_string(self : Json) -> String? {
  guard self is String(s) else { return None }
  Some(s)
}

///|
/// Try to get this element as an Array
#deprecated("Suggestion: `if json is Array(array) { Some(array) } else { None }`")
pub fn Json::as_array(self : Json) -> Array[Json]? {
  guard self is Array(arr) else { return None }
  Some(arr)
}

///|
/// Try to get this element as a Json Array and get the element at the `index` as a Json Value
#deprecated("Suggestion: `if json is Array(array) { array.get(index) } else { None }`")
pub fn Json::item(self : Json, index : Int) -> Json? {
  if self is Array(arr) {
    arr.get(index)
  } else {
    None
  }
}

///|
/// Try to get this element as an Object
#deprecated
pub fn Json::as_object(self : Json) -> Map[String, Json]? {
  guard self is Object(obj) else { return None }
  Some(obj)
}

///|
/// Try to get this element as a Json Object and get the element with the `key` as a Json Value
#deprecated("Suggestion: `if json is Object(obj) { obj.get(key) } else { None }`")
pub fn Json::value(self : Json, key : String) -> Json? {
  if self is Object(obj) {
    obj.get(key)
  } else {
    None
  }
}

///|
/// A Replacer provides a way to filter and transform JSON object properties during stringification.
/// 
/// Replacers contain a function that takes a property key and value, and returns:
/// - `Some(value)` to include the property in the output (possibly transformed)
/// - `None` to exclude the property from the output
/// 
/// Only applies to object properties, not array elements.
struct Replacer((String, Json) -> Json?)

///|
/// Create a new Replacer with a custom function.
/// 
/// The function receives `(key, value)` pairs and should return:
/// - `Some(transformed_value)` to include the property
/// - `None` to exclude the property
/// 
/// ## Example
/// 
/// ```mbt test
/// // Transform numbers and exclude sensitive fields
/// ignore(
///   @json.Replacer::new((key, value) => match key {
///     "password" | "secret" => None // exclude sensitive fields
///     _ =>
///       match value {
///         Number(n, ..) => Some(Json::number(n * 2.0)) // double all numbers
///         _ => Some(value) // keep other values as-is
///       }
///   }),
/// )
/// ```
pub fn Replacer::new(f : (String, Json) -> Json?) -> Replacer {
  Replacer(f)
}

///|
/// Create a Replacer that only keeps the specified property keys.
/// All other properties will be excluded from the output.
/// 
/// ## Example
/// 
/// ```mbt test
/// let replacer = @json.Replacer::keep(["name", "age", "email"])
/// let json : Json = {
///   "name": "Alice",
///   "age": 30.0,
///   "email": "alice@example.com",
///   "password": "secret",
/// }
/// ignore(json.stringify(replacer~)) // {"name":"Alice","age":30,"email":"alice@example.com"}
/// ```
pub fn Replacer::keep(array : ArrayView[StringView]) -> Replacer {
  Replacer((idx, value) => if array.contains(idx) { Some(value) } else { None })
}

///|
/// Create a Replacer that excludes the specified property keys.
/// All other properties will be included in the output.
/// 
/// ## Example
/// 
/// ```mbt test
/// let replacer = @json.Replacer::exclude(["password", "secret", "private"])
/// let json : Json = {
///   "name": "Alice",
///   "age": 30.0,
///   "password": "secret",
///   "email": "alice@example.com",
/// }
/// ignore(json.stringify(replacer~)) // {"name":"Alice","age":30,"email":"alice@example.com"}
/// ```
pub fn Replacer::exclude(array : ArrayView[StringView]) -> Replacer {
  Replacer((idx, value) => if array.contains(idx) { None } else { Some(value) })
}

// stringify implementation moved to stringify_ffi_js.mbt and stringify_nonjs.mbt

///|
/// Transform a JSON value by applying a replacer recursively to all object properties.
/// 
/// Unlike `stringify(replacer~)` which only affects the string output, `transform()` 
/// returns a new JSON value with properties filtered and transformed according to the replacer.
/// 
/// This is useful when you want to create a modified JSON structure that can be further 
/// processed, rather than just converting to a string.
/// 
/// ## Example
/// 
/// ```mbt test
/// let json : Json = {
///   "user": { "name": "Alice", "password": "secret", "age": 30.0 },
///   "id": 123.0,
/// }
///
/// // Remove sensitive data and double numeric values  
/// ignore(
///   json.transform(
///     @json.Replacer::new((key, value) => match key {
///       "password" => None // exclude password fields
///       _ =>
///         match value {
///           Number(n, ..) => Some(Json::number(n * 2.0)) // double numbers
///           _ => Some(value) // keep other values
///         }
///     }),
///   ),
/// )
/// // Result: { "user": { "name": "Alice", "age": 60 }, "id": 246 }
/// ```
/// 
/// ## Behavior
/// 
/// - Recursively applies the replacer to all nested objects
/// - Non-object values (arrays, strings, numbers, etc.) are returned unchanged
/// - The original JSON value is not modified; a new value is returned
pub fn Json::transform(self : Self, replacer : Replacer) -> Json {
  match self {
    Object(members) =>
      members
      .iterator()
      .filter_map(pair => {
        let (k, v) = pair
        if replacer(k, v) is Some(v2) {
          Some((k, v2.transform(replacer)))
        } else {
          None
        }
      })
      |> Map::from_iterator()
      |> Object
    Array(members) => Array(members.map(m => m.transform(replacer)))
    value => value
  }
}

///|
/// Useful for json interpolation
pub impl ToJson for Json with to_json(self) {
  self
}

///|
#callsite(autofill(args_loc, loc))
pub fn inspect(
  obj : &ToJson,
  content? : Json,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise InspectError {
  let loc = loc.to_json_string()
  let args_loc = args_loc.to_json()
  let actual = obj.to_json().stringify(escape_slash=false)
  let want = match content {
    None => "".to_json().stringify(escape_slash=false)
    Some(x) => x.stringify(escape_slash=false)
  }
  if actual != want {
    raise InspectError(
      "@EXPECT_FAILED {\"loc\": \{loc}, \"args_loc\": \{args_loc}, \"expect\": \{want.escape()}, \"actual\": \{actual.escape()}, \"mode\": \"json\"}",
    )
  }
}
