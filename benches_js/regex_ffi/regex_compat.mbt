// JS FFI RegExp implementation with API compatible with string/regex
// This provides the same interface as @regexp but uses native JS RegExp

// ================================
// Types
// ================================

///|
struct Regexp {
  inner : JSRegExp
}

///|
struct MatchResult {
  captures : Array[String?]
  names : Map[String, Int]
  before_str : String
  after_str : String
}

// ================================
// JS FFI functions
// ================================

///|
extern "js" fn js_regexp_new_u(pattern : String, flags : String) -> JSRegExp =
  #| (pattern, flags) => new RegExp(pattern, flags + 'u')

///|
extern "js" fn js_regexp_exec_captures(re : JSRegExp, input : String) -> Array[String?] =
  #| (re, input) => {
  #|   const m = re.exec(input);
  #|   if (!m) return [];
  #|   return Array.from(m).map(x => x === undefined ? null : x);
  #| }

///|
extern "js" fn js_regexp_exec_index_impl(re : JSRegExp, input : String) -> Int =
  #| (re, input) => {
  #|   const m = re.exec(input);
  #|   return m ? m.index : -1;
  #| }

///|
extern "js" fn js_regexp_get_group_names(re : JSRegExp) -> Array[String] =
  #| (re) => {
  #|   // Extract named groups from regex source
  #|   const names = [];
  #|   const src = re.source;
  #|   const regex = /\(\?<([^>]+)>/g;
  #|   let m;
  #|   while ((m = regex.exec(src)) !== null) {
  #|     names.push(m[1]);
  #|   }
  #|   return names;
  #| }

///|
extern "js" fn js_string_substring(s : String, start : Int, end : Int) -> String =
  #| (s, start, end) => s.substring(start, end)

///|
extern "js" fn js_string_length(s : String) -> Int =
  #| (s) => s.length

// ================================
// Regexp API
// ================================

///|
fn convert_pattern(pattern : String) -> String {
  // Convert MoonBit regex syntax to JS regex syntax
  // \p{Letter} -> \p{L}, \p{Number} -> \p{N}, etc.
  pattern
    .replace(old="\\p{Letter}", new="\\p{L}")
    .replace(old="\\p{Number}", new="\\p{N}")
    .replace(old="\\p{Separator}", new="\\p{Z}")
    .replace(old="\\P{Letter}", new="\\P{L}")
    .replace(old="\\P{Number}", new="\\P{N}")
    .replace(old="\\P{Separator}", new="\\P{Z}")
}

///|
fn convert_flags(flags : String) -> String {
  // Convert MoonBit flags to JS flags
  // m -> m (multiline)
  // s -> s (dotall)
  // i -> i (case insensitive)
  flags
}

///|
pub fn compile(pattern : String, flags~ : String = "") -> Regexp {
  let js_pattern = convert_pattern(pattern)
  let js_flags = convert_flags(flags)
  { inner: js_regexp_new_u(js_pattern, js_flags) }
}

///|
pub fn Regexp::execute(self : Regexp, input : String) -> MatchResult {
  let captures = js_regexp_exec_captures(self.inner, input)
  let index = js_regexp_exec_index_impl(self.inner, input)
  let group_names = js_regexp_get_group_names(self.inner)
  let names : Map[String, Int] = {}
  for i, name in group_names {
    names[name] = i + 1
  }
  let (before, after) = if captures.is_empty() || index < 0 {
    (input, "")
  } else {
    let match_len = match captures[0] {
      Some(m) => js_string_length(m)
      None => 0
    }
    let input_len = js_string_length(input)
    (
      js_string_substring(input, 0, index),
      js_string_substring(input, index + match_len, input_len),
    )
  }
  { captures, names, before_str: before, after_str: after }
}

///|
pub fn Regexp::match_(self : Regexp, input : String) -> MatchResult? {
  let result = self.execute(input)
  if result.matched() {
    Some(result)
  } else {
    None
  }
}

///|
pub fn Regexp::group_by_name(self : Regexp, name : String) -> Int? {
  let group_names = js_regexp_get_group_names(self.inner)
  for i, n in group_names {
    if n == name {
      return Some(i + 1)
    }
  }
  None
}

///|
pub fn Regexp::group_count(self : Regexp) -> Int {
  let group_names = js_regexp_get_group_names(self.inner)
  group_names.length() + 1
}

///|
pub fn Regexp::group_names(self : Regexp) -> Array[String] {
  js_regexp_get_group_names(self.inner)
}

// ================================
// MatchResult API
// ================================

///|
pub fn MatchResult::matched(self : MatchResult) -> Bool {
  not(self.captures.is_empty())
}

///|
pub fn MatchResult::get(self : MatchResult, index : Int) -> String? {
  if index < 0 || index >= self.captures.length() {
    return None
  }
  self.captures[index]
}

///|
pub fn MatchResult::results(self : MatchResult) -> Array[String?] {
  self.captures
}

///|
pub fn MatchResult::groups(self : MatchResult) -> Map[String, String] {
  let result : Map[String, String] = {}
  for name, index in self.names {
    if self.get(index) is Some(value) {
      result[name] = value
    }
  }
  result
}

///|
pub fn MatchResult::before(self : MatchResult) -> String {
  self.before_str
}

///|
pub fn MatchResult::after(self : MatchResult) -> String {
  self.after_str
}
