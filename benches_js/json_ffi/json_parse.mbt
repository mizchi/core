// JS FFI JSON parse implementation
// Uses native JSON.parse and converts to MoonBit Json type

// Note: MoonBit enum representation in JS:
// - Null, True, False: { $tag: 0/1/2 }
// - Number, String, Array, Object: constructor with prototype.$tag and _0, _1 fields

// Result type for parse
///|
type JSParseResult

///|
extern "js" fn js_parse_result_ok(result : JSParseResult) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn js_parse_result_value(result : JSParseResult) -> Json =
  #| (result) => result.value

// JS intermediate type for object entries
///|
type JSObjectEntries

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
  #|   // Create constructors matching MoonBit's enum representation
  #|   function JsonNumber(n, repr) { this._0 = n; this._1 = repr; }
  #|   JsonNumber.prototype.$tag = 3;
  #|   function JsonString(s) { this._0 = s; }
  #|   JsonString.prototype.$tag = 4;
  #|   function JsonArray(arr) { this._0 = arr; }
  #|   JsonArray.prototype.$tag = 5;
  #|   // For objects, we use a special marker to convert to Map later
  #|   function JsonObjectEntries(entries) { this._0 = entries; }
  #|   JsonObjectEntries.prototype.$tag = 6;
  #|
  #|   try {
  #|     const convert = (v) => {
  #|       if (v === null) return { $tag: 0 }; // Null
  #|       if (v === true) return { $tag: 1 }; // True
  #|       if (v === false) return { $tag: 2 }; // False
  #|       if (typeof v === "number") return new JsonNumber(v, undefined); // Number
  #|       if (typeof v === "string") return new JsonString(v); // String
  #|       if (Array.isArray(v)) return new JsonArray(v.map(convert)); // Array
  #|       // Object - return entries array for later conversion
  #|       const entries = Object.entries(v).map(([k, val]) => [k, convert(val)]);
  #|       return new JsonObjectEntries(entries);
  #|     };
  #|     return { ok: true, value: convert(JSON.parse(s)) };
  #|   } catch (e) {
  #|     return { ok: false };
  #|   }
  #| }

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
extern "js" fn js_is_object_entries(json : Json) -> Bool =
  #| (json) => json.$tag === 6 && Array.isArray(json._0)

///|
extern "js" fn js_get_object_entries(json : Json) -> JSObjectEntries =
  #| (json) => json._0

///|
fn convert_json_internal(json : Json) -> Json {
  // Check if this is an ObjectEntries placeholder
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
pub fn parse_ffi(input : String) -> Json? {
  let result = js_json_parse_raw(input)
  if js_parse_result_ok(result) {
    Some(convert_json_internal(js_parse_result_value(result)))
  } else {
    None
  }
}

///|
extern "js" fn js_json_stringify_impl(json : Json) -> String =
  #| (json) => {
  #|   const convert = (v) => {
  #|     switch (v.$tag) {
  #|       case 0: return null; // Null
  #|       case 1: return true; // True
  #|       case 2: return false; // False
  #|       case 3: return v._0; // Number
  #|       case 4: return v._0; // String
  #|       case 5: return v._0.map(convert); // Array
  #|       case 6: { // Object (MoonBit Map)
  #|         const obj = {};
  #|         // MoonBit Map has entries as FixedArray, iterate via head/next
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
  #|   return JSON.stringify(convert(json));
  #| }

///|
pub fn stringify_ffi(json : Json) -> String {
  js_json_stringify_impl(json)
}
