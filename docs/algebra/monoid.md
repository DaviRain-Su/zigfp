# Monoid

> 可组合的代数结构

## 概述

`Monoid(T)` 定义了一个类型的组合方式：一个单位元（`empty`）和一个结合操作（`combine`）。
Monoid 是函数式编程中最基础的抽象之一。

## 类型定义

```zig
pub fn Monoid(comptime T: type) type {
    return struct {
        empty: T,
        combine: *const fn (T, T) T,
    };
}
```

## Monoid 法则

任何 Monoid 必须满足：

1. **Left Identity**: `combine(empty, x) == x`
2. **Right Identity**: `combine(x, empty) == x`
3. **Associativity**: `combine(combine(x, y), z) == combine(x, combine(y, z))`

## API

### concat - 合并列表

```zig
/// 合并多个值
pub fn concat(self: Monoid(T), items: []const T) T
```

### fold - 折叠

```zig
/// 使用 Monoid 折叠可迭代结构
pub fn fold(self: Monoid(T), iter: anytype) T
```

## 内置 Monoid

### 数值 Monoid

```zig
// 加法 Monoid
pub const sumMonoid = Monoid(i64){
    .empty = 0,
    .combine = struct {
        fn f(a: i64, b: i64) i64 { return a + b; }
    }.f,
};

// 乘法 Monoid
pub const productMonoid = Monoid(i64){
    .empty = 1,
    .combine = struct {
        fn f(a: i64, b: i64) i64 { return a * b; }
    }.f,
};
```

### 布尔 Monoid

```zig
// 与 Monoid
pub const allMonoid = Monoid(bool){
    .empty = true,
    .combine = struct {
        fn f(a: bool, b: bool) bool { return a and b; }
    }.f,
};

// 或 Monoid
pub const anyMonoid = Monoid(bool){
    .empty = false,
    .combine = struct {
        fn f(a: bool, b: bool) bool { return a or b; }
    }.f,
};
```

### 字符串 Monoid

```zig
// 字符串连接（需要 allocator）
pub fn stringMonoid(allocator: Allocator) Monoid([]const u8) {
    return .{
        .empty = "",
        .combine = struct {
            fn f(a: []const u8, b: []const u8) []const u8 {
                return std.mem.concat(allocator, u8, &.{ a, b });
            }
        }.f,
    };
}
```

## 使用示例

```zig
const fp = @import("zigfp");

// 求和
const numbers = [_]i64{ 1, 2, 3, 4, 5 };
const sum = fp.sumMonoid.concat(&numbers);  // 15

// 求积
const product = fp.productMonoid.concat(&numbers);  // 120

// 全部为真
const bools = [_]bool{ true, true, false };
const all = fp.allMonoid.concat(&bools);  // false

// 任一为真
const any = fp.anyMonoid.concat(&bools);  // true
```

## 自定义 Monoid

```zig
// 最大值 Monoid
const maxMonoid = fp.Monoid(i32){
    .empty = std.math.minInt(i32),
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return @max(a, b);
        }
    }.f,
};

// 最小值 Monoid
const minMonoid = fp.Monoid(i32){
    .empty = std.math.maxInt(i32),
    .combine = struct {
        fn f(a: i32, b: i32) i32 {
            return @min(a, b);
        }
    }.f,
};

// 统计 Monoid
const Stats = struct {
    count: i64,
    sum: i64,
};

const statsMonoid = fp.Monoid(Stats){
    .empty = Stats{ .count = 0, .sum = 0 },
    .combine = struct {
        fn f(a: Stats, b: Stats) Stats {
            return Stats{
                .count = a.count + b.count,
                .sum = a.sum + b.sum,
            };
        }
    }.f,
};
```

## 与其他类型的结合

### Option 的 Monoid

当 `T` 是 Monoid 时，`Option(T)` 也是 Monoid：

```zig
pub fn optionMonoid(comptime T: type, inner: Monoid(T)) Monoid(Option(T)) {
    return .{
        .empty = Option(T).none(),
        .combine = struct {
            fn f(a: Option(T), b: Option(T)) Option(T) {
                return switch (a) {
                    .none => b,
                    .some => |va| switch (b) {
                        .none => a,
                        .some => |vb| Option(T).some(inner.combine(va, vb)),
                    },
                };
            }
        }.f,
    };
}
```

### Writer Monad 中的应用

Writer Monad 需要日志类型是 Monoid：

```zig
// Writer(W, T) 要求 W 是 Monoid
const LogWriter = fp.Writer([]const u8, i32);
// 日志通过 stringMonoid 累积
```

## 并行折叠

由于结合律，Monoid 可以安全地并行折叠：

```zig
// [a, b, c, d, e, f, g, h]
// 可以分组并行计算：
// 线程1: combine(a, b), combine(c, d)
// 线程2: combine(e, f), combine(g, h)
// 然后合并结果
```

## 常见 Monoid 总结

| 类型 | empty | combine |
|------|-------|---------|
| 数值 (Sum) | 0 | + |
| 数值 (Product) | 1 | * |
| 布尔 (All) | true | and |
| 布尔 (Any) | false | or |
| 列表 | [] | ++ |
| 字符串 | "" | concat |
| Option(T) | none | 合并内部值 |
| Map | {} | merge |
| 函数 T→T | id | compose |

## 源码

`src/monoid.zig`
