# Lazy 类型

> 惰性求值，延迟计算直到需要时

## 概述

`Lazy(T)` 是一个惰性求值包装器，存储一个计算过程而非值本身。
只有在调用 `force()` 时才执行计算，结果会被缓存（记忆化）。

## 类型定义

```zig
pub fn Lazy(comptime T: type) type {
    return struct {
        state: union(enum) {
            unevaluated: *const fn () T,
            evaluated: T,
        },
    };
}
```

## API

### 构造函数

```zig
// 从计算函数创建（未求值）
const lazy = Lazy(i32).init(struct {
    fn compute() i32 {
        return expensiveComputation();
    }
}.compute);

// 从已有值创建（已求值）
const eager = Lazy(i32).of(42);
```

### 求值

```zig
// force: 强制求值，返回结果并缓存
var lazy = Lazy(i32).init(compute);
const value = lazy.force();  // 执行计算
const again = lazy.force();  // 使用缓存
```

### Functor 操作

```zig
// map: 惰性映射
var doubled = lazy.map(i32, double);
// 此时不执行计算

const result = doubled.force();  // 现在执行
```

## 使用示例

```zig
const fp = @import("zigfp");

// 延迟昂贵计算
var config = fp.Lazy(Config).init(loadConfig);

// 只在需要时加载
if (needsConfig) {
    const cfg = config.force();
    useConfig(cfg);
}

// 惰性链式处理
var result = fp.Lazy(Data).init(fetchData)
    .map(ProcessedData, process)
    .map(Report, generateReport);

// 整个链条只在 force 时执行
const report = result.force();
```

## 记忆化特性

```zig
var lazy = Lazy(i32).init(struct {
    var callCount: usize = 0;
    fn compute() i32 {
        callCount += 1;
        return 42;
    }
}.compute);

_ = lazy.force();  // callCount = 1
_ = lazy.force();  // callCount = 1（使用缓存）
_ = lazy.force();  // callCount = 1（使用缓存）
```

## 与 Memoize 的区别

| 特性 | Lazy(T) | Memoize |
|------|---------|---------|
| 参数 | 无参数 | 支持参数 |
| 缓存 | 单值 | 参数 -> 值映射 |
| 用途 | 延迟单次计算 | 缓存函数调用 |

## Functor 法则

Lazy 满足 Functor 法则：

1. **Identity**: `lazy.map(id).force() == lazy.force()`
2. **Composition**: `lazy.map(f).map(g).force() == lazy.map(compose(g, f)).force()`

## 性能

- **首次调用**: 执行计算
- **后续调用**: O(1) 返回缓存值
- **内存**: 存储计算结果

## 源码

`src/lazy.zig`
