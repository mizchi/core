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

// JS FFI implementation of Regexp for JS backend
// This uses native JavaScript RegExp for better performance and smaller bundle size

///|
priv type JSRegExp

///|
priv type JSRegExpResult

///|
extern "js" fn js_regexp_try_new(
  pattern : String,
  flags : String
) -> JSRegExpResult =
  #| (pattern, flags) => {
  #|   try {
  #|     return { ok: true, regexp: new RegExp(pattern, flags + "u"), error: "" };
  #|   } catch (e) {
  #|     return { ok: false, regexp: null, error: e.message };
  #|   }
  #| }

///|
extern "js" fn js_regexp_result_is_ok(result : JSRegExpResult) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn js_regexp_result_get_regexp(result : JSRegExpResult) -> JSRegExp =
  #| (result) => result.regexp

///|
extern "js" fn js_regexp_result_get_error(result : JSRegExpResult) -> String =
  #| (result) => result.error

///|
extern "js" fn js_regexp_exec_captures(
  re : JSRegExp,
  input : String
) -> Array[String?] =
  #| (re, input) => {
  #|   const result = re.exec(input);
  #|   if (result === null) return [];
  #|   return Array.from(result, x => x === undefined ? null : x);
  #| }

///|
extern "js" fn js_regexp_exec_index(re : JSRegExp, input : String) -> Int =
  #| (re, input) => {
  #|   const result = re.exec(input);
  #|   return result === null ? -1 : result.index;
  #| }

///|
extern "js" fn js_regexp_get_group_names(re : JSRegExp) -> Array[String] =
  #| (re) => {
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
extern "js" fn js_string_length(s : String) -> Int =
  #| (s) => s.length

///|
extern "js" fn js_string_index_of(s : String, search : String) -> Int =
  #| (s, search) => s.indexOf(search)

///|
struct Regexp {
  inner : JSRegExp
  names : Map[String, Int]
  capture_count : Int
}

///|
fn convert_pattern(pattern : String) -> String {
  // Convert MoonBit regex syntax to JS regex syntax
  // \p{Letter} -> \p{L}, \p{Number} -> \p{N}, etc.
  pattern
    .replace(old="\\p{Letter}", new="\\p{L}")
    .replace(old="\\p{Number}", new="\\p{N}")
    .replace(old="\\p{Separator}", new="\\p{Z}")
    .replace(old="\\p{Symbol}", new="\\p{S}")
    .replace(old="\\p{Punctuation}", new="\\p{P}")
    .replace(old="\\p{Mark}", new="\\p{M}")
    .replace(old="\\p{Other}", new="\\p{C}")
    .replace(old="\\P{Letter}", new="\\P{L}")
    .replace(old="\\P{Number}", new="\\P{N}")
    .replace(old="\\P{Separator}", new="\\P{Z}")
    .replace(old="\\P{Symbol}", new="\\P{S}")
    .replace(old="\\P{Punctuation}", new="\\P{P}")
    .replace(old="\\P{Mark}", new="\\P{M}")
    .replace(old="\\P{Other}", new="\\P{C}")
}

///|
fn convert_flags(flags : StringView) -> String {
  let result = StringBuilder::new()
  for c in flags {
    match c {
      'i' | 'm' | 's' | 'g' => result.write_char(c)
      _ => ()
    }
  }
  result.to_string()
}

///|
fn count_capture_groups(pattern : String) -> Int {
  let mut count = 1 // Group 0 is the full match
  let mut i = 0
  let len = pattern.length()
  while i < len {
    let c = pattern[i].to_int().unsafe_to_char()
    if c == '\\' && i + 1 < len {
      i += 2 // Skip escaped character
    } else if c == '(' {
      if i + 1 < len && pattern[i + 1].to_int().unsafe_to_char() == '?' {
        if i + 2 < len && pattern[i + 2].to_int().unsafe_to_char() == ':' {
          // Non-capturing group (?:...)
          i += 1
        } else if i + 2 < len && pattern[i + 2].to_int().unsafe_to_char() == '<' {
          // Named group (?<name>...)
          count += 1
          i += 1
        } else {
          // Other special groups like (?i:...), (?=...), etc.
          i += 1
        }
      } else {
        // Regular capturing group
        count += 1
      }
      i += 1
    } else {
      i += 1
    }
  }
  count
}

