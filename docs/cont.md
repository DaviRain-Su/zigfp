# Continuation Monad

> 控制流抽象，表示"剩余的计算"

## 概述

Continuation 是函数式编程中强大的控制流抽象。它表示一个计算的"剩余部分"，
可以实现异常处理、协程、回溯等高级控制流。

数学定义：`Cont R A = (A -> R) -> R`

## 核心类型

### Cont(R, A)

简化的 Continuation Monad，存储值并支持函数式操作。

```zig
const fp = @import("zigfp");

// 创建 Continuation
const c = fp.Cont(i32, i32).pure(42);

// 运行 Continuation
const result = c.runCont(struct {
    fn k(x: i32) i32 { return x * 2; }
}.k);
// result = 84
```

### CPS(A, R)

CPS（Continuation-Passing Style）风格的函数包装。

```zig
// 创建 CPS
const cps = fp.CPS(i32, i32).pure(42);

// CPS 可以调用 continuation 多次
const cps2 = fp.CPS(i32, i32).init(struct {
    fn run(k: *const fn (i32) i32) i32 {
        return k(10) + k(20);  // 调用两次
    }
}.run);

const result = cps2.run(struct {
    fn k(x: i32) i32 { return x * 2; }
}.k);
// result = 20 + 40 = 60
```

## 函数式操作

### map

对结果应用函数。

```zig
const c = fp.Cont(i32, i32).pure(21);
const mapped = c.map(i32, struct {
    fn f(x: i32) i32 { return x * 2; }
}.f);
// mapped.getValue() = 42
```

### flatMap

链式操作。

```zig
const c = fp.Cont(i32, i32).pure(10);
const chained = c.flatMap(i32, struct {
    fn f(x: i32) fp.Cont(i32, i32) {
        return fp.Cont(i32, i32).pure(x + 5);
    }
}.f);
// chained.getValue() = 15
```

### andThen

序列操作，忽略第一个结果。

```zig
const first = fp.Cont(i32, i32).pure(10);
const second = fp.Cont(i32, i32).pure(20);
const result = first.andThen(i32, second);
// result.getValue() = 20
```

### zip

组合两个 Continuation 的值。

```zig
const c1 = fp.Cont(i32, i32).pure(10);
const c2 = fp.Cont(i32, i32).pure(20);
const zipped = c1.zip(i32, c2);
// zipped.getValue() = { 10, 20 }
```

## TrampolineCPS

栈安全的递归实现。

```zig
const TrampolineCPS = fp.TrampolineCPS;

// 完成
const done = TrampolineCPS(i32).done(42);

// 延迟计算
const delayed = TrampolineCPS(i32).more(struct {
    fn next() TrampolineCPS(i32) {
        return TrampolineCPS(i32).done(100);
    }
}.next);

// 运行到完成
const result = delayed.run();  // 100
```

## 控制流工具

### loop

CPS 风格的循环。

```zig
const State = struct { sum: i32, n: i32 };

// 计算 1 + 2 + 3 + 4 + 5
const result = fp.cont.loop(
    State,
    i32,
    State{ .sum = 0, .n = 1 },
    struct {
        fn condition(s: State) bool { return s.n <= 5; }
    }.condition,
    struct {
        fn body(s: State) State {
            return State{ .sum = s.sum + s.n, .n = s.n + 1 };
        }
    }.body,
    struct {
        fn final(s: State) i32 { return s.sum; }
    }.final,
);
// result = 15
```

### toCPS

将普通函数转换为 CPS 风格。

```zig
const double = struct {
    fn f(x: i32) i32 { return x * 2; }
}.f;

const result = fp.cont.toCPS(i32, i32, i32, double, 21, struct {
    fn k(x: i32) i32 { return x; }
}.k);
// result = 42
```

### composeCPS

CPS 风格的函数组合。

```zig
const double = struct { fn f(x: i32) i32 { return x * 2; } }.f;
const addOne = struct { fn f(x: i32) i32 { return x + 1; } }.f;

const result = fp.cont.composeCPS(
    i32, i32, i32, i32,
    double, addOne, 5,
    struct { fn k(x: i32) i32 { return x; } }.k
);
// double(5) = 10, addOne(10) = 11
```

## 使用场景

### 提前返回

```zig
const computation = fp.CPS(i32, i32).init(struct {
    fn run(k: *const fn (i32) i32) i32 {
        const input: i32 = -5;
        if (input < 0) {
            return 0;  // 提前返回，不调用 k
        }
        return k(input * 2);
    }
}.run);

const result = computation.run(struct {
    fn k(x: i32) i32 { return x + 100; }
}.k);
// result = 0 (提前返回)
```

### 多次调用 Continuation

```zig
// 回溯搜索
const search = fp.CPS(i32, []i32).init(struct {
    fn run(k: *const fn (i32) []i32) []i32 {
        // 尝试多个值
        var results: []i32 = undefined;
        results = k(1);  // 尝试 1
        results = k(2);  // 尝试 2
        results = k(3);  // 尝试 3
        return results;
    }
}.run);
```

## Monad 法则

Continuation Monad 满足 Monad 三法则：

```zig
// 左单位元: pure a >>= f  ==  f a
// 右单位元: m >>= pure  ==  m
// 结合律: (m >>= f) >>= g  ==  m >>= (\x -> f x >>= g)
```

## 限制

由于 Zig 不支持闭包，zigFP 的 Continuation 实现有以下限制：

1. **值捕获受限**：无法在内部函数中捕获外部变量
2. **comptime 依赖**：某些操作需要编译时已知的函数
3. **简化实现**：`Cont` 类型实际上是值包装，而非完整的 CPS 变换

## 与 Haskell 对比

| Haskell | zigFP |
|---------|-------|
| `Cont r a` | `Cont(R, A)` |
| `runCont` | `runCont` |
| `pure a` / `return a` | `Cont.pure(a)` |
| `callCC` | 受限支持 |
| `>>=` | `flatMap` |
| `>>` | `andThen` |

## 源码

`src/cont.zig`
