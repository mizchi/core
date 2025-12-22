# Map 実装の比較

## 利用可能な Map 実装

1. **HashMap** (`hashmap`) - ハッシュベース（mutable）
2. **@immut/hashmap** - ハッシュベース（immutable）
3. **sorted_map** - ソート済み（mutable、赤黒木）
4. **@immut/sorted_map** - ソート済み（immutable）

## 依存関係比較

### HashMap
```
hashmap
├── builtin
├── test
├── array
├── tuple
├── quickcheck
└── int
```
**特徴**: json に依存しない。Hasher を使用。

### sorted_map
```
sorted_map
├── builtin
├── option
├── tuple
├── quickcheck
├── json          ← 問題点
└── string
```
**特徴**: json に依存するため、サイズ増加の原因

### @immut/hashmap
```
immut/hashmap
├── builtin
├── array
├── tuple
├── quickcheck
├── immut/internal/sparse_array
├── immut/internal/path
└── list
```
**特徴**: json に依存しない。HAMT 実装。

### @immut/sorted_map
```
immut/sorted_map
├── builtin
├── tuple
├── string
├── array
├── quickcheck
└── json          ← 問題点
```
**特徴**: sorted_map と同様に json に依存

## Hasher の影響

### HashMapの場合
- `Hash` trait を使用
- キーは `Hash + Eq` を実装する必要あり
- JSターゲットではグローバルシードによる非決定性

### sorted_map の場合
- `Compare` trait を使用
- キーは `Compare` を実装する必要あり
- Hasher の影響なし（ハッシュを使わない）

## 使用シナリオ別推奨

### 1. JSビルドサイズを最小化したい
```
推奨: hashmap または immut/hashmap
理由: json に依存しない
```

### 2. 決定的な動作が必要
```
推奨: sorted_map または immut/sorted_map
理由: Hasher のシード問題を回避
注意: json への依存がある
```

### 3. 順序が必要
```
推奨: sorted_map または immut/sorted_map
理由: キーがソートされている
```

### 4. 高速なルックアップ
```
推奨: hashmap
理由: O(1) 平均ルックアップ（sorted_map は O(log n)）
```

## 実装詳細

### HashMap（Robin Hood Hashing）
- 衝突解決: Robin Hood ハッシング
- 自動リサイズ: 50% 充填率で拡張
- 初期容量: 8（2のべき乗に丸められる）

### sorted_map（赤黒木）
- バランス木による実装
- 挿入/検索/削除: O(log n)
- 順序保証: キーの Compare による

## コード例

```moonbit
// HashMap
let map : @hashmap.HashMap[String, Int] = @hashmap.new()
map.set("key", 42)

// sorted_map
let smap : @sorted_map.T[String, Int] = @sorted_map.new()
smap.set("key", 42)

// immut/hashmap
let imap : @immut/hashmap.T[String, Int] = @immut/hashmap.new()
let imap2 = imap.add("key", 42)
```
