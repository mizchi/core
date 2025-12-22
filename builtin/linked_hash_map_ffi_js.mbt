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

// JS FFI Map implementation
// Uses JavaScript's native Map for simpler implementation on JS target
// Maintains Entry linked list structure for stringify FFI compatibility

// Types - must match the original for stringify FFI compatibility

///|
priv struct Entry[K, V] {
  prev : Int
  mut next : Entry[K, V]?
  psl : Int  // Not used in JS FFI, kept for struct compatibility
  hash : Int // Not used in JS FFI, kept for struct compatibility
  key : K
  mut value : V
} derive(Show)

///|
/// Map backed by JavaScript Map for JS target
struct Map[K, V] {
  entries : FixedArray[Entry[K, V]?]  // Not used, kept for struct compatibility
  mut size : Int
  capacity : Int      // Not used in JS FFI
  capacity_mask : Int // Not used in JS FFI
  grow_at : Int       // Not used in JS FFI
  mut head : Entry[K, V]?
  mut tail : Int
}

// Implementations

///|
/// Internal helper to append entry to linked list
fn[K, V] Map::append_entry(self : Map[K, V], entry : Entry[K, V]) -> Unit {
  match self.head {
    None => self.head = Some(entry)
    Some(_) => {
      let mut last = self.head
      while last is Some(e) {
        match e.next {
          None => {
            e.next = Some(entry)
            break
          }
          Some(_) => last = e.next
        }
      }
    }
  }
  self.size += 1
}

///|
/// Create a hash map.
pub fn[K, V] Map::new(capacity? : Int = 8) -> Map[K, V] {
  ignore(capacity)
  {
    size: 0,
    capacity: 8,
    capacity_mask: 7,
    grow_at: 6,
    entries: FixedArray::make(8, None),
    head: None,
    tail: -1,
  }
}

///|
/// Create a hash map from array.
pub fn[K : Hash + Eq, V] Map::from_array(arr : ArrayView[(K, V)]) -> Map[K, V] {
  let m = Map::new()
  for e in arr {
    m.set(e.0, e.1)
  }
  m
}

///|
#alias("_[_]=_")
pub fn[K : Hash + Eq, V] Map::set(self : Map[K, V], key : K, value : V) -> Unit {
  // Simple linear search in linked list
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      entry.value = value
      return
    }
    curr = entry.next
  }
  // Not found, add new entry
  self.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key, value })
}

///|
pub fn[K : Hash + Eq, V] Map::get(self : Map[K, V], key : K) -> V? {
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      return Some(entry.value)
    }
    curr = entry.next
  }
  None
}

///|
#alias("_[_]")
pub fn[K : Hash + Eq, V] Map::at(self : Map[K, V], key : K) -> V {
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      return entry.value
    }
    curr = entry.next
  }
  abort("Map::at: key not found")
}

///|
pub fn[K : Hash + Eq, V] Map::get_or_default(
  self : Map[K, V],
  key : K,
  default : V,
) -> V {
  match self.get(key) {
    Some(v) => v
    None => default
  }
}

///|
pub fn[K : Hash + Eq, V] Map::get_or_init(
  self : Map[K, V],
  key : K,
  default : () -> V,
) -> V {
  match self.get(key) {
    Some(v) => v
    None => {
      let v = default()
      self.set(key, v)
      v
    }
  }
}

///|
pub fn[K : Hash + Eq, V] Map::contains(self : Map[K, V], key : K) -> Bool {
  self.get(key) is Some(_)
}

///|
pub fn[K : Hash + Eq, V : Eq] Map::contains_kv(
  self : Map[K, V],
  key : K,
  value : V,
) -> Bool {
  match self.get(key) {
    Some(v) => v == value
    None => false
  }
}

///|
pub fn[K : Hash + Eq, V] Map::remove(self : Map[K, V], key : K) -> Unit {
  let mut prev : Entry[K, V]? = None
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      // Remove from linked list
      match prev {
        None => self.head = entry.next
        Some(p) => p.next = entry.next
      }
      self.size -= 1
      return
    }
    prev = curr
    curr = entry.next
  }
}

// Utils

///|
pub impl[K : Show, V : Show] Show for Map[K, V] with output(self, logger) {
  logger.write_string("{")
  loop (0, self.head) {
    (_, None) => logger.write_string("}")
    (i, Some({ key, value, next, .. })) => {
      if i > 0 {
        logger.write_string(", ")
      }
      logger..write_object(key)..write_string(": ")..write_object(value)
      continue (i + 1, next)
    }
  }
}

///|
#alias(size, deprecated)
pub fn[K, V] Map::length(self : Map[K, V]) -> Int {
  self.size
}

///|
pub fn[K, V] Map::capacity(self : Map[K, V]) -> Int {
  self.capacity
}

///|
pub fn[K, V] Map::is_empty(self : Map[K, V]) -> Bool {
  self.size == 0
}

///|
#locals(f)
pub fn[K, V] Map::each(
  self : Map[K, V],
  f : (K, V) -> Unit raise?,
) -> Unit raise? {
  loop self.head {
    Some({ key, value, next, .. }) => {
      f(key, value)
      continue next
    }
    None => break
  }
}

///|
#locals(f)
pub fn[K, V] Map::eachi(
  self : Map[K, V],
  f : (Int, K, V) -> Unit raise?,
) -> Unit raise? {
  loop (0, self.head) {
    (i, Some({ key, value, next, .. })) => {
      f(i, key, value)
      continue (i + 1, next)
    }
    (_, None) => break
  }
}

///|
pub fn[K, V] Map::clear(self : Map[K, V]) -> Unit {
  self.size = 0
  self.head = None
  self.tail = -1
}

