# Result 类型

> 错误处理，类似 Haskell 的 `Either`、Rust 的 `Result`

## 概述

`Result(T, E)` 是一个泛型类型，表示一个操作要么成功（`ok`），要么失败（`err`）。
它是函数式编程中错误处理的核心抽象，提供类型安全的错误传播。

## 类型定义

```zig
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,
    };
}
```

## 与 Zig 原生错误处理的对比

| 特性 | Zig `E!T` | `Result(T, E)` |
|------|-----------|----------------|
| 错误类型 | 必须是 error | 任意类型 |
| map/flatMap | 无 | 有 |
| 双向映射 | 只能操作成功值 | bimap 支持 |
| 链式操作 | try 语法 | flatMap 链 |

## API

### 构造函数

```zig
// 创建成功值
const success = Result(i32, Error).ok(42);

// 创建错误值
const failure = Result(i32, Error).err(Error.NotFound);
```

### 检查方法

```zig
result.isOk();   // bool: 是否成功
result.isErr();  // bool: 是否失败
```

### 解包方法

```zig
result.unwrap();           // T: 获取成功值，失败时 panic
result.unwrapOr(default);  // T: 获取成功值或默认值
result.unwrapErr();        // E: 获取错误值，成功时 panic
```

### Functor 操作

```zig
// map: 对成功值应用函数
const mapped = result.map(String, toString);

// mapErr: 对错误值应用函数
const mappedErr = result.mapErr(String, formatError);
```

### Bifunctor 操作

```zig
// bimap: 同时对两边应用函数
const bimapped = result.bimap(
    String, FormattedError,
    toString, formatError
);
```

### Monad 操作

```zig
// flatMap: 链式操作
const chained = result.flatMap(User, fetchUser);
```

### 转换

```zig
// 转换为 Option（丢弃错误信息）
const opt = result.toOption();
```

## 使用示例

```zig
const fp = @import("zigfp");

const Error = enum { NotFound, InvalidInput, NetworkError };

// 链式错误处理
fn processUser(id: i32) fp.Result(Report, Error) {
    return fetchUser(id)
        .flatMap(Report, validateUser)
        .flatMap(Report, generateReport)
        .mapErr(Error, enhanceError);
}

// 错误恢复
const result = fetchFromCache(key)
    .flatMap(Data, process)
    .mapErr(Error, struct {
        fn recover(e: Error) Error {
            log("Cache miss: {}", e);
            return e;
        }
    }.recover);
```

## 与 Option 的转换

```zig
// Result -> Option（丢弃错误）
const opt = result.toOption();

// Option -> Result（提供错误）
const result = opt.okOr(Error.NotFound);
```

## Functor/Monad 法则

Result 对成功值满足以下法则：

### Functor 法则
1. **Identity**: `result.map(id) == result`
2. **Composition**: `result.map(f).map(g) == result.map(compose(g, f))`

### Monad 法则
1. **Left Identity**: `ok(a).flatMap(f) == f(a)`
2. **Right Identity**: `result.flatMap(ok) == result`
3. **Associativity**: `result.flatMap(f).flatMap(g) == result.flatMap(x => f(x).flatMap(g))`

### Bifunctor 法则
1. **Identity**: `result.bimap(id, id) == result`
2. **Composition**: `result.bimap(f, g).bimap(h, i) == result.bimap(compose(h, f), compose(i, g))`

## 性能

- **零成本**: tagged union，编译器优化
- **内联**: 所有操作使用 comptime 函数

## 源码

`src/result.zig`
