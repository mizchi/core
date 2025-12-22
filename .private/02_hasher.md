# Hasher とグローバル副作用

## 概要

`Hasher` は xxHash32 アルゴリズムを実装したハッシュ計算用の構造体。
`builtin/hasher.mbt` に定義されている。

## グローバル副作用の問題

### 問題のコード（builtin/hasher.mbt:76-94）

```moonbit
///|
#cfg(not(target="js"))
let seed : Int = 0

///|
#cfg(target="js")
let seed : Int = random_seed()

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
```

### 問題点

1. **JS ターゲットでのみ乱数シード**
   - 非JS: `seed = 0`（固定）
   - JS: `seed = random_seed()`（実行時に乱数生成）

2. **グローバル初期化時の副作用**
   - モジュールロード時に `crypto.getRandomValues()` または `Math.random()` が呼ばれる
   - これは純粋な関数型プログラミングの原則に反する

3. **ハッシュ値が実行ごとに異なる（JSのみ）**
   - テストの再現性に問題
   - デバッグが困難
   - ハッシュベースのデータ構造（HashMap, HashSet）の順序が不定

## 影響範囲

Hasherを使用するパッケージ：
- `hashmap` - HashMap全般
- `hashset` - HashSet全般
- `immut/hashmap` - 不変HashMap
- `immut/hashset` - 不変HashSet
- その他Hash traitを実装する全ての型

## Hasher の使用方法

```moonbit
let hasher = Hasher::new(seed=0)  // 明示的にシードを指定可能
hasher.combine_int(42)
hasher.combine_string("hello")
let hash = hasher.finalize()
```

## 回避策の検討

### 1. 明示的シード指定
```moonbit
let hasher = Hasher::new(seed=42)  // 固定シードを使用
```

### 2. Hash trait の hash メソッド
`Hash::hash()` はデフォルトで `Hasher::new()` を使用するため、グローバルシードの影響を受ける。

```moonbit
// builtin/traits.mbt:75-77
impl Hash with hash(self) {
  Hasher::new()..combine(self).finalize()
}
```

### 3. 可能な改善案

- シードを引数として渡すAPI設計
- 決定的ハッシュモードの提供
- ビルド時にシード戦略を選択可能にする
- JSターゲットでもデフォルトを固定シードにする（オプトインで乱数化）
