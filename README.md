# zigFP - Zig 函数式编程工具库

将函数式语言的核心特性带入 Zig，用函数式风格写高性能代码。

## 特性

- **类型安全**: 利用 Zig 类型系统防止运行时错误
- **零成本抽象**: 编译时展开，无运行时开销
- **Monad 支持**: Option, Result, Reader, Writer, State
- **函数组合**: compose, pipe, partial application
- **不可变更新**: Lens
- **惰性求值**: Lazy
- **记忆化**: Memoize

## 安装

将此库作为依赖添加到你的 `build.zig.zon`:

```zig
.dependencies = .{
    .zigfp = .{
        .url = "https://github.com/your-repo/zigfp/archive/main.tar.gz",
    },
},
```

在 `build.zig` 中添加:

```zig
const zigfp = b.dependency("zigfp", .{});
exe.root_module.addImport("zigfp", zigfp.module("function"));
```

## 快速开始

```zig
const fp = @import("zigfp");

// Option - 安全空值处理
const opt = fp.some(i32, 42);
const value = opt.unwrapOr(0);  // 42

// Result - 错误处理
const Error = enum { NotFound, Invalid };
const result = fp.ok(i32, Error, 42);
const v = result.unwrapOr(0);

// Pipe - 链式处理
const output = fp.Pipe(i32).init(5)
    .then(i32, double)
    .then(i32, addOne)
    .unwrap();  // 11

// compose - 函数组合
const composed = fp.compose(i32, i32, i32, double, addOne);
const r = composed(5);  // 12

// Monoid - 累积操作
const numbers = [_]i64{ 1, 2, 3, 4, 5 };
const sum = fp.sumMonoid.concat(&numbers);  // 15
```

## 模块

### 核心类型

| 模块 | 说明 |
|------|------|
| `Option(T)` | 安全空值处理，类似 Rust Option |
| `Result(T, E)` | 错误处理，类似 Rust Result |
| `Lazy(T)` | 惰性求值，带记忆化 |

### 函数工具

| 函数 | 说明 |
|------|------|
| `compose(f, g)` | 函数组合 f(g(x)) |
| `identity(T)` | 恒等函数 |
| `flip(f)` | 参数翻转 |
| `Pipe(T)` | 管道操作 |

### Monad

| 模块 | 说明 |
|------|------|
| `Reader(Env, T)` | 依赖注入模式 |
| `Writer(W, T)` | 日志累积 |
| `State(S, T)` | 状态管理 |

### 高级抽象

| 模块 | 说明 |
|------|------|
| `Lens(S, A)` | 不可变数据更新 |
| `Memoized(K, V)` | 函数记忆化 |
| `Monoid(T)` | 可组合代数结构 |
| `IO(T)` | 函数式 IO 操作 |

### 扩展模块 (v0.2.0)

| 模块 | 说明 |
|------|------|
| `Iterator` | 函数式迭代器 - map, filter, fold |
| `Validation(T, E)` | 累积错误验证 |
| `Free(F, A)` | Free Monad - 可解释 DSL |
| `Trampoline(A)` | 栈安全递归 |

## 示例

### Option 链式处理

```zig
const fp = @import("zigfp");

fn safeDiv(x: i32, y: i32) fp.Option(i32) {
    if (y == 0) return fp.none(i32);
    return fp.some(i32, @divTrunc(x, y));
}

const result = fp.some(i32, 100)
    .flatMap(i32, struct {
        fn f(x: i32) fp.Option(i32) {
            return safeDiv(x, 10);
        }
    }.f)
    .map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f)
    .unwrapOr(0);  // 20
```

### Result 错误处理

```zig
const Error = enum { NotFound, InvalidInput };

const result = fetchUser(1)
    .map([]const u8, getName)
    .mapErr([]const u8, formatError);
```

### Lens 不可变更新

```zig
const Point = struct { x: i32, y: i32 };

const pointXLens = fp.Lens(Point, i32).init(
    struct { fn get(p: Point) i32 { return p.x; } }.get,
    struct { fn set(p: Point, x: i32) Point { return .{ .x = x, .y = p.y }; } }.set,
);

const point = Point{ .x = 10, .y = 20 };
const newPoint = pointXLens.put(point, 100);  // { .x = 100, .y = 20 }
```

### Reader 依赖注入

```zig
const Config = struct { dbUrl: []const u8 };

const getDbUrl = fp.asks(Config, []const u8, struct {
    fn f(cfg: Config) []const u8 {
        return cfg.dbUrl;
    }
}.f);

const config = Config{ .dbUrl = "postgres://localhost" };
const url = getDbUrl.runReader(config);
```

### Memoize 记忆化

```zig
var memo = fp.memoize(i32, i32, allocator, fibonacci);
defer memo.deinit();

const result1 = memo.call(40);  // 计算
const result2 = memo.call(40);  // 缓存命中
```

## 测试

```bash
zig build test
```

## 性能

| 组件 | 开销 | 说明 |
|------|------|------|
| Option/Result | 零 | tagged union |
| map/flatMap | 零 | comptime 内联 |
| compose/Pipe | 零 | comptime 展开 |
| Lazy | 一次计算 | 首次求值后缓存 |
| Lens | 极低 | 结构体浅复制 |
| Memoize | 哈希查表 | O(1) 缓存查找 |

## 文档

详细文档请参阅 `docs/` 目录:

- [Option](docs/option.md)
- [Result](docs/result.md)
- [Lazy](docs/lazy.md)
- [Function](docs/function.md)
- [Pipe](docs/pipe.md)
- [Reader](docs/reader.md)
- [Writer](docs/writer.md)
- [State](docs/state.md)
- [Lens](docs/lens.md)
- [Memoize](docs/memoize.md)
- [Monoid](docs/monoid.md)
- [IO](docs/io.md)
- [Iterator](docs/iterator.md)
- [Validation](docs/validation.md)
- [Free Monad](docs/free.md)

## Zig 版本

需要 Zig 0.15.x 或更高版本。

## 许可证

MIT
