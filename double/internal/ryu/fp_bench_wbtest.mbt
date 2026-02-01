// Copyright 2026 International Digital Economy Academy
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

// Benchmark for fp-based string conversion

///|
test "fp_to_string_small_integers" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0, 12.0, 123.0, 1234.0, 12345.0, 123456.0, 1234567.0, 
    12345678.0, 123456789.0, 1234567890.0
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_decimals" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.234, 1.23456, 1.2345678, 1.23456789, 1.2345678901,
    3.1415926, 2.718281828, 0.000001, 0.0000001, 0.999999999
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_scientific" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0e10, 1.0e20, 1.0e30, 1.0e100, 1.0e200, 1.0e300,
    1.0e-10, 1.0e-20, 1.0e-30, 1.0e-100, 1.0e-200, 1.0e-300,
    1.23456789e50, 9.87654321e-50
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_edge_cases" (b : @bench.T) {
  let values : FixedArray[Double] = [
    0.0, -0.0, 1.0 / 0.0, -1.0 / 0.0, 0.0 / 0.0,
    5.0e-324, 1.7976931348623157e308, 2.2250738585072014e308
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_mixed" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0, 1.2, 1.23, 1.234, 1.2345, 1.23456, 1.234567,
    1.0e5, 1.0e10, 1.0e15, 1.0e20, 1.0e100,
    0.1, 0.01, 0.001, 0.0001, 0.00001,
    3.141592653589793, 2.718281828459045, 1.4142135623730951,
    123456789012345.0, 0.123456789012345
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_powers_of_2" (b : @bench.T) {
  let values : FixedArray[Double] = [
    2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0,
    2048.0, 4096.0, 8192.0, 16384.0, 32768.0, 65536.0,
    0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_powers_of_10" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0e0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9,
    1.0e-1, 1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5, 1.0e-6, 1.0e-7, 1.0e-8, 1.0e-9,
    1.0e10, 1.0e20, 1.0e30, 1.0e40, 1.0e50, 1.0e60, 1.0e70, 1.0e80, 1.0e90, 1.0e100
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

///|
test "fp_to_string_random_like" (b : @bench.T) {
  // Simulating "random" values that exercise different code paths
  let values : FixedArray[Double] = [
    1.2345678901234567e0, 1.2345678901234567e10,
    1.2345678901234567e20, 1.2345678901234567e30,
    1.2345678901234567e-10, 1.2345678901234567e-20,
    1.2345678901234567e-30, 1.2345678901234567e-100,
    9.999999999999999e99, 1.000000000000001e-99,
    5.555555555555555e50, 4.444444444444444e-50,
    3.333333333333333e150, 6.666666666666666e-150
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string(value))
      }
    }
  })
}

// ============================================================================
// Original Ryu Implementation Benchmarks (for comparison)
// ============================================================================

///|
test "ryu_to_string_small_integers" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0, 12.0, 123.0, 1234.0, 12345.0, 123456.0, 1234567.0, 
    12345678.0, 123456789.0, 1234567890.0
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_decimals" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.234, 1.23456, 1.2345678, 1.23456789, 1.2345678901,
    3.1415926, 2.718281828, 0.000001, 0.0000001, 0.999999999
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_scientific" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0e10, 1.0e20, 1.0e30, 1.0e100, 1.0e200, 1.0e300,
    1.0e-10, 1.0e-20, 1.0e-30, 1.0e-100, 1.0e-200, 1.0e-300,
    1.23456789e50, 9.87654321e-50
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_edge_cases" (b : @bench.T) {
  let values : FixedArray[Double] = [
    0.0, -0.0, 1.0 / 0.0, -1.0 / 0.0, 0.0 / 0.0,
    5.0e-324, 1.7976931348623157e308, 2.2250738585072014e308
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_mixed" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0, 1.2, 1.23, 1.234, 1.2345, 1.23456, 1.234567,
    1.0e5, 1.0e10, 1.0e15, 1.0e20, 1.0e100,
    0.1, 0.01, 0.001, 0.0001, 0.00001,
    3.141592653589793, 2.718281828459045, 1.4142135623730951,
    123456789012345.0, 0.123456789012345
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_powers_of_2" (b : @bench.T) {
  let values : FixedArray[Double] = [
    2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0,
    2048.0, 4096.0, 8192.0, 16384.0, 32768.0, 65536.0,
    0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_powers_of_10" (b : @bench.T) {
  let values : FixedArray[Double] = [
    1.0e0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9,
    1.0e-1, 1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5, 1.0e-6, 1.0e-7, 1.0e-8, 1.0e-9,
    1.0e10, 1.0e20, 1.0e30, 1.0e40, 1.0e50, 1.0e60, 1.0e70, 1.0e80, 1.0e90, 1.0e100
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}

///|
test "ryu_to_string_random_like" (b : @bench.T) {
  // Simulating "random" values that exercise different code paths
  let values : FixedArray[Double] = [
    1.2345678901234567e0, 1.2345678901234567e10,
    1.2345678901234567e20, 1.2345678901234567e30,
    1.2345678901234567e-10, 1.2345678901234567e-20,
    1.2345678901234567e-30, 1.2345678901234567e-100,
    9.999999999999999e99, 1.000000000000001e-99,
    5.555555555555555e50, 4.444444444444444e-50,
    3.333333333333333e150, 6.666666666666666e-150
  ]
  b.bench(fn () {
    for _ in 0..<1000 {
      for value in values {
        ignore(ryu_to_string_ryu(value))
      }
    }
  })
}
