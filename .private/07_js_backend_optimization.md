# JS Backend 最適化アプローチ

## 概要

MoonBitのJSビルドでは、コード量がそのままバンドルサイズに影響する。
しかし、JSネイティブAPIで代替できる機能については、`extern "js" fn` を使って
実装を委譲することで、大幅なサイズ削減が可能。

### 現状のバンドルサイズ

| Package | Raw Size | Gzip Size | 主な実装 |
|---------|----------|-----------|----------|
| map     | 84 KB    | 14 KB     | HashMap + Hasher |
| double  | 72 KB    | 13 KB     | Ryu algorithm |
| json    | 289 KB   | 36 KB     | Parser + Serializer |
| regex   | 358 KB   | 62 KB     | NFA VM + Unicode tables |

## アプローチ1: 完全委譲 (BigIntパターン)

### 既存の成功例: bigint_js.mbt

BigIntパッケージは既にJS委譲を実装している:

```moonbit
// bigint_js.mbt - JS環境専用
///|
type BigInt  // opaque type

///|
pub extern "js" fn BigInt::from_string(str : String) -> BigInt =
  #|(x) => BigInt(x)

///|
pub extern "js" fn BigInt::to_string(self : BigInt) -> String =
  #|(x) => String(x)

///|
pub extern "js" fn op_add(self : BigInt, other : BigInt) -> BigInt =
  #|(x, y) => x + y
```

### 効果
- Non-JS版: 1,845行
- JS版: 520行
- **削減率: 約72%**

### ファイル分離パターン
```
bigint/
├── bigint.mbt        # 共通インターフェース
├── bigint_js.mbt     # JS専用実装 (targets: ["js"])
└── bigint_nonjs.mbt  # Wasm/Native実装 (targets: ["wasm", "wasm-gc"])
```

moon.pkg.jsonでターゲット指定:
```json
{
  "targets": {
    "bigint_js.mbt": ["js"],
    "bigint_nonjs.mbt": ["wasm", "wasm-gc"]
  }
}
```

---

## アプローチ2: Double::to_string の最適化

### 現状の問題
- Ryuアルゴリズム: 731行の複雑な実装
- 128bit演算、累乗テーブル、多精度演算を含む
- JSビルドでは不要（Number.toString()で代替可能）

### 提案: double_js.mbt の追加

```moonbit
// double/ryu_js.mbt (新規)
///|
pub fn Double::to_string(self : Double) -> String {
  js_double_to_string(self)
}

///|
extern "js" fn js_double_to_string(d : Double) -> String =
  #|(x) => {
  #|  if (Object.is(x, -0)) return "-0";
  #|  if (Number.isNaN(x)) return "NaN";
  #|  if (!Number.isFinite(x)) return x > 0 ? "Infinity" : "-Infinity";
  #|  return String(x);
  #|}
```

### 互換性の考慮
- `-0` の文字列化: JSは `"0"` を返すが、Ryuは `"-0"`
- 非常に小さい/大きい数の指数表記
- ECMAScript仕様との完全互換が必要な場合は注意

### 期待される効果
- Ryu実装 731行 → JS FFI 10行程度
- 推定削減: 30-40KB

---

## アプローチ3: JSON パース最適化

### 現状の構造
```
json/
├── parse.mbt       # パーサー本体
├── lex_number.mbt  # 数値トークナイザ
├── lex_string.mbt  # 文字列トークナイザ
├── lex_misc.mbt    # その他トークン
└── from_json.mbt   # 型変換 (維持必要)
```

### 提案: パース層のみ委譲

```moonbit
// json/parse_js.mbt (新規)
///|
pub fn parse(input : String) -> Json raise JsonError {
  try {
    js_json_parse(input)
  } catch {
    e => raise JsonError(e.to_string())
  }
}

///|
extern "js" fn js_json_parse(input : String) -> Json =
  #|(s) => {
  #|  const convert = (v) => {
  #|    if (v === null) return { $tag: "Null" };
  #|    if (typeof v === "boolean") return { $tag: "Boolean", 0: v };
  #|    if (typeof v === "number") return { $tag: "Number", 0: v };
  #|    if (typeof v === "string") return { $tag: "String", 0: v };
  #|    if (Array.isArray(v)) return { $tag: "Array", 0: v.map(convert) };
  #|    return { $tag: "Object", 0: new Map(Object.entries(v).map(([k,v]) => [k, convert(v)])) };
  #|  };
  #|  return convert(JSON.parse(s));
  #|}
```

### 課題
1. **Json型のメモリレイアウト**: MoonBitのenum表現をJS側で正確に再現する必要
2. **エラー形式**: JsonError型との整合性
3. **from_json層**: MoonBit側での型変換は維持必須

### 期待される効果
- レキサー + パーサー約600行 → JS FFI 30行程度
- 推定削減: 50-80KB

---

## アプローチ4: Regex の部分最適化

