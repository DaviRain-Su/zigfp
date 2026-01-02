# 函数工具

> 函数组合、柯里化和常用函数工具

## 概述

`function.zig` 提供了函数式编程中常用的函数操作工具，
包括组合、柯里化、恒等函数等。

## API

### compose - 函数组合

```zig
/// compose(f, g)(x) = f(g(x))
/// 先执行 g，再执行 f
pub fn compose(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (B) C,
    g: *const fn (A) B,
) *const fn (A) C
```

**使用示例**:

```zig
const double = struct { fn f(x: i32) i32 { return x * 2; } }.f;
const addOne = struct { fn f(x: i32) i32 { return x + 1; } }.f;

// compose(double, addOne)(5) = double(addOne(5)) = double(6) = 12
const composed = fp.compose(i32, i32, i32, double, addOne);
const result = composed(5);  // 12
```

### curry2 - 二元函数柯里化

```zig
/// 将 f(a, b) 转换为 f(a)(b)
pub fn curry2(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (A, B) C,
) *const fn (A) *const fn (B) C
```

**使用示例**:

```zig
fn add(a: i32, b: i32) i32 { return a + b; }

const curriedAdd = fp.curry2(i32, i32, i32, add);
const add5 = curriedAdd(5);  // 部分应用
const result = add5(3);      // 8
```

### identity - 恒等函数

```zig
/// 返回输入值本身
pub fn identity(comptime T: type) *const fn (T) T
```

**使用示例**:

```zig
const id = fp.identity(i32);
const result = id(42);  // 42

// 常用于验证 Functor 法则
assert(opt.map(fp.identity(i32)).unwrap() == opt.unwrap());
```

### constant - 常量函数

```zig
/// 忽略输入，总是返回固定值
pub fn constant(comptime T: type, comptime U: type, value: T) *const fn (U) T
```

**使用示例**:

```zig
const always42 = fp.constant(i32, []const u8, 42);
const result = always42("ignored");  // 42
```

### flip - 参数翻转

```zig
/// 交换二元函数的参数顺序
/// flip(f)(a, b) = f(b, a)
pub fn flip(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (A, B) C,
) *const fn (B, A) C
```

**使用示例**:

```zig
fn subtract(a: i32, b: i32) i32 { return a - b; }

const flipped = fp.flip(i32, i32, i32, subtract);
const result = flipped(3, 10);  // 10 - 3 = 7
```

## 组合使用

```zig
const fp = @import("zigfp");

// 构建数据处理管道
const process = fp.compose(
    Data, ValidatedData, Report,
    generateReport,
    fp.compose(Data, Data, ValidatedData, validate, parse)
);

// 使用柯里化进行部分应用
fn multiply(a: i32, b: i32) i32 { return a * b; }
const double = fp.curry2(i32, i32, i32, multiply)(2);
const triple = fp.curry2(i32, i32, i32, multiply)(3);
```

## 性能

- **零成本**: 所有函数在编译时展开
- **内联**: comptime 函数指针，完全内联

## 源码

`src/function.zig`
