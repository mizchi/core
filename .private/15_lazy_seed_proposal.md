# Proposal: Lazy Seed Initialization for JS Backend

## Problem

現在の `builtin/hasher.mbt` の実装:

```moonbit
#cfg(target="js")
let seed : Int = random_seed()

extern "js" fn random_seed() -> Int =
  #|() => {
  #|  if (globalThis.crypto?.getRandomValues) { ... }
  #|}
```

これは JS 出力で以下のトップレベル副作用を生成:

```javascript
const seed = random_seed();  // ← トップレベルで実行される
```

**問題点:**
1. **ESM treeshake 不可**: トップレベル副作用があるモジュールは bundler が削除できない
2. **Cloudflare Workers 非互換**: グローバルスコープでの `crypto.getRandomValues()` が禁止
3. **IIFE でも回避不可**: モジュール読み込み時に必ず実行される

## Solution

遅延初期化パターンを使用:

```moonbit
///|
#cfg(target="js")
let lazy_seed : Ref[Int?] = { val: None }

///|
#cfg(target="js")
fn get_seed() -> Int {
  match lazy_seed.val {
    Some(s) => s
    None => {
      let s = random_seed()
      lazy_seed.val = Some(s)
      s
    }
  }
}

///|
#cfg(target="js")
extern "js" fn random_seed() -> Int =
  #|() => {
  #|  if (globalThis.crypto?.getRandomValues) {
  #|    const array = new Uint32Array(1);
  #|    globalThis.crypto.getRandomValues(array);
  #|    return array[0] | 0;
  #|  } else {
  #|    return Math.floor(Math.random() * 0x100000000) | 0;
  #|  }
  #|}

///|
pub fn Hasher::new(seed? : Int) -> Hasher {
  let actual_seed = match seed {
    Some(s) => s
    None => {
      #cfg(target="js") { get_seed() }
      #cfg(not(target="js")) { 0 }
    }
  }
  { acc: actual_seed.reinterpret_as_uint() + GPRIME5 }
}
```

## Generated JS Output

**Before (現状):**
```javascript
const seed = random_seed();  // トップレベル副作用

function Hasher$new(seed_opt) {
  let seed = seed_opt ?? moonbit_seed;
  // ...
}
```

**After (遅延版):**
```javascript
const lazy_seed = { val: undefined };  // 副作用なし

function get_seed() {
  if (lazy_seed.val === undefined) {
    lazy_seed.val = random_seed();  // 初回使用時のみ
  }
  return lazy_seed.val;
}

function Hasher$new(seed_opt) {
  let seed = seed_opt ?? get_seed();
  // ...
}
```

## Benefits

| 項目 | Before | After |
|------|--------|-------|
| トップレベル副作用 | あり | なし |
| ESM treeshake | 不可 | 可能 |
| Cloudflare Workers | 非互換 | 互換 |
| 初回 Hasher 生成 | 同じ | 同じ |
| 2回目以降 | 同じ | キャッシュ使用 |

## Performance Impact

- **初回**: `random_seed()` + Option チェック (数ns増加)
- **2回目以降**: Option チェックのみ (数ns)
- **実質的な影響**: 無視できるレベル

## PoC Verification

`benches_js/lazy_seed/` で遅延初期化パターンを検証済み:

```javascript
// 出力結果
const lazy_seed = { val: undefined };  // ← 副作用なし！

function get_lazy_seed() {
  if (lazy_seed.val === undefined) {
    lazy_seed.val = js_random_seed();
    return lazy_seed.val;
  }
  return lazy_seed.val;
}
```

## Alternative: Per-Table Seed

より強固な hashdos 対策として、HashMap/Map 生成時にシードを決定する方式も検討可能:

```moonbit
pub fn HashMap::new() -> HashMap[K, V] {
  let seed = random_seed()  // テーブルごとに異なるシード
  { entries: ..., seed: seed }
}
```

これは遅延初期化とは別の改善として検討可能。

## Recommendation

1. **短期**: 遅延初期化を導入して treeshake / Cloudflare Workers 問題を解決
2. **長期**: per-table seed を検討して hashdos 耐性を強化
