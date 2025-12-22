# JS FFI 実装ガイド

## MoonBit JS FFI の基本

### 構文

```moonbit
///|
extern "js" fn function_name(arg1 : Type1, arg2 : Type2) -> ReturnType =
  #| (a, b) => { /* JavaScript code */ }
```

### 引数マッピング

| MoonBit型 | JavaScript型 |
|-----------|-------------|
| Int | number (32bit整数) |
| Int64 | bigint |
| Double | number |
| String | string |
| Bool | boolean |
| Bytes | Uint8Array |
| Array[T] | Array |
| Option[T] | T \| null |
| 構造体 | { field1: v1, field2: v2 } |
| enum | { $tag: "Name", 0: v1, 1: v2 } |

---

## 実装パターン

### パターン1: 単純な関数委譲

```moonbit
// Math.pow の委譲
///|
pub extern "js" fn Double::pow(self : Double, exp : Double) -> Double =
  #|(x, y) => Math.pow(x, y)
```

### パターン2: 型変換を伴う委譲

```moonbit
// JSON.parse - JSオブジェクトをMoonBit Jsonに変換
///|
extern "js" fn js_parse_json(s : String) -> Json =
  #|(s) => {
  #|  const toJson = (v) => {
  #|    if (v === null) return { $tag: "Null" };
  #|    switch (typeof v) {
  #|      case "boolean": return { $tag: "Boolean", 0: v };
  #|      case "number": return { $tag: "Number", 0: v };
  #|      case "string": return { $tag: "String", 0: v };
  #|    }
  #|    if (Array.isArray(v)) {
  #|      return { $tag: "Array", 0: v.map(toJson) };
  #|    }
  #|    const entries = Object.entries(v).map(([k, val]) => [k, toJson(val)]);
  #|    return { $tag: "Object", 0: new Map(entries) };
  #|  };
  #|  return toJson(JSON.parse(s));
  #|}
```

### パターン3: エラーハンドリング

```moonbit
// MoonBitのErrorをラップする
///|
pub fn parse_json(s : String) -> Json raise JsonParseError {
  try {
    js_parse_json_safe(s)
  } catch {
    e => raise JsonParseError(e.to_string())
  }
}

///|
extern "js" fn js_parse_json_safe(s : String) -> Json raise =
  #|(s) => {
  #|  try {
  #|    return /* ... */;
  #|  } catch (e) {
  #|    throw new Error(e.message);
  #|  }
  #|}
```

### パターン4: Opaque型

```moonbit
// JSオブジェクトをそのまま保持
///|
type JsRegExp  // opaque - 内部構造を隠蔽

///|
extern "js" fn js_regexp_new(pattern : String) -> JsRegExp =
  #|(p) => new RegExp(p, 'u')

///|
extern "js" fn js_regexp_test(re : JsRegExp, s : String) -> Bool =
  #|(re, s) => re.test(s)
```

---

## ターゲット別ファイル分離

### ディレクトリ構造

```
package/
├── moon.pkg.json
├── types.mbt           # 共通の型定義
├── interface.mbt       # 公開API (impl trait等)
├── impl_js.mbt         # JS専用実装
└── impl_wasm.mbt       # Wasm専用実装
```

### moon.pkg.json 設定

```json
{
  "import": [...],
  "targets": {
    "impl_js.mbt": ["js"],
    "impl_wasm.mbt": ["wasm", "wasm-gc"]
  }
}
```

---

## 具体的な最適化案

### 案1: Double::to_string (Ryu置換)

**現状**: `double/internal/ryu/ryu.mbt` (731行)

**最適化後**:
```moonbit
// double/to_string_js.mbt
///|
pub fn Double::to_string(self : Double) -> String {
  // 特殊ケースのハンドリング
  if self.is_nan() {
    return "NaN"
  }
  if self.is_pos_inf() {
    return "Infinity"
  }
  if self.is_neg_inf() {
    return "-Infinity"
  }
  // -0 のチェック
  if self == 0.0 && 1.0 / self < 0.0 {
    return "-0"
  }
  js_number_to_string(self)
}

///|
extern "js" fn js_number_to_string(d : Double) -> String =
  #|(x) => String(x)
```

