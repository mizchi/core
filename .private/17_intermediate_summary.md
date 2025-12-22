# JS FFI 最適化 中間サマリ

## 成果

| 指標 | Before | After | 改善 |
|------|--------|-------|------|
| バンドルサイズ (Raw) | 305KB | 94KB | **70% 削減** |
| バンドルサイズ (Gzip) | - | 13KB | - |
| json_stringify 性能 | 9.2μs | 1.8μs | **5x 高速化** |

## バンドル内訳 (regex_json: 94KB / gzip 13KB)

| パッケージ | サイズ | 割合 | 備考 |
|------------|--------|------|------|
| **Regex** | 14KB | 16% | 正規表現エンジン |
| **Builtin (Map含む)** | 15KB | 17% | Map FFI実装 + 基本型 |
| **JSON** | 5KB | 6% | parse/stringify FFI |
| **String** | 5KB | 6% | 文字列操作 |
| **Benchmark** | 3KB | 4% | テストコード |
| **Array/Double等** | 2KB | 2% | 補助型 |
| **関数本体 + Runtime** | ~50KB | ~53% | コンパイル後のロジック |

## 実装した FFI

### 1. JSON FFI (`json/`)

| ファイル | 対象 | 内容 |
|----------|------|------|
| `parse_ffi_js.mbt` | JS | JSON.parse/stringify FFI |
| `stringify_ffi_js.mbt` | JS | stringify本体 (Replacer対応) |
| `stringify_nonjs.mbt` | 非JS | オリジナル実装 |

**特徴:**
- `JSON.parse` → MoonBit `Json` enum に変換
- `JSON.stringify` → Entry linked list を走査
- `repr` フィールド対応 (Infinity等の特殊数値)

### 2. Map FFI (`builtin/`)

| ファイル | 対象 | 内容 |
|----------|------|------|
| `linked_hash_map_ffi_js.mbt` | JS | 簡略化Map実装 |
| `linked_hash_map.mbt` | 非JS | オリジナル実装 |

**特徴:**
- ハッシュテーブル → リンクリスト (線形探索)
- Entry 構造体は stringify FFI との互換性のため維持
- `capacity()` はオリジナルと同じ振る舞い

## テスト結果

| ターゲット | 結果 |
|------------|------|
| JS | 2255/2255 通過 |
| wasm-gc | 2414/2414 通過 |

## コミット履歴

1. `feat(json): add JS FFI JSON parse/stringify implementation`
2. `feat(builtin): add Map JS FFI implementation`
3. `refactor(builtin): reduce Map JS FFI code by 89 lines`
4. `fix(builtin): align Map JS FFI capacity with original implementation`
5. `fix(json): handle Number repr in JS FFI stringify`

## 技術的詳細

### JSON stringify での repr 対応

```javascript
// Number の repr フィールドを処理
case 3: return v._1 !== undefined ? '__REPR__:' + v._1 : v._0;
// 後処理でマーカーを置換
result.replace(/"__REPR__:([^"]+)"/g, '$1');
```

### Map の Entry 構造 (stringify FFI との互換性)

```moonbit
priv struct Entry[K, V] {
  prev : Int
  mut next : Entry[K, V]?
  psl : Int   // 未使用、互換性のため
  hash : Int  // 未使用、互換性のため
  key : K
  mut value : V
}
```

stringify FFI は `entry.key`, `entry.value`, `entry.next` を使用してオブジェクトを構築。

## 今後の検討事項

1. **Regex のさらなる最適化**: 14KB を占める正規表現エンジンの FFI 化
2. **String 操作の FFI 化**: 頻出操作を JS ネイティブに委譲
3. **Dead code elimination**: 未使用コードの除去
