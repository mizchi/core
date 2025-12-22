# MoonBit Core Library 概要

## リポジトリ構成

MoonBit標準ライブラリは57個のパッケージで構成されています。

### パッケージ一覧

#### 基盤パッケージ（依存関係なし/最小限）
- `builtin` - すべてのパッケージの基礎
- `abort` - 仮想パッケージ
- `coverage` - builtinのみに依存

#### プリミティブ型
- `bool`, `byte`, `char`, `unit`
- `int`, `int16`, `int64`
- `uint`, `uint16`, `uint64`
- `float`, `double`

#### 文字列・バイト
- `string` - 文字列操作
- `bytes` - バイト列
- `buffer` - 可変バッファ
- `strconv` - 文字列変換（double依存）
- `encoding/utf8`, `encoding/utf16` - エンコーディング

#### コレクション（mutable）
- `array` - 配列
- `hashmap` - ハッシュマップ（Hash + Eq必須）
- `hashset` - ハッシュセット
- `deque` - 両端キュー
- `queue` - キュー
- `priority_queue` - 優先度付きキュー
- `sorted_map` - ソート済みマップ（**json依存あり！**）
- `sorted_set` - ソート済みセット
- `set` - セット
- `list` - リスト

#### コレクション（immutable）
- `immut/array`
- `immut/hashmap`, `immut/hashset`
- `immut/sorted_map`, `immut/sorted_set`
- `immut/list`
- `immut/priority_queue`

#### ユーティリティ
- `option`, `result` - Optional/Result型
- `ref` - 参照
- `tuple` - タプル
- `cmp` - 比較
- `error` - エラー
- `env` - 環境
- `math` - 数学関数
- `random` - 乱数生成
- `bigint` - 大きな整数

#### テスト・開発
- `test` - テストフレームワーク
- `bench` - ベンチマーク
- `quickcheck` - プロパティベーステスト

#### その他
- `json` - JSONパース/シリアライズ
- `string/regex` - 正規表現
- `prelude` - プリロード

## ビルドターゲット

各パッケージは複数のターゲットをサポート：
- `js` - JavaScript
- `wasm`, `wasm-gc` - WebAssembly
- `native`, `llvm` - ネイティブ

ターゲット固有のファイルは `*_js.mbt`, `*_nonjs.mbt` などの命名規則に従う。
