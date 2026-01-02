//! Reader Monad - 依赖注入
//!
//! `Reader(Env, T)` 表示一个需要环境 Env 才能产生值 T 的计算。
//! 用于实现依赖注入的函数式方式。

const std = @import("std");

/// Reader Monad - 环境读取
pub fn Reader(comptime Env: type, comptime T: type) type {
    return struct {
        /// 运行函数：接受环境，返回值
        run: *const fn (Env) T,

        const Self = @This();

        // ============ 构造函数 ============

        /// 包装值（忽略环境）
        pub fn pure(value: T) Self {
            _ = value;
            // 由于 Zig 不支持闭包，需要使用不同的方式
            // 这里返回一个忽略环境的函数
            return .{
                .run = struct {
                    fn f(_: Env) T {
                        // 注意：这里无法捕获 value
                        // 需要使用 ReaderWithValue 模式
                        @compileError("Reader.pure requires closure support. Use ReaderValue instead.");
                    }
                }.f,
            };
        }

        /// 创建 Reader
        pub fn init(run: *const fn (Env) T) Self {
            return .{ .run = run };
        }

        // ============ 执行 ============

        /// 提供环境，执行计算
        pub fn runReader(self: Self, env: Env) T {
            return self.run(env);
        }
    };
}

/// 带值的 Reader - 解决闭包问题
pub fn ReaderValue(comptime Env: type, comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// 创建带值的 Reader
        pub fn pure(value: T) Self {
            return .{ .value = value };
        }

        /// 执行（忽略环境，返回值）
        pub fn runReader(self: Self, _: Env) T {
            return self.value;
        }

        /// 映射值
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) ReaderValue(Env, U) {
            return ReaderValue(Env, U).pure(f(self.value));
        }
    };
}

/// Ask Reader - 返回环境本身
pub fn ask(comptime Env: type) Reader(Env, Env) {
    return Reader(Env, Env).init(struct {
        fn f(env: Env) Env {
            return env;
        }
    }.f);
}

/// Asks Reader - 对环境应用函数
pub fn asks(comptime Env: type, comptime T: type, f: *const fn (Env) T) Reader(Env, T) {
    return Reader(Env, T).init(f);
}

/// LocalReader - 在修改后的环境中运行 Reader
/// local f reader = \env -> runReader reader (f env)
pub fn LocalReader(comptime Env: type, comptime T: type) type {
    return struct {
        inner: Reader(Env, T),
        modifier: *const fn (Env) Env,

        const Self = @This();

        /// 创建 LocalReader
        pub fn init(inner: Reader(Env, T), modifier: *const fn (Env) Env) Self {
            return .{ .inner = inner, .modifier = modifier };
        }

        /// 在修改后的环境中运行
        pub fn runReader(self: Self, env: Env) T {
            return self.inner.run(self.modifier(env));
        }
    };
}

/// local - 在局部修改的环境中运行 Reader
/// 类似 Haskell 的 local :: (r -> r) -> Reader r a -> Reader r a
pub fn local(
    comptime Env: type,
    comptime T: type,
    inner: Reader(Env, T),
    modifier: *const fn (Env) Env,
) LocalReader(Env, T) {
    return LocalReader(Env, T).init(inner, modifier);
}

/// ReaderWithEnv - 带环境变换的 Reader
/// 用于从外部环境提取内部环境
pub fn ReaderWithEnv(comptime OuterEnv: type, comptime InnerEnv: type, comptime T: type) type {
    return struct {
        inner: Reader(InnerEnv, T),
        extract: *const fn (OuterEnv) InnerEnv,

        const Self = @This();

        /// 创建 ReaderWithEnv
        pub fn init(inner: Reader(InnerEnv, T), extract: *const fn (OuterEnv) InnerEnv) Self {
            return .{ .inner = inner, .extract = extract };
        }

        /// 使用外部环境运行，内部会先提取内部环境
        pub fn runReader(self: Self, outerEnv: OuterEnv) T {
            return self.inner.run(self.extract(outerEnv));
        }
    };
}

/// withReader - 使用环境提取器包装 Reader
/// 类似 Haskell 的 withReader :: (r' -> r) -> Reader r a -> Reader r' a
pub fn withReader(
    comptime OuterEnv: type,
    comptime InnerEnv: type,
    comptime T: type,
    inner: Reader(InnerEnv, T),
    extract: *const fn (OuterEnv) InnerEnv,
) ReaderWithEnv(OuterEnv, InnerEnv, T) {
    return ReaderWithEnv(OuterEnv, InnerEnv, T).init(inner, extract);
}

// ============ 测试 ============

const TestConfig = struct {
    dbUrl: []const u8,
    apiKey: []const u8,
    debug: bool,
};

test "Reader.init and runReader" {
    const getDbUrl = Reader(TestConfig, []const u8).init(struct {
        fn f(cfg: TestConfig) []const u8 {
            return cfg.dbUrl;
        }
    }.f);

    const config = TestConfig{
        .dbUrl = "postgres://localhost",
        .apiKey = "secret",
        .debug = true,
    };

    const url = getDbUrl.runReader(config);
    try std.testing.expectEqualStrings("postgres://localhost", url);
}

