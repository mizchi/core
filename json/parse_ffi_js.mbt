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

// JS FFI JSON parse/stringify implementation
// Uses native JSON.parse/JSON.stringify for smaller bundle size

///|
priv type JSParseResult

///|
extern "js" fn js_parse_result_ok(result : JSParseResult) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn js_parse_result_value(result : JSParseResult) -> Json =
  #| (result) => result.value

///|
extern "js" fn js_parse_result_error(result : JSParseResult) -> String =
  #| (result) => result.error || ""

///|
priv type JSObjectEntries

///|
extern "js" fn js_object_entries_length(entries : JSObjectEntries) -> Int =
  #| (entries) => entries.length

///|
extern "js" fn js_object_entries_key(entries : JSObjectEntries, index : Int) -> String =
  #| (entries, i) => entries[i][0]

///|
extern "js" fn js_object_entries_value(entries : JSObjectEntries, index : Int) -> Json =
  #| (entries, i) => entries[i][1]

///|
extern "js" fn js_json_parse_raw(input : String) -> JSParseResult =
  #| (s) => {
  #|   function JsonNumber(n, repr) { this._0 = n; this._1 = repr; }
  #|   JsonNumber.prototype.$tag = 3;
  #|   function JsonString(s) { this._0 = s; }
  #|   JsonString.prototype.$tag = 4;
  #|   function JsonArray(arr) { this._0 = arr; }
  #|   JsonArray.prototype.$tag = 5;
  #|   function JsonObjectEntries(entries) { this._0 = entries; }
  #|   JsonObjectEntries.prototype.$tag = 6;
  #|   try {
  #|     const convert = (v) => {
  #|       if (v === null) return { $tag: 0 };
  #|       if (v === true) return { $tag: 1 };
  #|       if (v === false) return { $tag: 2 };
  #|       if (typeof v === "number") return new JsonNumber(v, undefined);
  #|       if (typeof v === "string") return new JsonString(v);
  #|       if (Array.isArray(v)) return new JsonArray(v.map(convert));
  #|       const entries = Object.entries(v).map(([k, val]) => [k, convert(val)]);
  #|       return new JsonObjectEntries(entries);
  #|     };
  #|     return { ok: true, value: convert(JSON.parse(s)) };
  #|   } catch (e) {
  #|     return { ok: false, error: e.message };
  #|   }
  #| }

///|
extern "js" fn js_is_object_entries(json : Json) -> Bool =
  #| (json) => json.$tag === 6 && Array.isArray(json._0)

///|
extern "js" fn js_get_object_entries(json : Json) -> JSObjectEntries =
  #| (json) => json._0

///|
fn convert_object_entries(entries : JSObjectEntries) -> Map[String, Json] {
  let map : Map[String, Json] = {}
  let len = js_object_entries_length(entries)
  for i in 0..<len {
    let key = js_object_entries_key(entries, i)
    let value = convert_json_internal(js_object_entries_value(entries, i))
    map[key] = value
  }
  map
}

///|
fn convert_json_internal(json : Json) -> Json {
  if js_is_object_entries(json) {
    let entries = js_get_object_entries(json)
    Json::object(convert_object_entries(entries))
  } else {
    match json {
      Array(arr) => {
        let new_arr : Array[Json] = []
        for i in 0..<arr.length() {
          new_arr.push(convert_json_internal(arr[i]))
        }
        Json::array(new_arr)
      }
      _ => json
    }
  }
}

///|
pub fn valid(input : StringView) -> Bool {
  let result = js_json_parse_raw(input.to_string())
  js_parse_result_ok(result)
}

///|
#label_migration(max_nesting_depth, fill=false)
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  ignore(max_nesting_depth) // Not used in JS FFI version
  let result = js_json_parse_raw(input.to_string())
  if js_parse_result_ok(result) {
    convert_json_internal(js_parse_result_value(result))
  } else {
    let error_msg = js_parse_result_error(result)
    raise InvalidChar(
      { line: 1, column: 0 },
      if error_msg.length() > 0 {
        error_msg[0].to_int().unsafe_to_char()
      } else {
        '?'
      },
    )
  }
}

// ============================================================================
// Stringify FFI Implementation
// ============================================================================

///|
extern "js" fn js_json_stringify(json : Json, indent : Int) -> String =
  #| (json, indent) => {
  #|   const convert = (v) => {
  #|     switch (v.$tag) {
  #|       case 0: return null;
  #|       case 1: return true;
  #|       case 2: return false;
  #|       case 3: return v._1 !== undefined ? '__REPR__:' + v._1 : v._0;
  #|       case 4: return v._0;
  #|       case 5: return v._0.map(convert);
  #|       case 6: {
  #|         const obj = {};
  #|         let entry = v._0.head;
  #|         while (entry) {
  #|           obj[entry.key] = convert(entry.value);
  #|           entry = entry.next;
  #|         }
  #|         return obj;
  #|       }
  #|       default: return null;
  #|     }
  #|   };
  #|   let result = JSON.stringify(convert(json), null, indent || undefined);
  #|   return result.replace(/"__REPR__:([^"]+)"/g, '$1');
  #| }

///|
extern "js" fn js_json_stringify_escape_slash(json : Json, indent : Int) -> String =
  #| (json, indent) => {
  #|   const convert = (v) => {
  #|     switch (v.$tag) {
  #|       case 0: return null;
  #|       case 1: return true;
  #|       case 2: return false;
  #|       case 3: return v._1 !== undefined ? '__REPR__:' + v._1 : v._0;
  #|       case 4: return v._0;
  #|       case 5: return v._0.map(convert);
  #|       case 6: {
  #|         const obj = {};
  #|         let entry = v._0.head;
  #|         while (entry) {
  #|           obj[entry.key] = convert(entry.value);
  #|           entry = entry.next;
  #|         }
  #|         return obj;
  #|       }
  #|       default: return null;
  #|     }
  #|   };
  #|   let result = JSON.stringify(convert(json), null, indent || undefined);
  #|   result = result.replace(/"__REPR__:([^"]+)"/g, '$1');
  #|   return result.replace(/\//g, '\\/');
  #| }
