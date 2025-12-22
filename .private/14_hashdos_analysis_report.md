# Hashdos 脆弱性分析レポート

## 背景

GitHub Issue #2901 で指摘された問題:
1. **Cloudflare Workers の問題**: `random_seed()` がグローバルスコープで実行され、`crypto.getRandomValues()` がリクエストハンドラ外で呼ばれる
2. **Hashdos 脆弱性**: 固定シードにすると攻撃者がハッシュ衝突を事前計算可能

## 現状のシード実装

```moonbit
// builtin/hasher.mbt

// 非JSバックエンド: 固定シード
#cfg(not(target="js"))
let seed : Int = 0

// JSバックエンド: ランダムシード
#cfg(target="js")
let seed : Int = random_seed()

extern "js" fn random_seed() -> Int =
  #|() => {
  #|  if (globalThis.crypto?.getRandomValues) {
  #|    const array = new Uint32Array(1);
  #|    globalThis.crypto.getRandomValues(array);
  #|    return array[0] | 0;
  #|  } else {
  #|    return Math.floor(Math.random() * 0x100000000) | 0;
  #|  }
  #|}
```

**問題点**:
- `moonbitlang$core$builtin$$seed = moonbitlang$core$builtin$$random_seed();` がモジュールトップレベルで実行
- Cloudflare Workers はグローバルスコープでの非決定的操作を禁止

## バンドルサイズへの影響

random_seed 関連コード: **224 bytes** (全体 17.9KB の **1.2%**)

→ **バンドルサイズへの影響は軽微**

## Hashdos 攻撃の現実性分析

### MoonBit xxHash32 実装の特性

- ハッシュ空間: 2^32 = 4,294,967,296 値
- 測定ハッシュレート: 23 M/s (Node.js)

### 衝突生成コスト

| 衝突キー数 | 計算時間 |
|-----------|---------|
| 1 | ~3分 |
| 100 | ~5時間 |
| 1000 | ~52時間 |

### 攻撃シナリオ

1. **事前計算フェーズ** (オフライン):
   - 攻撃者は固定シード (seed=0) を知っている
   - 衝突するキーセットを計算 (52時間で1000個)

2. **攻撃フェーズ** (オンライン):
   - 衝突キーを含むリクエストを送信
   - HashMap の挿入が遅延

### Robin Hood Hashing の緩和効果

MoonBit の HashMap/Map は Robin Hood Hashing を使用:

- **通常のオープンアドレッシング**: 衝突で O(n) に劣化
- **Robin Hood Hashing**: PSL (Probe Sequence Length) を公平に再分配
  - 最悪ケースでも対数的な劣化
  - 完全な DoS は困難

## 結論

### Hashdos リスク評価: **中程度**

| 要素 | 評価 |
|-----|------|
| 事前計算コスト | 高 (52時間/1000キー) |
| 攻撃の複雑さ | 中 (シード固定なら可能) |
| 影響の深刻度 | 中 (Robin Hood で緩和) |
| 実用性 | 低〜中 (コストに見合うか疑問) |

### 推奨対策

1. **per-table seed** (推奨):
   - HashMap/Map 生成時にシードをランダム生成
   - リクエストハンドラ内で生成されるため Cloudflare Workers 互換
   - 各テーブルが異なるシードを持つため hashdos 困難

2. **遅延シード生成**:
   - グローバルスコープでの `random_seed()` 呼び出しを回避
   - 最初の HashMap 生成時にシードを生成

3. **SipHash への移行** (長期):
   - 暗号学的に安全なハッシュ関数
   - バンドルサイズは増加 (~5KB)

## 補足: 衝突検証コード

`benches_js/hashdos_test/generate_collisions.mjs` で MoonBit の xxHash32 実装を再現し、衝突生成を検証した。

```javascript
// MoonBit xxHash32 実装 (簡略版)
function xxhash32_moonbit(str, seed = 0) {
    let acc = ((seed | 0) + GPRIME5) | 0;
    for (let i = 0; i < str.length; i++) {
        const charCode = str.charCodeAt(i);
        acc = (acc + 4) | 0;
        acc = Math.imul(rotl((acc + Math.imul(charCode, GPRIME3)) | 0, 17), GPRIME4) | 0;
    }
    // avalanche finalization
    acc = acc ^ (acc >>> 15);
    acc = Math.imul(acc, GPRIMES2) | 0;
    acc = acc ^ (acc >>> 13);
    acc = Math.imul(acc, GPRIME3) | 0;
    return acc ^ (acc >>> 16);
}
```

ハッシュ値の一致を確認:
- `xxhash32("a") = 2079483668` ✓
- `xxhash32("abc") = -771846975` ✓
