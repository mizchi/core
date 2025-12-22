# Set JS FFI 調査

## 概要

Map FFI と同様のアプローチで Set の JS FFI 実装を試みた。

## 実装した内容

### 1. リンクリスト版 (コミット済み)

Map FFI と同じパターンで、Entry 構造体を維持しつつ線形探索で実装。

```moonbit
priv struct Entry[K] {
  prev : Int
  mut next : Entry[K]?
  psl : Int   // 未使用
  hash : Int  // 未使用
  key : K
}

struct Set[K] {
  // ... 互換性のためのフィールド
  mut head : Entry[K]?
}
```

**結果:** テスト通過するが、バンドルサイズ削減効果は限定的。

### 2. JS Set API 版 (失敗)

JavaScript の `Set` を直接使う実装を試みた。

```moonbit
priv type JSSet

extern "js" fn js_set_new() -> JSSet =
  #| () => new Set()

// ❌ エラー: FFI function cannot have type parameters
extern "js" fn js_set_add[K](s : JSSet, key : K) -> Unit =
  #| (s, k) => s.add(k)
```

**エラー:**
```
FFI function cannot have type parameters.
```

## MoonBit FFI の制限

### 型パラメータの問題

FFI 関数は型パラメータを持てない:

```moonbit
// ❌ 不可
extern "js" fn js_set_add[K](s : JSSet, key : K) -> Unit

// ✅ 可能 (具体的な型)
extern "js" fn js_set_add_string(s : JSSet, key : String) -> Unit
```

### Map FFI が動作する理由

1. Map の主な用途は `Map[String, Json]` (JSON オブジェクト)
2. JSON stringify では JS 側で Entry 構造体を読むだけ
3. FFI 関数自体は型パラメータを使わない

```javascript
// JSON stringify FFI - 型パラメータなしで動作
let entry = v._0.head;
while (entry) {
  obj[entry.key] = convert(entry.value);  // JS側で読むだけ
  entry = entry.next;
}
```

## 結論

| アプローチ | 実現可能性 | バンドル削減 |
|------------|------------|--------------|
| リンクリスト版 | ✅ 可能 | 限定的 |
| JS Set API版 | ❌ 不可 | (理論上は大) |

**現状の対応:**
- リンクリスト版を維持
- バンドルサイズ削減効果は限定的だが、コードは簡略化されている

## 今後の可能性

1. **特定の型に特化した FFI**
   - `Set[String]` 専用の FFI を作成
   - 汎用性は失われるが、よく使われる型には効果的

2. **コンパイラ側の対応**
   - FFI の型パラメータサポート
   - これがあれば JS Set API を直接使える

## 参考: JS Set API (MDN)

```javascript
const set = new Set();
set.add(value);      // 追加
set.has(value);      // 存在確認
set.delete(value);   // 削除
set.size;            // サイズ
set.clear();         // クリア
[...set];            // 配列に変換
set.forEach(cb);     // イテレート
```

挿入順序を保持するため、MoonBit の LinkedHashSet と同じセマンティクス。
