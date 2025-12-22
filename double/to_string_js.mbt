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
/// Converts a floating-point number to its string representation.
/// Uses JavaScript's native Number.toString() for JS backend.
///
/// Example:
///
/// ```mbt test
/// inspect(42.0.to_string(), content="42")
/// inspect(3.14159.to_string(), content="3.14159")
/// inspect((-0.0).to_string(), content="0")
/// inspect(@double.not_a_number.to_string(), content="NaN")
/// ```
///
pub fn Double::to_string(self : Double) -> String {
  js_double_to_string(self)
}

///|
extern "js" fn js_double_to_string(d : Double) -> String =
  #| (x) => String(x)
