//! Effect System 模块
//!
//! 代数效果系统，分离效果描述与处理。
//! 允许以纯函数式的方式描述副作用，然后用不同的处理器解释。
//!
//! 类似于 Haskell 的 polysemy 或 Scala 的 ZIO

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============ 效果类型定义 ============

/// 效果标记 - 用于标识不同类型的效果
pub const EffectTag = enum {
    Pure, // 纯计算
    Reader, // 读取环境
    State, // 状态操作
    Error, // 错误处理
    IO, // IO 操作
    Async, // 异步操作
    Log, // 日志
};

/// 效果描述
pub fn Effect(comptime E: type, comptime A: type) type {
    return union(enum) {
        pure_val: A,
        effect_op: EffectOp,

        const Self = @This();

        pub const EffectOp = struct {
            tag: EffectTag,
            data: E,
        };

        // ============ 构造器 ============

        /// 纯值
        pub fn pure(value: A) Self {
            return .{ .pure_val = value };
        }

        /// 创建效果操作
        pub fn perform(tag: EffectTag, data: E) Self {
            return .{
                .effect_op = .{
                    .tag = tag,
                    .data = data,
                },
            };
        }

        // ============ 查询 ============

        /// 是否是纯值
        pub fn isPure(self: Self) bool {
            return self == .pure_val;
        }

        /// 获取纯值
        pub fn getValue(self: Self) ?A {
            return switch (self) {
                .pure_val => |v| v,
                .effect_op => null,
            };
        }

        // ============ Functor ============

        /// 对结果应用函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) Effect(E, B) {
            return switch (self) {
                .pure_val => |v| Effect(E, B).pure(f(v)),
                .effect_op => |op| Effect(E, B){
                    .effect_op = .{
                        .tag = op.tag,
                        .data = op.data,
                    },
                },
            };
        }

        // ============ Monad ============

        /// 链式效果
        pub fn flatMap(self: Self, comptime B: type, f: *const fn (A) Effect(E, B)) Effect(E, B) {
            return switch (self) {
                .pure_val => |v| f(v),
                .effect_op => |op| Effect(E, B){
                    .effect_op = .{
                        .tag = op.tag,
                        .data = op.data,
                    },
                },
            };
        }

        /// 序列操作
        pub fn andThen(self: Self, comptime B: type, next: Effect(E, B)) Effect(E, B) {
            return switch (self) {
                .pure_val => next,
                .effect_op => |op| Effect(E, B){
                    .effect_op = .{
                        .tag = op.tag,
                        .data = op.data,
                    },
                },
            };
        }
    };
}

// ============ 常用效果类型 ============

/// Reader 效果 - 读取环境
pub fn ReaderEffect(comptime Env: type, comptime A: type) type {
    return struct {
        const Self = @This();

        pub const Eff = Effect(Env, A);

        /// 读取整个环境
        pub fn ask() Eff {
            return Eff.perform(.Reader, undefined);
        }

        /// 读取环境的一部分
        pub fn asks(f: *const fn (Env) A) Eff {
            _ = f;
            return Eff.perform(.Reader, undefined);
        }

        /// 运行 Reader 效果
        pub fn runReader(eff: Eff, env: Env) A {
            return switch (eff) {
                .pure_val => |v| v,
                .effect_op => |op| {
                    if (op.tag == .Reader) {
                        // 返回环境（简化实现）
                        _ = env;
                        return undefined;
                    }
                    return undefined;
                },
            };
        }
    };
}

/// State 效果 - 状态操作
pub fn StateEffect(comptime S: type, comptime A: type) type {
    return struct {
        const Self = @This();

        pub const StateOp = union(enum) {
            get: void,
            put: S,
            modify: *const fn (S) S,
        };

        pub const Eff = Effect(StateOp, A);

        /// 获取状态
        pub fn get() Effect(StateOp, S) {
            return Effect(StateOp, S).perform(.State, .{ .get = {} });
        }

        /// 设置状态
        pub fn put(s: S) Effect(StateOp, void) {
            return Effect(StateOp, void).perform(.State, .{ .put = s });
        }

        /// 修改状态
        pub fn modify(f: *const fn (S) S) Effect(StateOp, void) {
            return Effect(StateOp, void).perform(.State, .{ .modify = f });
        }

        /// 运行 State 效果
        pub fn runState(eff: Eff, initial: S) struct { value: A, state: S } {
            var state = initial;
            const value = switch (eff) {
                .pure_val => |v| v,
                .effect_op => |op| {
                    switch (op.data) {
                        .get => {},
                        .put => |s| state = s,
                        .modify => |f| state = f(state),
                    }
                    return undefined;
                },
            };
            return .{ .value = value, .state = state };
        }
    };
}