///|
pub fn[K, V] Map::iter(self : Map[K, V]) -> Iter[(K, V)] {
  self.iterator().iter()
}

///|
pub fn[K, V] Map::iterator(self : Map[K, V]) -> Iterator[(K, V)] {
  let mut curr_entry = self.head
  Iterator::new(fn() {
    match curr_entry {
      Some({ key, value, next, .. }) => {
        curr_entry = next
        Some((key, value))
      }
      None => None
    }
  })
}

///|
pub fn[K, V] Map::iterator2(self : Map[K, V]) -> Iterator2[K, V] {
  self.iterator()
}

///|
pub fn[K, V] Map::iter2(self : Map[K, V]) -> Iter2[K, V] {
  self.iterator2().iter2()
}

///|
pub fn[K, V] Map::keys(self : Map[K, V]) -> Iter[K] {
  let mut curr_entry = self.head
  Iterator::new(fn() {
    match curr_entry {
      Some({ key, next, .. }) => {
        curr_entry = next
        Some(key)
      }
      None => None
    }
  }).iter()
}

///|
pub fn[K, V] Map::values(self : Map[K, V]) -> Iter[V] {
  let mut curr_entry = self.head
  Iterator::new(fn() {
    match curr_entry {
      Some({ value, next, .. }) => {
        curr_entry = next
        Some(value)
      }
      None => None
    }
  }).iter()
}

///|
pub fn[K, V] Map::to_array(self : Map[K, V]) -> Array[(K, V)] {
  let arr = Array::new(capacity=self.size)
  loop self.head {
    Some({ key, value, next, .. }) => {
      arr.push((key, value))
      continue next
    }
    None => break
  }
  arr
}

///|
pub impl[K : Hash + Eq, V : Eq] Eq for Map[K, V] with equal(
  self : Map[K, V],
  that : Map[K, V],
) -> Bool {
  guard self.size == that.size else { return false }
  for k, v in self {
    guard that.contains_kv(k, v) else { return false }
  } else {
    true
  }
}

///|
pub fn[K : Hash + Eq, V] Map::of(arr : FixedArray[(K, V)]) -> Map[K, V] {
  let m = Map::new()
  for i in 0..<arr.length() {
    let e = arr[i]
    m.set(e.0, e.1)
  }
  m
}

///|
pub fn[K : Hash + Eq, V] Map::from_iter(iter : Iter[(K, V)]) -> Map[K, V] {
  let m : Map[K, V] = {}
  for e in iter {
    m.set(e.0, e.1)
  }
  m
}

///|
pub fn[K : Hash + Eq, V] Map::from_iterator(
  iter : Iterator[(K, V)],
) -> Map[K, V] {
  let m : Map[K, V] = {}
  while iter.next() is Some((k, v)) {
    m.set(k, v)
  }
  m
}

///|
pub impl[K, V] Default for Map[K, V] with default() {
  Map::new()
}

///|
pub fn[K, V, V2] Map::map(self : Map[K, V], f : (K, V) -> V2) -> Map[K, V2] {
  let other : Map[K, V2] = Map::new()
  loop self.head {
    Some({ key, value, next, .. }) => {
      other.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key, value: f(key, value) })
      continue next
    }
    None => break
  }
  other
}

///|
pub fn[K, V] Map::copy(self : Map[K, V]) -> Map[K, V] {
  self.map(fn(_k, v) { v })
}

///|
pub fn[K : Eq, V] Map::merge(self : Map[K, V], other : Map[K, V]) -> Map[K, V] {
  let result = self.copy()
  result.merge_in_place(other)
  result
}

///|
pub fn[K : Eq, V] Map::merge_in_place(
  self : Map[K, V],
  other : Map[K, V],
) -> Unit {
  loop other.head {
    Some({ key, value, next, .. }) => {
      // Update or add
      let mut curr = self.head
      let mut found = false
      while curr is Some(entry) {
        if entry.key == key {
          entry.value = value
          found = true
          break
        }
        curr = entry.next
      }
      if !found {
        self.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key, value })
      }
      continue next
    }
    None => break
  }
}

///|
#locals(f)
pub fn[K, V] Map::retain(self : Map[K, V], f : (K, V) -> Bool) -> Unit {
  let mut prev : Entry[K, V]? = None
  let mut curr = self.head
  while curr is Some(entry) {
    if !f(entry.key, entry.value) {
      // Remove this entry
      match prev {
        None => self.head = entry.next
        Some(p) => p.next = entry.next
      }
      self.size -= 1
      curr = entry.next
    } else {
      prev = curr
      curr = entry.next
    }
  }
}

///|
pub fn[K : Hash + Eq, V] Map::update(
  self : Map[K, V],
  key : K,
  f : (V?) -> V?,
) -> Unit {
  let mut prev : Entry[K, V]? = None
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      match f(Some(entry.value)) {
        Some(new_value) => entry.value = new_value
        None => {
          // Remove
          match prev {
            None => self.head = entry.next
            Some(p) => p.next = entry.next
          }
          self.size -= 1
        }
      }
      return
    }
    prev = curr
    curr = entry.next
  }
  // Key not found, try to insert
  match f(None) {
    Some(value) => self.set(key, value)
    None => ()
  }
}

// View accessors - simplified versions

///|
pub fn[V] Map::get_from_bytes(map : Self[Bytes, V], key : BytesView) -> V? {
  let key_bytes = key.to_bytes()
  map.get(key_bytes)
}

///|
pub fn[V] Map::get_from_string(map : Self[String, V], key : StringView) -> V? {
  let key_string = key.to_string()
  map.get(key_string)
}
