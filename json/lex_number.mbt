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
fn ParseContext::lex_decimal_integer(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  // Clear the side channel before starting a fresh number so a previous value
  // can never leak through if a later step raises before reaching
  // `lex_number_end` (the only writer).
  ctx.last_number_repr = None
  for {
    match ctx.read_char() {
      Some('.') => return ctx.lex_decimal_point(start~)
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_point(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some(c) =>
      if c >= '0' && c <= '9' {
        ctx.lex_decimal_fraction(start~)
      } else {
        ctx.invalid_char(shift=-1)
      }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_fraction(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  for {
    match ctx.read_char() {
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_exponent(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some('+') | Some('-') => return ctx.lex_decimal_exponent_sign(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.offset -= 1
      ctx.invalid_char()
    }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_exponent_sign(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.offset -= 1
      ctx.invalid_char()
    }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_exponent_integer(
  ctx : ParseContext,
  start~ : Int,
) -> Double {
  for {
    match ctx.read_char() {
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_zero(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  // See `lex_decimal_integer`: clear the side channel at the number entry point.
  ctx.last_number_repr = None
  match ctx.read_char() {
    Some('.') => ctx.lex_decimal_point(start~)
    Some('e' | 'E') => ctx.lex_decimal_exponent(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        ctx.offset -= 1
        ctx.invalid_char()
      }
      ctx.offset -= 1
      return ctx.lex_number_end(start, ctx.offset)
    }
    None => return ctx.lex_number_end(start, ctx.offset)
  }
}

///|
fn ParseContext::lex_number_end(
  ctx : ParseContext,
  start : Int,
  end : Int,
) -> Double {
  let s = ctx.input.view(start_offset=start, end_offset=end)
  if !s.contains(".") && !s.contains("e") && !s.contains("E") {
    // If the string does not contain a decimal point or exponent, it is likely an integer
    // We can try to parse it as an integer first
    let parsed_int = try? @strconv.parse_int64(s)
    match parsed_int {
      Ok(i) if i <= 9007199254740991 && i >= -9007199254740991 => {
        ctx.last_number_repr = None
        i.to_double()
      }
      // Outside the safe-integer range we cannot represent the value exactly,
      // so fall back to infinity and preserve the original string.
      _ => {
        ctx.last_number_repr = Some(s)
        if s is ['-', ..] {
          @double.neg_infinity
        } else {
          @double.infinity
        }
      }
    }
  } else {
    let parsed_double = try? @strconv.parse_double(s)
    match parsed_double {
      // For normal values, return without string representation
      Ok(d) => {
        ctx.last_number_repr = None
        d
      }
      // If parsing fails as a double, treat it as infinity and preserve the string
      Err(_) => {
        ctx.last_number_repr = Some(s)
        if s is ['-', ..] {
          @double.neg_infinity
        } else {
          @double.infinity
        }
      }
    }
  }
}