///|
pub fn compile(
  regexp : StringView,
  flags? : StringView = ""
) -> Regexp raise @parse.RegexpError {
  let pattern_str = regexp.to_string()
  let js_pattern = convert_pattern(pattern_str)
  let js_flags = convert_flags(flags)
  let result = js_regexp_try_new(js_pattern, js_flags)
  let inner = if js_regexp_result_is_ok(result) {
    js_regexp_result_get_regexp(result)
  } else {
    raise @parse.create_regexp_error(js_regexp_result_get_error(result))
  }
  let group_names = js_regexp_get_group_names(inner)
  let names : Map[String, Int] = {}
  for i, name in group_names {
    names[name] = i + 1
  }
  let capture_count = count_capture_groups(pattern_str)
  { inner, names, capture_count }
}

///|
pub fn Regexp::group_by_name(self : Regexp, name : String) -> Int? {
  self.names.get(name)
}

///|
pub fn Regexp::group_count(self : Regexp) -> Int {
  self.capture_count
}

///|
pub fn Regexp::group_names(self : Regexp) -> Array[String] {
  self.names.keys().collect()
}

///|
struct MatchResult {
  input : StringView
  captures : Array[String?]
  names : Map[String, Int]
  before : StringView
  after : StringView
  index : Int
}

///|
pub fn Regexp::execute(self : Regexp, input : StringView) -> MatchResult {
  let input_str = input.to_string()
  let captures = js_regexp_exec_captures(self.inner, input_str)
  let index = js_regexp_exec_index(self.inner, input_str)
  let (before, after) = if captures.is_empty() || index < 0 {
    (input, input.view(start_offset=input.length()))
  } else {
    let match_len = match captures[0] {
      Some(m) => js_string_length(m)
      None => 0
    }
    (
      input.view(end_offset=index),
      input.view(start_offset=index + match_len),
    )
  }
  { input, captures, names: self.names, before, after, index }
}

///|
#deprecated("Use `Regexp::execute` and `MatchResult::before`/`after` instead.")
pub fn Regexp::execute_with_remainder(
  self : Regexp,
  input : StringView
) -> (MatchResult, StringView) {
  let result = self.execute(input)
  (result, result.after)
}

///|
pub fn Regexp::match_(self : Regexp, input : StringView) -> MatchResult? {
  let result = self.execute(input)
  if result.matched() {
    Some(result)
  } else {
    None
  }
}

///|
pub fn MatchResult::matched(self : MatchResult) -> Bool {
  not(self.captures.is_empty())
}

///|
pub fn MatchResult::get(self : MatchResult, index : Int) -> StringView? {
  if self.captures.is_empty() || index < 0 || index >= self.captures.length() {
    return None
  }
  match self.captures[index] {
    Some(s) => {
      // Find the position in input and return a view
      if index == 0 {
        // Full match - use index position
        Some(self.input.view(start_offset=self.index, end_offset=self.index + s.length()))
      } else {
        // For capture groups, we need to find them in the input
        let full_match = match self.captures[0] {
          Some(m) => m
          None => ""
        }
        // Try to find the capture within the full match
        let pos = js_string_index_of(full_match, s)
        if pos >= 0 {
          Some(self.input.view(start_offset=self.index + pos, end_offset=self.index + pos + s.length()))
        } else {
          // Fallback: return a view from the start of input with the matched content
          Some(self.input.view(start_offset=self.index, end_offset=self.index + s.length()))
        }
      }
    }
    None => None
  }
}

///|
pub fn MatchResult::groups(self : MatchResult) -> Map[String, StringView] {
  let result : Map[String, StringView] = {}
  for name, index in self.names {
    if self.get(index) is Some(content) {
      result[name] = content
    }
  }
  result
}

///|
pub fn MatchResult::results(self : MatchResult) -> Array[StringView?] {
  let results : Array[StringView?] = []
  for i, capture in self.captures {
    match capture {
      Some(_) => results.push(self.get(i))
      None => results.push(None)
    }
  }
  results
}

///|
pub fn MatchResult::before(self : MatchResult) -> StringView {
  self.before
}

///|
pub fn MatchResult::after(self : MatchResult) -> StringView {
  self.after
}
