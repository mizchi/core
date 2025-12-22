# Regex JS FFI 最適化レポート

## 概要

MoonBitの`string/regex`パッケージをJavaScriptネイティブの`RegExp`に委譲することで、JSバックエンドのバンドルサイズを大幅に削減できるかを検証した。

## バンドルサイズ比較

| 実装 | Raw Size | Gzip Size | 削減率 |
|------|----------|-----------|--------|
| **Original** (MoonBit regex) | 320 KB | 53 KB | - |
| **JS FFI** (native RegExp) | 11 KB | 2 KB | **97%** |

### 内訳

オリジナル実装の主なサイズ構成:
- パーサー: 約984行
- NFA VM: 約211行
- Unicodeテーブル: 約644行（最大）
- その他ユーティリティ

JS FFI版の実装:
- FFI関数定義: 約10関数
- ラッパーAPI: 約150行
- 合計: 約200行

## パフォーマンス比較

### 実行速度 (us/op)

| 操作 | Original | JS FFI | 高速化 |
|------|----------|--------|--------|
| exec simple | 5.5 | 0.11 | ~50x |
| exec email | 8.2 | 0.20 | ~41x |
| exec number | 5.3 | 0.28 | ~19x |
| compile simple | 6.9 | 0.17 | ~41x |
| compile complex | 14.3 | 0.18 | ~79x |

JS FFI版はV8のネイティブ正規表現エンジンを使用するため、解釈実行のMoonBit実装より大幅に高速。

## テストカバレッジ

### 実装したテスト: 44件 (全パス)

テストした機能:
- 基本的なパターンマッチ
- 量指定子 (`*`, `+`, `?`, `{n}`, `{n,m}`, `{n,}`)
- 文字クラス (`\d`, `\w`, `\s`, `[a-z]`, `[^abc]`, `[\d]`, `[\W]`)
- アンカー (`^`, `$`, `\b`, `\B`)
- グループ (キャプチャ、非キャプチャ、名前付き、ネスト)
- 交互選択 (`|`)
- 貪欲/非貪欲マッチ (`*?`, `+?`, `??`)
- エスケープシーケンス (`\.`, `\\`, `\t`, `\n`, `\r`)
- Unicodeエスケープ (`\u{XXXX}`, `\uXXXX`)
- フラグ (`i`, `m`, `s`, インライン `(?i:...)`)
- Unicode文字・絵文字
- Unicodeプロパティ (`\p{Letter}`, `\p{Number}`, `\p{Separator}`)
- 文字クラス内のUnicodeプロパティ (`[\p{L}\p{N}]`)
- 複雑な実用パターン (email, phone, URL, IP, credit card)
- エッジケース (空パターン、長文字列、境界、ゼロ幅アサーション)

### オリジナルのテスト: 21件

オリジナル実装には21件のテストがあり、JS FFI版は44件でより広範囲をカバー。

## 既知の制限

### 1. オプショナルグループのnull処理

```moonbit
// オリジナル: マッチしなかった場合 None を返す
result.get(2) // => None

// JS FFI版: null が返され、Some(null) として扱われる可能性
result.get(2) // => Some(null) または処理によってはエラー
```

### 2. エラーハンドリング

現在のJS FFI版は正規表現のコンパイルエラーを適切に捕捉していない。不正なパターンを渡すとJavaScript例外が発生する。

```moonbit
// オリジナル: RegexpError を raise
compile("a(b") // => raise RegexpError(...)

// JS FFI版: JS例外が発生
compile("a(b") // => JavaScript SyntaxError
```

### 3. フラグの互換性

一部のMoonBit固有のインラインフラグ構文がJS RegExpに直接マッピングされない:

```moonbit
// オリジナルでサポート
"(?m-m:$)"  // multilineフラグのトグル

// JS RegExpでは非対応の構文もある
```

### 4. Unicodeプロパティの変換

MoonBitの`\p{Letter}`をJSの`\p{L}`に変換しているが、すべてのプロパティ名が網羅されていない。

## 懸念点: V8サブセット問題

### 問題の本質

JS FFI版を正式採用した場合、**MoonBitのRegex実装がV8（およびJavaScriptエンジン）のサブセットになってしまう**という根本的な問題がある。

### 具体的なリスク

1. **機能の制約**
   - MoonBit独自の正規表現機能を追加できなくなる
   - JSエンジン間の差異（V8 vs SpiderMonkey vs JavaScriptCore）に依存
   - 古いブラウザでは`\p{L}`等のUnicodeプロパティが動作しない

2. **セマンティクスの不一致**
   - MoonBit Wasm版とJS版で動作が異なる可能性
   - エッジケースでの挙動差異
   - 例: バックトラッキングの挙動、Unicode正規化

3. **テスト・保守の複雑化**
   - 2つの実装を並行してテストする必要
   - JS版固有のバグが発生する可能性
   - Wasm版との一貫性を保証できない

4. **将来の拡張性**
   - MoonBitで独自の正規表現機能（例: 再帰パターン）を追加したい場合、JS版では不可能
   - JSエンジンのバージョンアップに依存

### 推奨事項

1. **用途を明確に限定する**
   - バンドルサイズが最優先のWebアプリケーション向け
   - 完全な互換性が不要なユースケース

2. **オプトイン方式**
   - デフォルトはMoonBit純粋実装
   - `moon.pkg.json`で明示的にJS FFI版を選択可能にする

3. **ドキュメント化**
   - JS FFI版の制限事項を明確に文書化
   - Wasm版との差異を説明

4. **段階的アプローチ**
   - まずUnicodeテーブルのみをJS委譲（選択肢B）
   - これにより50-100KBの削減が可能で、互換性リスクは低い

## ファイル構成

```
benches_js/regex_ffi/
├── moon.pkg.json       # パッケージ設定
├── main.mbt            # ベンチマーク用FFI関数
├── regex_compat.mbt    # 互換API実装
└── regex_test.mbt      # テストケース
```

## 実装されたFFI関数

```moonbit
// RegExp作成
extern "js" fn js_regexp_new_u(pattern : String, flags : String) -> JSRegExp

// マッチ実行
extern "js" fn js_regexp_exec_captures(re : JSRegExp, input : String) -> Array[String?]
extern "js" fn js_regexp_exec_index_impl(re : JSRegExp, input : String) -> Int

// メタ情報取得
extern "js" fn js_regexp_get_group_names(re : JSRegExp) -> Array[String]

// 文字列操作
extern "js" fn js_string_substring(s : String, start : Int, end : Int) -> String
extern "js" fn js_string_length(s : String) -> Int
```

## 結論

JS FFI版Regexは**97%のバンドルサイズ削減**と**最大80倍の高速化**を実現できるが、MoonBit実装がJavaScriptエンジンのサブセットになるという根本的なトレードオフがある。

採用する場合は:
- 明確なオプトイン方式
- 制限事項の文書化
- Wasm版との差異テスト

を整備した上で、ユーザーが用途に応じて選択できるようにすべき。
