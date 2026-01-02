# Function 模块

函数工具，提供函数组合和转换的工具。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [function.md](function.md) | `compose`, `identity`, `flip` | 函数组合工具 |
| [pipe.md](pipe.md) | `Pipe(T)` | 管道操作，链式调用 |
| [memoize.md](memoize.md) | `Memoized(K, V)` | 函数记忆化 |

## 导入方式

```zig
const function = @import("zigfp").function;

const compose = function.compose;
const Pipe = function.Pipe;
const Memoized = function.Memoized;
```

## 快速示例

### compose - 函数组合

```zig
const double = struct { fn f(x: i32) i32 { return x * 2; } }.f;
const addOne = struct { fn f(x: i32) i32 { return x + 1; } }.f;

// compose(f, g)(x) = f(g(x))
const composed = compose(i32, i32, i32, double, addOne);
const result = composed(5);  // double(addOne(5)) = 12
```

### Pipe - 管道操作

```zig
const result = Pipe(i32).init(5)
    .then(i32, double)      // 10
    .then(i32, addOne)      // 11
    .then(i32, double)      // 22
    .unwrap();
```

### Memoize - 记忆化

```zig
var memo = Memoized(i32, i64).init(allocator, fibonacci);
defer memo.deinit();

// 第一次调用会计算
const fib50 = memo.get(50);

// 第二次调用直接返回缓存结果
const fib50_cached = memo.get(50);  // O(1)
```

## 设计说明

由于 Zig 不支持运行时闭包，一些高阶函数需要使用 comptime 函数指针：

```zig
// 正确做法 - 使用命名函数
const double = struct {
    fn f(x: i32) i32 { return x * 2; }
}.f;

// 然后传递函数指针
const result = someHigherOrderFn(double);
```
