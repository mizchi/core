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

// JS FFI Set implementation
// Uses simplified linked list for JS target
// Maintains Entry structure for iteration order compatibility

// Types - must match the original for compatibility

///|
priv struct Entry[K] {
  prev : Int
  mut next : Entry[K]?
  psl : Int  // Not used in JS FFI
  hash : Int // Not used in JS FFI
  key : K
} derive(Show)

///|
/// Set backed by linked list for JS target
struct Set[K] {
  entries : FixedArray[Entry[K]?]  // Not used, kept for struct compatibility
  mut size : Int
  capacity : Int
  capacity_mask : Int
  grow_at : Int
  mut head : Entry[K]?
  mut tail : Int
}

// Implementations

///|
/// Internal helper to append entry to linked list
fn[K] Set::append_entry(self : Set[K], entry : Entry[K]) -> Unit {
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
/// Create a hash set.
#as_free_fn
pub fn[K] Set::new(capacity? : Int = 8) -> Set[K] {
  let cap = capacity.next_power_of_two()
  {
    size: 0,
    capacity: cap,
    capacity_mask: cap - 1,
    grow_at: cap * 13 / 16,
    entries: FixedArray::make(cap, None),
    head: None,
    tail: -1,
  }
}

///|
/// Create a hash set from array.
#as_free_fn
#alias(of, deprecated="Use from_array instead")
#as_free_fn(of, deprecated="Use from_array instead")
pub fn[K : Hash + Eq] Set::from_array(arr : ArrayView[K]) -> Set[K] {
  let length = arr.length()
  let mut cap = length.next_power_of_two()
  if length > cap * 13 / 16 {
    cap *= 2
  }
  let m = Set::new(capacity=cap)
  for e in arr {
    m.add(e)
  }
  m
}

///|
/// Insert a key into the hash set.
#alias(insert, deprecated)
pub fn[K : Hash + Eq] Set::add(self : Set[K], key : K) -> Unit {
  // Simple linear search in linked list
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      return // Already exists
    }
    curr = entry.next
  }
  // Not found, add new entry
  self.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key })
}

///|
/// Insert a key and return whether it was added.
pub fn[K : Hash + Eq] Set::add_and_check(self : Set[K], key : K) -> Bool {
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      return false
    }
    curr = entry.next
  }
  self.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key })
  true
}

///|
/// Check if the hash set contains a key.
pub fn[K : Hash + Eq] Set::contains(self : Set[K], key : K) -> Bool {
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      return true
    }
    curr = entry.next
  }
  false
}