### 現状の複雑性
- パーサー: 984行
- NFA VM: 211行
- Unicodeテーブル: 644行 (最大の問題)

### 選択肢A: 完全委譲 (制限あり)

```moonbit
// regex/regex_js.mbt
///|
type Regex

///|
pub fn compile(pattern : String) -> Regex raise {
  js_regexp_new(pattern)
}

///|
extern "js" fn js_regexp_new(pattern : String) -> Regex =
  #|(p) => new RegExp(p, 'u')

///|
pub fn Regex::execute(self : Regex, input : String) -> MatchResult? {
  js_regexp_exec(self, input)
}

///|
extern "js" fn js_regexp_exec(re : Regex, input : String) -> MatchResult? =
  #|(re, s) => {
  #|  const m = re.exec(s);
  #|  if (!m) return null;
  #|  return { /* MatchResult構造 */ };
  #|}
```

### 制限事項
- `\p{L}`, `\p{N}` 等のUnicodeプロパティ: ES2018+で部分対応
- 名前付きキャプチャグループ: ES2018+で対応
- lookbehind: ES2018+で対応
- 古いブラウザでは動作しない可能性

### 選択肢B: Unicodeテーブルのみ最適化

Unicodeカテゴリ判定をJS側に委譲:

```moonbit
///|
extern "js" fn is_unicode_letter(c : Char) -> Bool =
  #|(c) => /\p{L}/u.test(c)

///|
extern "js" fn is_unicode_number(c : Char) -> Bool =
  #|(c) => /\p{N}/u.test(c)
```

### 期待される効果
- 完全委譲: 推定削減 200-250KB
- テーブルのみ: 推定削減 50-100KB

---

## アプローチ5: Math関数の委譲

### 現状
double/pow_nonjs.mbt に445行の数学関数実装

### 提案

```moonbit
// double/math_js.mbt
///|
pub extern "js" fn Double::pow(self : Double, exp : Double) -> Double =
  #|(x, y) => Math.pow(x, y)

///|
pub extern "js" fn Double::sin(self : Double) -> Double =
  #|(x) => Math.sin(x)

///|
pub extern "js" fn Double::cos(self : Double) -> Double =
  #|(x) => Math.cos(x)

///|
pub extern "js" fn Double::sqrt(self : Double) -> Double =
  #|(x) => Math.sqrt(x)

///|
pub extern "js" fn Double::log(self : Double) -> Double =
  #|(x) => Math.log(x)
```

### 期待される効果
- pow実装 445行 → JS FFI 20行程度
- 推定削減: 15-25KB

---

## 実装優先度

| 優先度 | 対象 | 難易度 | 削減効果 | 互換性リスク |
|--------|------|--------|----------|--------------|
| 1 | Double::to_string (Ryu) | 低 | 30-40KB | 低 |
| 2 | Double::pow等 (Math) | 低 | 15-25KB | 極低 |
| 3 | JSON parse | 中 | 50-80KB | 中 |
| 4 | Regex (完全) | 高 | 200KB+ | 高 |
| 5 | Regex (Unicode表のみ) | 中 | 50-100KB | 低 |

---

## 実装上の注意点

### 1. ファイル命名規則
```
foo.mbt        # 共通コード
foo_js.mbt     # JS専用 (targets: ["js"])
foo_nonjs.mbt  # 非JS専用 (targets: ["wasm", "wasm-gc"])
```

### 2. moon.pkg.jsonでのターゲット指定
```json
{
  "targets": {
    "ryu.mbt": ["wasm", "wasm-gc"],
    "ryu_js.mbt": ["js"]
  }
}
```

### 3. 型の互換性
- JSから返す複合型はMoonBitのメモリレイアウトに合わせる必要
- enumは `{ $tag: "TagName", 0: value1, 1: value2 }` 形式

### 4. エラーハンドリング
- JS例外をMoonBitのraise/catchに変換する仕組みが必要
- try-catchラッパーの実装

---

## 次のステップ

1. **PoC実装**: Double::to_string のJS委譲版を作成
2. **ベンチマーク**: 性能への影響を測定
3. **互換性テスト**: エッジケースの動作確認
4. **段階的導入**: 優先度順に実装を進める

---

## 参考: BigInt実装の詳細

bigint_js.mbtで使用されているFFIパターン:

```moonbit
// 型定義
type BigInt

// コンストラクタ
extern "js" fn BigInt::js_from_string(str : String) -> BigInt =
  #|(x) => BigInt(x)

// メソッド
pub extern "js" fn BigInt::to_string(self : BigInt) -> String =
  #|(x) => String(x)

// 演算子
pub extern "js" fn op_add(self : BigInt, other : BigInt) -> BigInt =
  #|(x, y) => x + y

// 比較
pub extern "js" fn op_equal(self : BigInt, other : BigInt) -> Bool =
  #|(x, y) => x === y
```

この33個のextern "js"関数で1,845行のPure実装を置き換えている。
