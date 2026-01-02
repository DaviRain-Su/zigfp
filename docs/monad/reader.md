# Reader Monad

> 依赖注入，环境读取

## 概述

`Reader(Env, T)` 表示一个需要环境 `Env` 才能产生值 `T` 的计算。
它是实现依赖注入的函数式方式，让依赖通过组合而非参数传递。

## 类型定义

```zig
pub fn Reader(comptime Env: type, comptime T: type) type {
    return struct {
        run: *const fn (Env) T,

        pub fn runReader(self: Self, env: Env) T { ... }
    };
}
```

## 核心思想

传统依赖注入:
```zig
fn getUser(db: Database, id: i32) User { ... }
fn getEmail(db: Database, user: User) Email { ... }
// 每个函数都需要传递 db
```

Reader Monad:
```zig
fn getUser(id: i32) Reader(Database, User) { ... }
fn getEmail(user: User) Reader(Database, Email) { ... }
// db 通过 Reader 隐式传递
```

## API

### pure - 包装值

```zig
/// 将值包装为 Reader（忽略环境）
pub fn pure(v: T) Reader(Env, T)
```

### ask - 获取环境

```zig
/// 返回整个环境
pub fn ask() Reader(Env, Env)
```

### asks - 获取环境的一部分

```zig
/// 对环境应用函数
pub fn asks(f: *const fn (Env) T) Reader(Env, T)
```

### map - Functor

```zig
/// 对结果应用函数
pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Reader(Env, U)
```

### flatMap - Monad

```zig
/// 链式 Reader 操作
pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) Reader(Env, U)) Reader(Env, U)
```

### runReader - 执行

```zig
/// 提供环境，执行计算
pub fn runReader(self: Self, env: Env) T
```

## 使用示例

```zig
const fp = @import("zigfp");

// 定义环境
const Config = struct {
    db_url: []const u8,
    api_key: []const u8,
    debug: bool,
};

// 使用 Reader 定义依赖
fn getDbUrl() fp.Reader(Config, []const u8) {
    return fp.Reader(Config, []const u8).asks(struct {
        fn f(cfg: Config) []const u8 {
            return cfg.db_url;
        }
    }.f);
}

fn connectDb() fp.Reader(Config, Connection) {
    return getDbUrl().flatMap(Connection, struct {
        fn f(url: []const u8) fp.Reader(Config, Connection) {
            return fp.Reader(Config, Connection).pure(Connection.open(url));
        }
    }.f);
}

fn fetchUser(id: i32) fp.Reader(Config, User) {
    return connectDb().flatMap(User, struct {
        fn f(conn: Connection) fp.Reader(Config, User) {
            return fp.Reader(Config, User).pure(conn.query(User, id));
        }
    }.f);
}

// 运行时提供配置
const config = Config{
    .db_url = "postgres://localhost/mydb",
    .api_key = "secret",
    .debug = true,
};

const user = fetchUser(42).runReader(config);
```

## 组合多个 Reader

```zig
// 所有操作共享同一个环境
const program = fetchUser(1)
    .flatMap(Profile, fetchProfile)
    .flatMap(Report, generateReport)
    .map([]const u8, formatReport);

// 一次性提供环境
const output = program.runReader(config);
```

## Monad 法则

Reader 满足 Monad 法则：

1. **Left Identity**: `pure(a).flatMap(f).runReader(env) == f(a).runReader(env)`
2. **Right Identity**: `r.flatMap(pure).runReader(env) == r.runReader(env)`
3. **Associativity**: `r.flatMap(f).flatMap(g) == r.flatMap(x => f(x).flatMap(g))`

## 与依赖注入框架对比

| 特性 | DI 框架 | Reader Monad |
|------|---------|--------------|
| 类型安全 | 运行时 | 编译时 |
| 可测试性 | 需要 Mock | 直接替换环境 |
| 组合性 | 有限 | 完全可组合 |
| 开销 | 运行时反射 | 零成本 |

## 源码

`src/reader.zig`