///|
/// Remove a key from the hash set.
pub fn[K : Hash + Eq] Set::remove(self : Set[K], key : K) -> Unit {
  let mut prev : Entry[K]? = None
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
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

///|
/// Remove a key and return whether it was removed.
pub fn[K : Hash + Eq] Set::remove_and_check(self : Set[K], key : K) -> Bool {
  let mut prev : Entry[K]? = None
  let mut curr = self.head
  while curr is Some(entry) {
    if entry.key == key {
      match prev {
        None => self.head = entry.next
        Some(p) => p.next = entry.next
      }
      self.size -= 1
      return true
    }
    prev = curr
    curr = entry.next
  }
  false
}

// Utils

///|
pub impl[K : Show] Show for Set[K] with output(self, logger) {
  logger.write_string("{")
  loop (0, self.head) {
    (_, None) => logger.write_string("}")
    (i, Some({ key, next, .. })) => {
      if i > 0 {
        logger.write_string(", ")
      }
      logger.write_object(key)
      continue (i + 1, next)
    }
  }
}

///|
#alias(size, deprecated)
pub fn[K] Set::length(self : Set[K]) -> Int {
  self.size
}

///|
pub fn[K] Set::capacity(self : Set[K]) -> Int {
  self.capacity
}

///|
pub fn[K] Set::is_empty(self : Set[K]) -> Bool {
  self.size == 0
}

///|
#locals(f)
pub fn[K] Set::each(self : Set[K], f : (K) -> Unit raise?) -> Unit raise? {
  loop self.head {
    Some({ key, next, .. }) => {
      f(key)
      continue next
    }
    None => break
  }
}

///|
#locals(f)
pub fn[K] Set::eachi(self : Set[K], f : (Int, K) -> Unit raise?) -> Unit raise? {
  loop (0, self.head) {
    (i, Some({ key, next, .. })) => {
      f(i, key)
      continue (i + 1, next)
    }
    (_, None) => break
  }
}

///|
pub fn[K] Set::clear(self : Set[K]) -> Unit {
  self.size = 0
  self.head = None
  self.tail = -1
}

///|
pub fn[K] Set::iter(self : Set[K]) -> Iter[K] {
  self.iterator().iter()
}

///|
pub fn[K] Set::iterator(self : Set[K]) -> Iterator[K] {
  let mut curr_entry = self.head
  Iterator::new(fn() {
    match curr_entry {
      Some({ key, next, .. }) => {
        curr_entry = next
        Some(key)
      }
      None => None
    }
  })
}

///|
pub fn[K] Set::to_array(self : Set[K]) -> Array[K] {
  let arr = Array::new(capacity=self.size)
  loop self.head {
    Some({ key, next, .. }) => {
      arr.push(key)
      continue next
    }
    None => break
  }
  arr
}

///|
pub impl[K : Hash + Eq] Eq for Set[K] with equal(self, other) {
  guard self.size == other.size else { return false }
  for k in self {
    guard other.contains(k) else { return false }
  } else {
    true
  }
}

///|
#as_free_fn
pub fn[K : Hash + Eq] Set::from_iter(iter : Iter[K]) -> Set[K] {
  let m = Set::new()
  for e in iter {
    m.add(e)
  }
  m
}

///|
#as_free_fn
pub fn[K : Hash + Eq] Set::from_iterator(iter : Iterator[K]) -> Set[K] {
  let m = Set::new()
  while iter.next() is Some(e) {
    m.add(e)
  }
  m
}

///|
pub impl[K] Default for Set[K] with default() {
  Set::new()
}

///|
pub fn[K] Set::copy(self : Set[K]) -> Set[K] {
  let other : Set[K] = Set::new(capacity=self.capacity)
  loop self.head {
    Some({ key, next, .. }) => {
      other.append_entry({ prev: -1, next: None, psl: 0, hash: 0, key })
      continue next
    }
    None => break
  }
  other
}

///|
pub fn[K : Hash + Eq] Set::difference(self : Set[K], other : Set[K]) -> Set[K] {
  let m = Set::new()
  self.each(fn(k) { if !other.contains(k) { m.add(k) } })
  m
}

///|
pub fn[K : Hash + Eq] Set::symmetric_difference(
  self : Set[K],
  other : Set[K],
) -> Set[K] {
  let m = Set::new()
  self.each(fn(k) { if !other.contains(k) { m.add(k) } })
  other.each(fn(k) { if !self.contains(k) { m.add(k) } })
  m
}

///|
pub fn[K : Hash + Eq] Set::union(self : Set[K], other : Set[K]) -> Set[K] {
  let m = Set::new()
  self.each(fn(k) { m.add(k) })
  other.each(fn(k) { m.add(k) })
  m
}

///|
pub fn[K : Hash + Eq] Set::intersection(
  self : Set[K],
  other : Set[K],
) -> Set[K] {
  let m = Set::new()
  self.each(fn(k) { if other.contains(k) { m.add(k) } })
  m
}

///|
pub impl[X : ToJson] ToJson for Set[X] with to_json(self) {
  let res = Array::new(capacity=self.size)
  for v in self {
    res.push(v.to_json())
  }
  Json::array(res)
}

///|
pub fn[K : Hash + Eq] Set::is_disjoint(self : Set[K], other : Set[K]) -> Bool {
  if self.length() <= other.length() {
    for k in self {
      if other.contains(k) {
        return false
      }
    }
  } else {
    for k in other {
      if self.contains(k) {
        return false
      }
    }
  }
  true
}

///|
pub fn[K : Hash + Eq] Set::is_subset(self : Set[K], other : Set[K]) -> Bool {
  if self.length() <= other.length() {
    for k in self {
      if !other.contains(k) {
        return false
      }
    }
    true
  } else {
    false
  }
}

///|
pub fn[K : Hash + Eq] Set::is_superset(self : Set[K], other : Set[K]) -> Bool {
  other.is_subset(self)
}

///|
pub impl[K : Hash + Eq] BitAnd for Set[K] with land(self, other) {
  self.intersection(other)
}

///|
pub impl[K : Hash + Eq] BitOr for Set[K] with lor(self, other) {
  self.union(other)
}

///|
pub impl[K : Hash + Eq] BitXOr for Set[K] with lxor(self, other) {
  self.symmetric_difference(other)
}

///|
pub impl[K : Hash + Eq] Sub for Set[K] with sub(self, other) {
  self.difference(other)
}