/// Error 效果 - 错误处理
pub fn ErrorEffect(comptime E: type, comptime A: type) type {
    return struct {
        const Self = @This();

        pub const Eff = Effect(E, A);

        /// 抛出错误
        pub fn throw(err: E) Eff {
            return Eff.perform(.Error, err);
        }

        /// 捕获错误
        pub fn catch_(eff: Eff, handler: *const fn (E) Eff) Eff {
            return switch (eff) {
                .pure_val => eff,
                .effect_op => |op| {
                    if (op.tag == .Error) {
                        return handler(op.data);
                    }
                    return eff;
                },
            };
        }

        /// 运行 Error 效果
        pub fn runError(eff: Eff) union(enum) { ok: A, err: E } {
            return switch (eff) {
                .pure_val => |v| .{ .ok = v },
                .effect_op => |op| {
                    if (op.tag == .Error) {
                        return .{ .err = op.data };
                    }
                    return .{ .ok = undefined };
                },
            };
        }
    };
}

/// Log 效果 - 日志记录
pub fn LogEffect(comptime A: type) type {
    return struct {
        const Self = @This();

        pub const LogOp = struct {
            level: LogLevel,
            message: []const u8,
        };

        pub const LogLevel = enum {
            Debug,
            Info,
            Warn,
            Error,
        };

        pub const Eff = Effect(LogOp, A);

        /// 记录日志
        pub fn log(level: LogLevel, message: []const u8) Effect(LogOp, void) {
            return Effect(LogOp, void).perform(.Log, .{
                .level = level,
                .message = message,
            });
        }

        /// 快捷方法
        pub fn debug(message: []const u8) Effect(LogOp, void) {
            return log(.Debug, message);
        }

        pub fn info(message: []const u8) Effect(LogOp, void) {
            return log(.Info, message);
        }

        pub fn warn(message: []const u8) Effect(LogOp, void) {
            return log(.Warn, message);
        }

        pub fn err(message: []const u8) Effect(LogOp, void) {
            return log(.Error, message);
        }
    };
}

// ============ 效果处理器 ============

/// 效果处理器接口
pub fn Handler(comptime E: type, comptime A: type, comptime R: type) type {
    return struct {
        handleFn: *const fn (EffectTag, E) R,
        pureFn: *const fn (A) R,

        const Self = @This();

        pub fn init(
            handleFn: *const fn (EffectTag, E) R,
            pureFn: *const fn (A) R,
        ) Self {
            return .{
                .handleFn = handleFn,
                .pureFn = pureFn,
            };
        }

        /// 处理效果
        pub fn handle(self: Self, eff: Effect(E, A)) R {
            return switch (eff) {
                .pure_val => |v| self.pureFn(v),
                .effect_op => |op| self.handleFn(op.tag, op.data),
            };
        }
    };
}

// ============ 组合效果 ============

/// 组合两种效果
pub fn Combined(comptime E1: type, comptime E2: type) type {
    return union(enum) {
        first: E1,
        second: E2,
    };
}

/// 效果列表
pub fn EffectList(comptime effects: []const type) type {
    if (effects.len == 0) {
        return void;
    } else if (effects.len == 1) {
        return effects[0];
    } else {
        return Combined(effects[0], EffectList(effects[1..]));
    }
}

// ============ 纯效果运行器 ============

/// 运行纯效果（无副作用）
pub fn runPure(comptime A: type, eff: Effect(void, A)) A {
    return switch (eff) {
        .pure_val => |v| v,
        .effect_op => unreachable,
    };
}

// ============ 测试 ============

test "Effect.pure" {
    const eff = Effect(void, i32).pure(42);
    try std.testing.expect(eff.isPure());
    try std.testing.expectEqual(@as(?i32, 42), eff.getValue());
}

test "Effect.perform" {
    const eff = Effect([]const u8, i32).perform(.Log, "hello");
    try std.testing.expect(!eff.isPure());
    try std.testing.expectEqual(@as(?i32, null), eff.getValue());
}

