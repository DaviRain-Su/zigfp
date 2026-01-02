# Memoize 记忆化

> 函数结果缓存，避免重复计算

## 概述

`Memoized(F)` 包装一个函数，缓存其调用结果。
对于相同的参数，直接返回缓存值而不重复计算。

## 类型定义

```zig
pub fn Memoized(comptime F: type) type {
    const Args = std.meta.ArgsTuple(F);
    const Ret = @typeInfo(F).Fn.return_type.?;

    return struct {
        func: F,
        cache: std.AutoHashMap(Args, Ret),
        hits: usize,
        misses: usize,
    };
}
```

## API

### init - 创建记忆化函数

```zig
/// 创建记忆化包装器
pub fn init(allocator: std.mem.Allocator, f: F) Memoized(F)
```

### call - 调用函数

```zig
/// 调用函数，使用缓存
pub fn call(self: *Self, args: Args) Ret
```

### deinit - 释放资源

```zig
/// 释放缓存
pub fn deinit(self: *Self) void
```

### 统计信息

```zig
pub fn hitRate(self: Self) f64  // 缓存命中率
pub fn stats(self: Self) Stats  // 详细统计
```

## 便捷函数

```zig
/// 创建记忆化函数
pub fn memoize(
    allocator: std.mem.Allocator,
    comptime F: type,
    f: F,
) Memoized(F)
```

## 使用示例

```zig
const fp = @import("zigfp");

// 昂贵的计算函数
fn fibonacci(n: u64) u64 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// 记忆化版本
var memoFib = fp.memoize(allocator, @TypeOf(fibonacci), fibonacci);
defer memoFib.deinit();

// 调用
const result1 = memoFib.call(.{40});  // 计算并缓存
const result2 = memoFib.call(.{40});  // 使用缓存

std.debug.print("Hit rate: {d:.2}%\n", .{memoFib.hitRate() * 100});
```

## 多参数函数

```zig
fn expensiveComputation(x: i32, y: i32, z: i32) i64 {
    // 复杂计算...
    return @as(i64, x) * y * z;
}

var memo = fp.memoize(allocator, @TypeOf(expensiveComputation), expensiveComputation);
defer memo.deinit();

const result = memo.call(.{ 10, 20, 30 });  // 缓存键是 (10, 20, 30)
```

## 与 Lazy 的区别

| 特性 | Lazy(T) | Memoize |
|------|---------|---------|
| 参数 | 无参数（thunk） | 支持任意参数 |
| 缓存 | 单个值 | 参数 -> 值 映射表 |
| 内存 | 固定 | 随调用增长 |
| 用途 | 延迟单次计算 | 缓存纯函数结果 |
| 生命周期 | 随结构 | 需要手动 deinit |

## 适用场景

**适合记忆化的函数**:
- 纯函数（相同输入总是相同输出）
- 计算密集型
- 被多次调用

**不适合的情况**:
- 有副作用
- 返回值包含指针/引用
- 参数空间巨大

## 递归函数的记忆化

对于递归函数，需要特殊处理：

```zig
// 使用全局或静态记忆化
var memoFib: ?*fp.Memoized(@TypeOf(fibonacci)) = null;

fn fibonacci(n: u64) u64 {
    if (n <= 1) return n;
    // 递归调用通过记忆化版本
    if (memoFib) |m| {
        return m.call(.{n - 1}) + m.call(.{n - 2});
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// 初始化
memoFib = &fp.memoize(allocator, @TypeOf(fibonacci), fibonacci);
```

## 性能特性

| 操作 | 复杂度 | 说明 |
|------|--------|------|
| 缓存命中 | O(1) | HashMap 查找 |
| 缓存未命中 | O(f) + O(1) | 计算 + 存储 |
| 内存 | O(n) | n = 不同参数数量 |

## 缓存策略

当前实现使用简单策略（无限增长）。
可以扩展支持：
- LRU（最近最少使用）
- 大小限制
- TTL（生存时间）

## 源码

`src/memoize.zig`
