# Proposal: Swappable Standard Library Implementations for JS Backend

## Summary

I experimentally replaced some core library functions with corresponding JS FFI implementations. The results showed significant improvements:

**Request**: Either merge JS FFI implementations into core, or provide a mechanism to swap standard library implementations.

### Bundle Size Reduction Results

| Package | Before | After | Reduction |
|---------|--------|-------|-----------|
| Double::to_string | 72 KB | 2.3 KB | **97%** |
| JSON parse/stringify | 258 KB | 23 KB | **91%** |
| Regex | 320 KB | 11 KB | **97%** |
| **Combined (double + json + regex)** | 305 KB | 92 KB | **70%** |

### Performance Improvement

| Operation | Before | After | Speedup |
|-----------|--------|-------|---------|
| Double::to_string | 0.65-1.81 μs | 0.01-0.03 μs | **22-133x** |
| JSON stringify | 9.2 μs | 1.8 μs | **5x** |

All 2255 JS tests pass. API compatibility is maintained.

## The Problem

### 1. Unavoidable Dependencies via Show Trait

`Double::to_string` is implicitly called through the `Show` trait:

```moonbit
let msg = "Value: \{some_double}"  // Implicitly calls Double::to_string
```

This pulls in the Ryu algorithm (731 lines, 72KB). **Users cannot avoid this** - any string interpolation with floating-point numbers triggers this dependency.

### 2. High-Demand Packages Have High Cost

JSON is essential for JS backend applications, but using `@json` adds ~258KB. Users face an uncomfortable choice:
- Use standard library JSON → Large bundle
- Implement custom JSON handling → Poor developer experience

### 3. Library Author Perspective

For reference, common JS libraries:
- zod (validator): ~40KB
- ReactDOM: ~180KB

A MoonBit library using JSON and floating-point formatting can easily exceed these sizes.

## Precedent: Rust Wasm Allocator

In Rust Wasm, bundle size is a known concern. The standard allocator is large, so users can swap it:

```rust
extern crate wee_alloc;

// Use wee_alloc as the global allocator instead of the default
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
```

This reduces Wasm binary size by ~10KB with a simple one-line change. The key insight: **users can choose trade-offs appropriate for their use case**.

## What We Want

**Option A: Merge JS FFI implementations into core**

The core library ships with both implementations, selected by target:
- JS target: Use `JSON.parse`, `String(x)`, `RegExp`
- Wasm/Native target: Use Ryu, custom parser, NFA VM

**Option B: Package override mechanism**

Allow users to swap standard library packages:
```json
{
  "override": {
    "moonbitlang/core/double": "mizchi/jslight/double"
  }
}
```

## PoC Implementation

This repository demonstrates working implementations:

### Double::to_string

```moonbit
// double/to_string_js.mbt
pub fn Double::to_string(self : Double) -> String {
  js_double_to_string(self)
}

extern "js" fn js_double_to_string(d : Double) -> String =
  #| (x) => String(x)
```

### JSON

Delegates to `JSON.parse` / `JSON.stringify` with MoonBit enum conversion.

### Regex

Delegates to native `RegExp` with pattern conversion.

## Known Trade-offs

| Component | Trade-off | Acceptable for |
|-----------|-----------|----------------|
| Double::to_string | Minor edge case differences | Most applications |
| JSON | No detailed error positions | Web apps |
| Regex | V8 subset, some syntax unsupported | Web apps |

## Other Issues

### Hasher Lazy Initialization (Issue #2901)

`random_seed()` runs at module top-level, causing:
- ESM tree-shaking impossible
- Cloudflare Workers incompatibility

### `--nostd` Mode

Question: Can we import only `Array` with `--nostd` and map it to array literals?

## Related Work

- Prisma Wasm optimization: https://github.com/prisma/prisma-engines/issues/5008

## Repository

Experimental branch: https://github.com/mizchi/core/tree/jsbench

The `.private/` directory contains investigation logs created during implementation. Kept for reference.

---

# 提案: JS バックエンド向け標準ライブラリ実装の差し替え

## 要約

試験的に core ライブラリの一部の関数を対応する JS FFI に差し替えてみた。その結果、大きな効果が得られた:

**リクエスト**: JS FFI 実装をコアにマージするか、標準ライブラリを差し替えられる仕組みを提供してほしい。

