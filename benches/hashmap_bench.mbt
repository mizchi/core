// Benchmark for HashMap operations

///|
/// Benchmark HashMap insertion
test "bench_hashmap_insert" (b : @bench.T) {
  b.bench(
    name="hashmap_insert_1000",
    fn() {
      let map : @hashmap.HashMap[Int, Int] = @hashmap.new()
      for i in 0..<1000 {
        map.set(i, i)
      }
      b.keep(map)
    },
  )
}

///|
/// Benchmark HashMap lookup
test "bench_hashmap_get" (b : @bench.T) {
  let map : @hashmap.HashMap[Int, Int] = @hashmap.new()
  for i in 0..<1000 {
    map.set(i, i)
  }
  b.bench(
    name="hashmap_get_1000",
    fn() {
      for i in 0..<1000 {
        b.keep(map.get(i))
      }
    },
  )
}

///|
/// Benchmark HashMap with String keys
test "bench_hashmap_string_keys" (b : @bench.T) {
  let keys = Array::makei(100, fn(i) { "key_\{i}" })
  b.bench(
    name="hashmap_string_insert_100",
    fn() {
      let map : @hashmap.HashMap[String, Int] = @hashmap.new()
      for i, key in keys {
        map.set(key, i)
      }
      b.keep(map)
    },
  )
}

///|
/// Benchmark sorted_map insertion for comparison
test "bench_sorted_map_insert" (b : @bench.T) {
  b.bench(
    name="sorted_map_insert_1000",
    fn() {
      let map : @sorted_map.SortedMap[Int, Int] = @sorted_map.new()
      for i in 0..<1000 {
        map.set(i, i)
      }
      b.keep(map)
    },
  )
}

///|
/// Benchmark sorted_map lookup for comparison
test "bench_sorted_map_get" (b : @bench.T) {
  let map : @sorted_map.SortedMap[Int, Int] = @sorted_map.new()
  for i in 0..<1000 {
    map.set(i, i)
  }
  b.bench(
    name="sorted_map_get_1000",
    fn() {
      for i in 0..<1000 {
        b.keep(map.get(i))
      }
    },
  )
}

///|
/// Benchmark immutable HashMap
test "bench_immut_hashmap_insert" (b : @bench.T) {
  b.bench(
    name="immut_hashmap_insert_1000",
    fn() {
      let mut map : @immut_hashmap.HashMap[Int, Int] = @immut_hashmap.new()
      for i in 0..<1000 {
        map = map.add(i, i)
      }
      b.keep(map)
    },
  )
}

///|
/// Benchmark immutable sorted_map
test "bench_immut_sorted_map_insert" (b : @bench.T) {
  b.bench(
    name="immut_sorted_map_insert_1000",
    fn() {
      let mut map : @immut_sorted_map.SortedMap[Int, Int] = @immut_sorted_map.new()
      for i in 0..<1000 {
        map = map.add(i, i)
      }
      b.keep(map)
    },
  )
}
