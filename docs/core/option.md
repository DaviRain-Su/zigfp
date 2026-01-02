# Option 类型

> 安全空值处理，类似 Haskell 的 `Maybe`、Rust 的 `Option`

## 概述

`Option(T)` 是一个泛型类型，表示一个值要么存在（`some`），要么不存在（`none`）。
它是函数式编程中处理可空值的核心抽象，避免了空指针问题。

## 类型定义

```zig
pub fn Option(comptime T: type) type {
    return union(enum) {
        some: T,
        none,
    };
}
```

## API

### 构造函数

```zig
// 创建 some 值
const opt = Option(i32).some(42);

// 创建 none
const empty = Option(i32).none();

// 从 Zig 原生可选类型转换
const fromNullable = Option(i32).fromNullable(nullable_value);

// 便捷函数
const opt2 = some(i32, 42);
const empty2 = none(i32);
```

### 检查方法

```zig
opt.isSome();  // bool: 是否有值
opt.isNone();  // bool: 是否为空
```

### 解包方法

```zig
opt.unwrap();           // T: 获取值，none 时 panic
opt.unwrapOr(default);  // T: 获取值或默认值
opt.unwrapOrElse(f);    // T: 获取值或调用函数获取默认值
```

### Functor 操作

```zig
// map: 对内部值应用函数
const doubled = opt.map(i32, struct {
    fn f(x: i32) i32 { return x * 2; }
}.f);
```

### Monad 操作

```zig
// flatMap: 链式操作，返回 Option 的函数
const result = opt.flatMap(i32, struct {
    fn f(x: i32) Option(i32) {
        if (x > 0) return Option(i32).some(x * 2);
        return Option(i32).none();
    }
}.f);
```

### 过滤

```zig
// filter: 满足条件保留，否则返回 none
const filtered = opt.filter(struct {
    fn p(x: i32) bool { return x > 10; }
}.p);
```

### 组合操作

```zig
// zip: 组合两个 Option
const zipped = opt1.zip(i32, opt2);
// 结果: Option(struct { T, U })

// or: 如果 self 是 none，返回 other
const result = opt1.@"or"(opt2);
```

## 使用示例

```zig
const fp = @import("zigfp");

// 链式处理
const result = fp.some(i32, 42)
    .map(i32, double)
    .filter(isPositive)
    .unwrapOr(0);

// 安全除法
fn safeDiv(a: i32, b: i32) fp.Option(i32) {
    if (b == 0) return fp.none(i32);
    return fp.some(i32, @divTrunc(a, b));
}

const result = safeDiv(10, 2)
    .flatMap(i32, struct {
        fn f(x: i32) fp.Option(i32) {
            return safeDiv(x, 2);
        }
    }.f);
```

## Functor/Monad 法则

Option 满足以下法则：

### Functor 法则
1. **Identity**: `opt.map(id) == opt`
2. **Composition**: `opt.map(f).map(g) == opt.map(compose(g, f))`

### Monad 法则
1. **Left Identity**: `some(a).flatMap(f) == f(a)`
2. **Right Identity**: `opt.flatMap(some) == opt`
3. **Associativity**: `opt.flatMap(f).flatMap(g) == opt.flatMap(x => f(x).flatMap(g))`

## 性能

- **零成本**: tagged union，编译器优化
- **内联**: map/flatMap 使用 comptime 函数，完全内联

## 源码

`src/option.zig`