### バンドルサイズ削減結果

| パッケージ | Before | After | 削減率 |
|-----------|--------|-------|-------|
| Double::to_string | 72 KB | 2.3 KB | **97%** |
| JSON parse/stringify | 258 KB | 23 KB | **91%** |
| Regex | 320 KB | 11 KB | **97%** |
| **統合 (double + json + regex)** | 305 KB | 92 KB | **70%** |

### パフォーマンス改善

| 操作 | Before | After | 高速化 |
|-----|--------|-------|-------|
| Double::to_string | 0.65-1.81 μs | 0.01-0.03 μs | **22-133倍** |
| JSON stringify | 9.2 μs | 1.8 μs | **5倍** |

全 2255 件の JS テストが通過。API 互換性は維持。

## 問題点

### 1. Show Trait 経由で回避不能な依存関係

`Double::to_string` は `Show` trait を通じて暗黙的に呼び出される:

```moonbit
let msg = "Value: \{some_double}"  // 暗黙的に Double::to_string を呼ぶ
```

これにより Ryu アルゴリズム（731行、72KB）が引き込まれる。**ユーザーはこれを回避できない** - 浮動小数点数を含む文字列補間で必ず発生。

### 2. 需要の高いパッケージが高コスト

JSON は JS バックエンドに不可欠だが、`@json` で約 258KB が追加される。ユーザーは不快な選択を迫られる:
- 標準ライブラリの JSON を使う → バンドルが大きい
- カスタム JSON を実装 → 開発者体験が悪い

### 3. ライブラリ作者の視点

参考: 一般的な JS ライブラリのサイズ:
- zod（バリデータ）: 約40KB
- ReactDOM: 約180KB

JSON と浮動小数点フォーマットを使うだけで、これらを超えてしまう。

## 前例: Rust Wasm のアロケータ

Rust Wasm ではバンドルサイズが問題になることが知られている。標準アロケータは大きいため、ユーザーが差し替えられる:

```rust
extern crate wee_alloc;

// デフォルトの代わりに wee_alloc をグローバルアロケータとして使用
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
```

これにより1行の変更で Wasm バイナリサイズが約 10KB 削減される。重要な洞察: **ユーザーが自分のユースケースに適したトレードオフを選択できる**。

## 求めているもの

**オプション A: JS FFI 実装をコアにマージ**

コアライブラリが両方の実装を同梱し、ターゲットで選択:
- JS ターゲット: `JSON.parse`, `String(x)`, `RegExp` を使用
- Wasm/Native ターゲット: Ryu, カスタムパーサー, NFA VM を使用

**オプション B: パッケージオーバーライド機構**

ユーザーが標準ライブラリパッケージを差し替え可能に:
```json
{
  "override": {
    "moonbitlang/core/double": "mizchi/jslight/double"
  }
}
```

## PoC 実装

このリポジトリには動作する実装が含まれている:

### Double::to_string

```moonbit
// double/to_string_js.mbt
pub fn Double::to_string(self : Double) -> String {
  js_double_to_string(self)
}

extern "js" fn js_double_to_string(d : Double) -> String =
  #| (x) => String(x)
```

### JSON

`JSON.parse` / `JSON.stringify` に委譲し、MoonBit enum に変換。

### Regex

ネイティブ `RegExp` に委譲し、パターンを変換。

## 既知のトレードオフ

| コンポーネント | トレードオフ | 許容可能な用途 |
|--------------|-------------|--------------|
| Double::to_string | 軽微なエッジケース差異 | ほとんどのアプリ |
| JSON | 詳細なエラー位置情報なし | Web アプリ |
| Regex | V8 サブセット、一部構文非対応 | Web アプリ |

## その他の問題

### Hasher 遅延初期化（Issue #2901）

`random_seed()` がモジュールのトップレベルで実行され、以下を引き起こす:
- ESM ツリーシェイキング不可
- Cloudflare Workers 非互換

### `--nostd` モード

質問: `--nostd` で `Array` のみを import し、配列リテラルにマッピングする方法はあるか？

## 関連事例

- Prisma Wasm 最適化: https://github.com/prisma/prisma-engines/issues/5008

## リポジトリ

実験ブランチ: https://github.com/mizchi/core/tree/jsbench

`.private/` ディレクトリには実装までの実験ログが含まれている。参考として残してある。