test "Effect.map" {
    const eff = Effect(void, i32).pure(21);
    const mapped = eff.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 42), mapped.getValue());
}

test "Effect.flatMap" {
    const eff = Effect(void, i32).pure(10);
    const chained = eff.flatMap(i32, struct {
        fn f(x: i32) Effect(void, i32) {
            return Effect(void, i32).pure(x + 5);
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 15), chained.getValue());
}

test "Effect.andThen" {
    const first = Effect(void, i32).pure(10);
    const second = Effect(void, i32).pure(20);
    const result = first.andThen(i32, second);

    try std.testing.expectEqual(@as(?i32, 20), result.getValue());
}

test "ErrorEffect.throw" {
    const ErrEff = ErrorEffect([]const u8, i32);
    const eff = ErrEff.throw("error!");

    try std.testing.expect(!eff.isPure());
}

test "ErrorEffect.runError with pure" {
    const ErrEff = ErrorEffect([]const u8, i32);
    const eff = ErrEff.Eff.pure(42);
    const result = ErrEff.runError(eff);

    try std.testing.expectEqual(@as(i32, 42), result.ok);
}

test "ErrorEffect.runError with error" {
    const ErrEff = ErrorEffect([]const u8, i32);
    const eff = ErrEff.throw("oops");
    const result = ErrEff.runError(eff);

    try std.testing.expectEqualStrings("oops", result.err);
}

test "ErrorEffect.catch_" {
    const ErrEff = ErrorEffect([]const u8, i32);
    const eff = ErrEff.throw("error");

    const caught = ErrEff.catch_(eff, struct {
        fn handler(_: []const u8) ErrEff.Eff {
            return ErrEff.Eff.pure(0); // 返回默认值
        }
    }.handler);

    try std.testing.expectEqual(@as(?i32, 0), caught.getValue());
}

test "LogEffect.log" {
    const LogEff = LogEffect(void);
    const eff = LogEff.info("hello");

    try std.testing.expect(!eff.isPure());
}

test "Handler.handle pure" {
    const handler = Handler(void, i32, i32).init(
        struct {
            fn handle(_: EffectTag, _: void) i32 {
                return 0;
            }
        }.handle,
        struct {
            fn pure(v: i32) i32 {
                return v * 2;
            }
        }.pure,
    );

    const eff = Effect(void, i32).pure(21);
    const result = handler.handle(eff);

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "Handler.handle effect" {
    const handler = Handler(i32, i32, i32).init(
        struct {
            fn handle(_: EffectTag, data: i32) i32 {
                return data * 10;
            }
        }.handle,
        struct {
            fn pure(v: i32) i32 {
                return v;
            }
        }.pure,
    );

    const eff = Effect(i32, i32).perform(.State, 5);
    const result = handler.handle(eff);

    try std.testing.expectEqual(@as(i32, 50), result);
}

test "runPure" {
    const eff = Effect(void, i32).pure(42);
    const result = runPure(i32, eff);

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "Effect Monad law: left identity" {
    const a: i32 = 5;
    const f = struct {
        fn func(x: i32) Effect(void, i32) {
            return Effect(void, i32).pure(x * 2);
        }
    }.func;

    const left = Effect(void, i32).pure(a).flatMap(i32, f);
    const right = f(a);

    try std.testing.expectEqual(left.getValue(), right.getValue());
}

test "Effect Monad law: right identity" {
    const m = Effect(void, i32).pure(42);

    const left = m.flatMap(i32, struct {
        fn f(x: i32) Effect(void, i32) {
            return Effect(void, i32).pure(x);
        }
    }.f);

    try std.testing.expectEqual(left.getValue(), m.getValue());
}

test "Effect Monad law: associativity" {
    const m = Effect(void, i32).pure(5);

    const f = struct {
        fn func(x: i32) Effect(void, i32) {
            return Effect(void, i32).pure(x * 2);
        }
    }.func;

    const g = struct {
        fn func(x: i32) Effect(void, i32) {
            return Effect(void, i32).pure(x + 1);
        }
    }.func;

    const left = m.flatMap(i32, f).flatMap(i32, g);
    const right = m.flatMap(i32, struct {
        fn func(x: i32) Effect(void, i32) {
            return f(x).flatMap(i32, g);
        }
    }.func);

    try std.testing.expectEqual(left.getValue(), right.getValue());
}