test "ask" {
    const askConfig = ask(TestConfig);

    const config = TestConfig{
        .dbUrl = "postgres://localhost",
        .apiKey = "secret",
        .debug = true,
    };

    const result = askConfig.runReader(config);
    try std.testing.expectEqualStrings("postgres://localhost", result.dbUrl);
    try std.testing.expect(result.debug);
}

test "asks" {
    const getApiKey = asks(TestConfig, []const u8, struct {
        fn f(cfg: TestConfig) []const u8 {
            return cfg.apiKey;
        }
    }.f);

    const config = TestConfig{
        .dbUrl = "postgres://localhost",
        .apiKey = "my-secret-key",
        .debug = false,
    };

    const key = getApiKey.runReader(config);
    try std.testing.expectEqualStrings("my-secret-key", key);
}

test "asks with transformation" {
    const isDebug = asks(TestConfig, bool, struct {
        fn f(cfg: TestConfig) bool {
            return cfg.debug;
        }
    }.f);

    const debugConfig = TestConfig{
        .dbUrl = "",
        .apiKey = "",
        .debug = true,
    };

    const prodConfig = TestConfig{
        .dbUrl = "",
        .apiKey = "",
        .debug = false,
    };

    try std.testing.expect(isDebug.runReader(debugConfig));
    try std.testing.expect(!isDebug.runReader(prodConfig));
}

test "ReaderValue.pure" {
    const reader = ReaderValue(TestConfig, i32).pure(42);

    const config = TestConfig{
        .dbUrl = "",
        .apiKey = "",
        .debug = false,
    };

    try std.testing.expectEqual(@as(i32, 42), reader.runReader(config));
}

test "ReaderValue.map" {
    const reader = ReaderValue(TestConfig, i32).pure(21);
    const doubled = reader.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const config = TestConfig{
        .dbUrl = "",
        .apiKey = "",
        .debug = false,
    };

    try std.testing.expectEqual(@as(i32, 42), doubled.runReader(config));
}

test "Reader with integer environment" {
    // 简单场景：环境是整数
    const addEnv = Reader(i32, i32).init(struct {
        fn f(env: i32) i32 {
            return env + 10;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 15), addEnv.runReader(5));
    try std.testing.expectEqual(@as(i32, 110), addEnv.runReader(100));
}

test "chained Reader operations" {
    // 组合多个 Reader 操作
    const getDbUrlLen = asks(TestConfig, usize, struct {
        fn f(cfg: TestConfig) usize {
            return cfg.dbUrl.len;
        }
    }.f);

    const config = TestConfig{
        .dbUrl = "postgres://localhost:5432/mydb",
        .apiKey = "",
        .debug = false,
    };

    const len = getDbUrlLen.runReader(config);
    try std.testing.expectEqual(@as(usize, 30), len);
}

test "local - modify environment" {
    // 使用 local 在修改后的环境中运行
    const getEnv = Reader(i32, i32).init(struct {
        fn f(env: i32) i32 {
            return env;
        }
    }.f);

    const doubleEnv = struct {
        fn f(env: i32) i32 {
            return env * 2;
        }
    }.f;

    const localReader = local(i32, i32, getEnv, doubleEnv);

    // 原环境是 5，local 会先将其变为 10
    try std.testing.expectEqual(@as(i32, 10), localReader.runReader(5));
    try std.testing.expectEqual(@as(i32, 20), localReader.runReader(10));
}

test "local with struct environment" {
    const setDebugFalse = struct {
        fn f(cfg: TestConfig) TestConfig {
            return TestConfig{
                .dbUrl = cfg.dbUrl,
                .apiKey = cfg.apiKey,
                .debug = false,
            };
        }
    }.f;

    const isDebug = Reader(TestConfig, bool).init(struct {
        fn f(cfg: TestConfig) bool {
            return cfg.debug;
        }
    }.f);

    const localReader = local(TestConfig, bool, isDebug, setDebugFalse);

    const debugConfig = TestConfig{
        .dbUrl = "",
        .apiKey = "",
        .debug = true,
    };

    // 即使传入 debug=true，local 会将其改为 false
    try std.testing.expect(!localReader.runReader(debugConfig));
}

test "withReader - environment extraction" {
    const AppConfig = struct {
        db: TestConfig,
        port: u16,
    };

    const extractDbConfig = struct {
        fn f(app: AppConfig) TestConfig {
            return app.db;
        }
    }.f;

    const getDbUrl = Reader(TestConfig, []const u8).init(struct {
        fn f(cfg: TestConfig) []const u8 {
            return cfg.dbUrl;
        }
    }.f);

    const appReader = withReader(AppConfig, TestConfig, []const u8, getDbUrl, extractDbConfig);

    const appConfig = AppConfig{
        .db = TestConfig{
            .dbUrl = "postgres://db",
            .apiKey = "key",
            .debug = false,
        },
        .port = 8080,
    };

    try std.testing.expectEqualStrings("postgres://db", appReader.runReader(appConfig));
}
