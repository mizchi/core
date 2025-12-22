// Benchmark for Array operations

///|
/// Benchmark Array creation
test "bench_array_create" (b : @bench.T) {
  b.bench(
    name="array_make_1000",
    fn() {
      b.keep(Array::make(1000, 0))
    },
  )
  b.bench(
    name="array_makei_1000",
    fn() {
      b.keep(Array::makei(1000, fn(i) { i }))
    },
  )
}

///|
/// Benchmark Array push
test "bench_array_push" (b : @bench.T) {
  b.bench(
    name="array_push_1000",
    fn() {
      let arr : Array[Int] = []
      for i in 0..<1000 {
        arr.push(i)
      }
      b.keep(arr)
    },
  )
}

///|
/// Benchmark Array access
test "bench_array_access" (b : @bench.T) {
  let arr = Array::makei(1000, fn(i) { i })
  b.bench(
    name="array_get_1000",
    fn() {
      let mut sum = 0
      for i in 0..<1000 {
        sum += arr[i]
      }
      b.keep(sum)
    },
  )
}

///|
/// Benchmark Array iteration
test "bench_array_iter" (b : @bench.T) {
  let arr = Array::makei(1000, fn(i) { i })
  b.bench(
    name="array_foreach_1000",
    fn() {
      let mut sum = 0
      arr.each(fn(x) { sum += x })
      b.keep(sum)
    },
  )
  b.bench(
    name="array_for_in_1000",
    fn() {
      let mut sum = 0
      for x in arr {
        sum += x
      }
      b.keep(sum)
    },
  )
}

///|
/// Benchmark Array map
test "bench_array_map" (b : @bench.T) {
  let arr = Array::makei(1000, fn(i) { i })
  b.bench(
    name="array_map_1000",
    fn() {
      b.keep(arr.map(fn(x) { x * 2 }))
    },
  )
}

///|
/// Benchmark Array filter
test "bench_array_filter" (b : @bench.T) {
  let arr = Array::makei(1000, fn(i) { i })
  b.bench(
    name="array_filter_1000",
    fn() {
      b.keep(arr.filter(fn(x) { x % 2 == 0 }))
    },
  )
}

///|
/// Benchmark Array sort
test "bench_array_sort" (b : @bench.T) {
  b.bench(
    name="array_sort_1000",
    fn() {
      let arr = Array::makei(1000, fn(i) { 999 - i })
      arr.sort()
      b.keep(arr)
    },
  )
}
