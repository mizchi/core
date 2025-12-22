# 依存関係グラフ

## 依存レベル

### レベル0（基盤）
```
builtin ← abort
```

### レベル1（builtinのみ依存）
```
byte, char, bool, unit, int16, uint16, uint64, float, option,
result, ref, tuple, cmp, env, test, error, bytes
```

### レベル2（基本パッケージ）
```
uint, int, array, string
```

### レベル3以降（複合パッケージ）
```
double → uint64, double/internal/ryu
strconv → double, uint64, string, char, array
buffer → bytes, array, string, float, int16, uint16
json → array, char, double, float, string, strconv, option, buffer
```

## 主要パッケージの依存チェーン

### double（Double::to_string含む）
```
double
├── builtin
├── uint64
└── double/internal/ryu
    ├── builtin
    ├── bool
    └── array
```

**コード量**: 約1,083行（ryu）

### json
```
json
├── array
├── builtin
├── char
├── double  ← 重要！
├── float
├── string
├── strconv ← double経由でryuも含む
├── option
└── buffer
```

**コード量**: 約5,540行

### hashmap
```
hashmap
├── builtin
├── test
├── array
├── tuple
├── quickcheck
└── int
```

### sorted_map
```
sorted_map
├── builtin
├── option
├── tuple
├── quickcheck
├── json      ← 注意！jsonへの依存
└── string
```

**問題**: sorted_mapを使うとjsonが引き込まれる

### random
```
random
├── builtin
├── double    ← double依存
├── float
├── random/internal/random_source
│   ├── builtin
│   ├── array
│   └── bytes
└── bigint
```

## 依存関係の問題点

1. **sorted_mapがjsonに依存** - ツリーシェイクが効かない場合、サイズ増加
2. **json → double → ryu チェーン** - JSONを使うとryuが含まれる
3. **多くのパッケージがquickcheckに依存** - テスト用だが本番ビルドに含まれる可能性

## コアハブパッケージ

最も多くのパッケージが依存するもの：
1. `builtin` - 全パッケージ
2. `array` - 26パッケージ
3. `string` - 13パッケージ
4. `quickcheck` - 11パッケージ
5. `json` - 11パッケージ
6. `bytes` - 10パッケージ
7. `double` - 8パッケージ
