# JSON パッケージとサイズへの影響

## 概要

`json` パッケージは JSON のパース・シリアライズ機能を提供する。
約 5,540 行のコードがあり、比較的大きなパッケージ。

## ファイル構成

| ファイル | 行数 | 説明 |
|----------|------|------|
| json.mbt | 15KB | メイン実装 |
| from_json.mbt | 8.7KB | デシリアライズ |
| lex_*.mbt | 計17KB | レキサー |
| parse.mbt | 3.2KB | パーサー |
| json_path.mbt | 5.6KB | JSONPath |
| tuple_fromjson.mbt | 16KB | タプルのデシリアライズ |
| types.mbt | 2.7KB | 型定義 |
| utils.mbt | 1.2KB | ユーティリティ |

## 依存関係

```
json
├── array
├── builtin
├── char
├── double      ← Double::to_string が含まれる
├── float
├── string
├── strconv     ← これも double に依存
├── option
└── buffer
```

## 推移的依存関係

jsonを使用すると、以下すべてが含まれる：
1. json 本体（約5,540行）
2. double + ryu（約1,000行）
3. strconv
4. buffer
5. その他基本パッケージ

## 問題: sorted_map が json に依存

```json
// sorted_map/moon.pkg.json
{
  "import": [
    "moonbitlang/core/json",  // ← ここ
    ...
  ]
}
```

**影響**: `sorted_map` を使うだけで `json` 全体が含まれる可能性

### なぜ依存しているか？

おそらくテストやデバッグ用の `Show` 実装のため。
ツリーシェイクが効けば問題ないが、効かない場合は大きなサイズ増加。

## サイズ削減の提案

### 1. json への依存を test-import に移動

```json
// sorted_map/moon.pkg.json の改善案
{
  "import": [
    "moonbitlang/core/builtin",
    "moonbitlang/core/option",
    "moonbitlang/core/tuple",
    "moonbitlang/core/quickcheck",
    "moonbitlang/core/string"
  ],
  "test-import": [
    "moonbitlang/core/json",  // テスト時のみ
    "moonbitlang/core/array"
  ]
}
```

### 2. json パッケージの分割

- `json/core` - 最小限のJSON型定義
- `json/parse` - パーサー
- `json/stringify` - シリアライズ
- `json/path` - JSONPath

### 3. 軽量な Show 実装

JSON に依存しない文字列化の実装を提供。

## 使用パターン別の依存

| 使用パターン | 含まれるパッケージ |
|-------------|------------------|
| 基本型のみ | builtin |
| Double::to_string | builtin, uint64, double/ryu |
| HashMap | builtin, array, tuple, int + Hasher |
| JSON | 上記全て + json, strconv, buffer |
| sorted_map | 上記全て（json含む） |

## 推奨事項

1. **JS ビルドサイズを気にする場合**:
   - `json` の使用を避ける
   - `sorted_map` より `hashmap` を使用
   - 必要な場合のみ `Double::to_string`

2. **ツリーシェイクの確認**:
   - 使用しない機能が本当に除外されているか確認
   - ビルド後のサイズを計測
