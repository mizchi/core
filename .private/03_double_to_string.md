# Double::to_string と Ryu アルゴリズム

## 概要

`Double::to_string()` は Ryu アルゴリズムを使用して浮動小数点数を文字列に変換する。

## 実装場所

- `double/double.mbt:181-182` - メインエントリポイント
- `double/internal/ryu/ryu.mbt` - Ryu アルゴリズム本体

```moonbit
// double/double.mbt
pub fn Double::to_string(self : Double) -> String {
  @ryu.ryu_to_string(self)
}
```

## 依存関係

```
double
├── builtin
├── uint64
└── double/internal/ryu
    ├── builtin
    ├── bool
    └── array
```

**最小限の依存**: 基本的な型のみに依存しており、比較的軽量

## コードサイズ

- `ryu.mbt`: 約657行（テストを除く）
- `ryu_test.mbt`: 約426行

## Ryu アルゴリズムについて

Ryu（竜）は高速な浮動小数点数→文字列変換アルゴリズム。
- Google によって開発
- 最短かつ正確な10進数表現を生成
- 従来の実装より2-3倍高速

## JS ターゲット固有の処理

`double/moon.pkg.json` のターゲット設定：
```json
{
  "targets": {
    "exp_js.mbt": ["js"],
    "exp_nonjs.mbt": ["not", "js"],
    "log_js.mbt": ["js"],
    "log_nonjs.mbt": ["not", "js"],
    ...
  }
}
```

多くの数学関数（exp, log, pow, trig など）は JS/非JS で異なる実装を持つ。
JS では Math オブジェクトを直接使用することで最適化される可能性がある。

## サイズへの影響

Double::to_string を使用すると、以下が含まれる：
1. `double` パッケージ本体
2. `double/internal/ryu` 全体
3. `uint64` パッケージ

これは避けられない依存関係だが、JSON やその他の文字列変換機能を使用しない場合は影響なし。

## 関連パッケージ

`strconv` パッケージも `double` に依存：
```
strconv → double, uint64, string, char, array
```

文字列から数値への変換、フォーマット機能を提供。