**削減効果**: ~35KB

---

### 案2: strconv最適化

**現状**: strconvはdoubleに依存 → Ryuが含まれる

**最適化アプローチ**:
- Double::to_stringをJS委譲すれば自動的に解決
- parse_double もJS委譲可能:

```moonbit
///|
extern "js" fn js_parse_float(s : String) -> Double =
  #|(s) => parseFloat(s)

///|
pub fn parse_double(s : String) -> Double? {
  let d = js_parse_float(s)
  if d.is_nan() && s != "NaN" {
    None  // パース失敗
  } else {
    Some(d)
  }
}
```

---

### 案3: Regex軽量版

Unicode完全対応が不要な場合のシンプル実装:

```moonbit
// string/regex/regex_js.mbt
///|
type Regex

///|
struct MatchResult {
  matched : String
  index : Int
  groups : Array[String?]
}

///|
pub fn compile(pattern : String) -> Regex raise {
  js_regexp_compile(pattern)
}

///|
extern "js" fn js_regexp_compile(pattern : String) -> Regex raise =
  #|(p) => {
  #|  try {
  #|    return new RegExp(p, 'gu');
  #|  } catch (e) {
  #|    throw new Error(`Invalid regex: ${e.message}`);
  #|  }
  #|}

///|
pub fn Regex::exec(self : Regex, input : String) -> MatchResult? {
  js_regexp_exec(self, input)
}

///|
extern "js" fn js_regexp_exec(re : Regex, input : String) -> MatchResult? =
  #|(re, s) => {
  #|  re.lastIndex = 0;
  #|  const m = re.exec(s);
  #|  if (!m) return null;
  #|  return {
  #|    matched: m[0],
  #|    index: m.index,
  #|    groups: m.slice(1).map(g => g ?? null)
  #|  };
  #|}
```

**削減効果**: ~250KB (ただしUnicode機能制限あり)

---

### 案4: Hasher最適化

**現状の問題**: グローバルな乱数シード初期化

```moonbit
// 現状 (hasher/hasher.mbt)
let global_random_state : UInt = init_random_state()

///|
extern "js" fn init_random_state() -> UInt =
  #|() => Math.floor(Math.random() * 0x100000000)
```

**最適化案**: 遅延初期化または固定シード

```moonbit
// オプション1: 固定シード (決定論的だがDoS耐性なし)
let global_random_state : UInt = 0x12345678

// オプション2: 遅延初期化
let mut global_random_state : UInt? = None

fn get_random_state() -> UInt {
  match global_random_state {
    Some(s) => s
    None => {
      let s = init_random_state()
      global_random_state = Some(s)
      s
    }
  }
}
```

---

## 互換性チェックリスト

### Double::to_string
- [ ] `-0` → `"-0"` (JSは `"0"`)
- [ ] 非常に大きい数の指数表記
- [ ] 非常に小さい数の指数表記
- [ ] NaN, Infinity の文字列

### JSON.parse
- [ ] 深いネスト (スタックオーバーフロー)
- [ ] 数値の精度 (53bit超)
- [ ] Unicode エスケープ
- [ ] 重複キー

### Regex
- [ ] Unicode プロパティ (\p{L})
- [ ] 名前付きキャプチャ
- [ ] 後方参照
- [ ] 複雑なアサーション

---

## ベンチマーク方法

最適化前後でサイズと性能を比較:

```bash
# サイズ測定
moon build --target js --package package/name
wc -c target/js/release/build/package/name/name.js
gzip -c target/js/release/build/package/name/name.js | wc -c

# 性能測定
node target/js/release/build/package/name/name.js
```

---

## リスク評価

| 対象 | サイズ削減 | 実装難度 | 互換性リスク | 推奨 |
|------|-----------|----------|--------------|------|
| Double::to_string | 高 | 低 | 低 | 強く推奨 |
| Math関数 | 中 | 低 | 極低 | 強く推奨 |
| JSON parse | 高 | 中 | 中 | 推奨 |
| Regex (完全) | 極高 | 高 | 高 | 条件付き |
| Regex (部分) | 中 | 中 | 低 | 推奨 |
