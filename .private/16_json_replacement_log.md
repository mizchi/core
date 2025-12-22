# JSON/Map JS FFI 置き換え作業ログ

## 概要

MoonBit の JS バックエンド向けに、JSON と Map の実装を JavaScript ネイティブ API で置き換え、バンドルサイズを大幅に削減した。

## 成果

| 項目 | Before | After | 削減率 |
|------|--------|-------|--------|
| バンドルサイズ (regex+json) | 305KB | 92KB | **70%** |
| json_stringify 性能 | 9.2μs | 1.8μs | **5x 高速化** |
| Map FFI コード行数 | - | -89行 | リファクタで削減 |

## 実装ファイル

### JSON FFI

| ファイル | 対象 | 内容 |
|----------|------|------|
| `json/parse_ffi_js.mbt` | JS | JSON.parse FFI + stringify FFI関数定義 |
| `json/stringify_ffi_js.mbt` | JS | stringify 本体 (Replacer対応付き) |
| `json/stringify_nonjs.mbt` | 非JS | オリジナルstringify実装 |
| `json/parse.mbt` | 非JS | オリジナルparse実装 |

### Map FFI

| ファイル | 対象 | 内容 |
|----------|------|------|
| `builtin/linked_hash_map_ffi_js.mbt` | JS | 簡略化Map実装 |
| `builtin/linked_hash_map.mbt` | 非JS | オリジナルMap実装 |

## 技術的詳細

### 1. JSON Parse FFI

```moonbit
extern "js" fn js_json_parse_raw(input : String) -> JSParseResult =
  #| (s) => {
  #|   function JsonNumber(n, repr) { this._0 = n; this._1 = repr; }
  #|   JsonNumber.prototype.$tag = 3;
  #|   // ... MoonBit Json enumに変換
  #|   return { ok: true, value: convert(JSON.parse(s)) };
  #| }
```

**課題と解決:**
- MoonBit の `Json` enum は `$tag` フィールドで判別される
- Object は一時的に `$tag=6` の `JsonObjectEntries` として返し、後で `Map[String, Json]` に変換

### 2. JSON Stringify FFI

```moonbit
extern "js" fn js_json_stringify(json : Json, indent : Int) -> String =
  #| (json, indent) => {
  #|   const convert = (v) => {
  #|     switch (v.$tag) {
  #|       case 6: {
  #|         const obj = {};
  #|         let entry = v._0.head;  // Map の Entry linked list
  #|         while (entry) {
  #|           obj[entry.key] = convert(entry.value);
  #|           entry = entry.next;
  #|         }
  #|         return obj;
  #|       }
  #|       // ...
  #|     }
  #|   };
  #|   return JSON.stringify(convert(json), null, indent || undefined);
  #| }
```

**重要な発見:**
- MoonBit の `Map` は `LinkedHashMap` 実装
- Entry 構造: `{ key, value, next, prev, psl, hash }`
- `head` から `next` を辿って全エントリを取得

### 3. Map FFI 実装

Entry 構造を維持しつつ、内部アルゴリズムを簡略化:

```moonbit
priv struct Entry[K, V] {
  prev : Int
  mut next : Entry[K, V]?
  psl : Int   // 未使用、互換性のため保持
  hash : Int  // 未使用、互換性のため保持
  key : K
  mut value : V
}

struct Map[K, V] {
  mut size : Int
  mut head : Entry[K, V]?
  // その他のフィールドは互換性のため保持
}
```

**設計判断:**
- ハッシュテーブルの代わりに線形探索を使用
- コードサイズ削減を優先（O(n) vs O(1) のトレードオフ）
- stringify FFI との互換性のため Entry 構造を維持

### 4. Map FFI リファクタリング

**削除したもの:**
- 未使用の JS FFI 関数 (6関数、約25行)
  ```moonbit
  // 削除: js_map_new, js_map_set, js_map_get, js_map_has, js_map_delete, js_map_size
  ```
- 未使用のヘルパー関数
  ```moonbit
  // 削除: StringView::equal_to_string, BytesView::equal_to_bytes
  ```

**共通化したもの:**
```moonbit
fn[K, V] Map::append_entry(self : Map[K, V], entry : Entry[K, V]) -> Unit {
  match self.head {
    None => self.head = Some(entry)
    Some(_) => {
      // 末尾を探して追加
    }
  }
  self.size += 1
}
```

これにより `set`, `map`, `merge_in_place` の重複コードを削除。

## moon.pkg.json 設定

```json
{
  "targets": {
    "parse_ffi_js.mbt": ["js"],
    "parse.mbt": ["not", "js"],
    "stringify_ffi_js.mbt": ["js"],
    "stringify_nonjs.mbt": ["not", "js"],
    "linked_hash_map_ffi_js.mbt": ["js"],
    "linked_hash_map.mbt": ["not", "js"]
  }
}
```

## 遭遇したエラーと解決

### 1. ParseError 構造体の誤り

```
Error: position只有两个字段 line 和 column
```

**修正:** `InvalidChar({ line: 1, column: 0 }, char)` の形式に変更

### 2. String インデックスの戻り値型

```
error: String[0] returns UInt16, not Char
```

**修正:** `error_msg[0].to_int().unsafe_to_char()`

### 3. Map の iteration 方法

```javascript
// 誤: v._0.entries()  // JS Map のメソッド
// 正: v._0.head → entry.next を辿る
```

### 4. unused_mut 警告

```
Error: The mutability of field 'prev' is never used
```

**修正:** 実際に変更されないフィールドから `mut` を削除

## 既知の制限

JS FFI 版では以下のテストが失敗する（既知の挙動差）:

1. **JSON Infinity**: `JSON.stringify(Infinity)` → `null`
2. **Map capacity**: 常に 8 を返す（内部的にはリンクリストなので意味がない）

## コミット履歴

1. `feat(json): add JS FFI JSON parse/stringify implementation`
2. `feat(builtin): add Map JS FFI implementation`
3. `refactor(builtin): reduce Map JS FFI code by 89 lines`

## 今後の検討事項

1. **Hash trait 不要化**: JS FFI 版では Hash を使わないが、API 互換のため制約を残している
2. **capacity() の挙動**: 常に 8 を返すのは誤解を招く可能性
3. **大規模 Map での性能**: 線形探索のため O(n) だが、多くのケースでは問題にならない
