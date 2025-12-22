# 改善提案

## 現在の問題点まとめ

1. **Hasher のグローバル副作用（JS）**
   - 実行時に乱数シードが生成される
   - ハッシュ値が実行ごとに異なる

2. **json への広範な依存**
   - sorted_map, immut/sorted_map が json に依存
   - 不必要なコードサイズ増加

3. **依存関係の連鎖**
   - json → strconv → double → ryu
   - 意図しない依存の引き込み

## 提案1: Hasher の決定論的モード

### 現状
```moonbit
#cfg(target="js")
let seed : Int = random_seed()  // 非決定的
```

### 改善案A: コンパイル時オプション
```moonbit
#cfg(target="js", deterministic_hash)
let seed : Int = 0

#cfg(target="js", not(deterministic_hash))
let seed : Int = random_seed()
```

### 改善案B: 明示的な初期化API
```moonbit
pub fn init_hasher_seed(seed : Int) -> Unit {
  global_seed.val = seed
}
```

### 改善案C: 環境変数による制御
```javascript
// JS 側で
globalThis.__MOONBIT_HASH_SEED__ = 42
```

## 提案2: sorted_map の json 依存除去

### 現状
`sorted_map/moon.pkg.json`:
```json
{
  "import": [
    "moonbitlang/core/json",
    ...
  ]
}
```

### 改善案: test-import への移動
```json
{
  "import": [
    "moonbitlang/core/builtin",
    "moonbitlang/core/option",
    "moonbitlang/core/tuple",
    "moonbitlang/core/quickcheck",
    "moonbitlang/core/string"
  ],
  "test-import": [
    "moonbitlang/core/json"
  ]
}
```

### 確認すべき点
- json が実際のランタイムコードで使用されているか
- Show 実装が json に依存しているか

## 提案3: json パッケージの分割

### 現状
単一の大きなパッケージ（5,540行）

### 改善案
```
json/
├── types/          # 型定義のみ（軽量）
├── parse/          # パーサー
├── stringify/      # シリアライズ
└── path/           # JSONPath
```

使用例:
```moonbit
import "moonbitlang/core/json/types"      // 軽量
import "moonbitlang/core/json/parse"      // 必要な場合のみ
```

## 提案4: quickcheck 依存の見直し

多くのパッケージが quickcheck に依存しているが、本番ビルドには不要。

### 現状
```json
{
  "import": [
    "moonbitlang/core/quickcheck"
  ]
}
```

### 改善案
```json
{
  "test-import": [
    "moonbitlang/core/quickcheck"
  ]
}
```

## 提案5: ビルドサイズ監視

### CI での自動チェック
```yaml
- name: Check bundle size
  run: |
    moon build --target js
    du -sh target/js/
    # サイズが閾値を超えたら警告
```

### パッケージごとのサイズ計測
各パッケージの単体ビルドサイズを記録し、回帰を検出。

## 優先度

| 提案 | 優先度 | 影響範囲 | 難易度 |
|------|--------|----------|--------|
| sorted_map の json 依存除去 | 高 | 大 | 低 |
| quickcheck を test-import へ | 高 | 中 | 低 |
| Hasher 決定論的モード | 中 | 大 | 中 |
| json 分割 | 低 | 大 | 高 |
| ビルドサイズ監視 | 中 | - | 低 |

## 実験的確認

以下を確認することを推奨:

1. `sorted_map` から `json` への依存が実際のランタイムで使われているか
2. ツリーシェイクが正しく機能しているか
3. JSビルドの実際のサイズ
