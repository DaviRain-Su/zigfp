//! State Monad - 状态管理
//!
//! `State(S, T)` 表示一个状态变换函数，接受初始状态 S，返回值 T 和新状态 S。
//! 用纯函数的方式处理有状态的计算。

const std = @import("std");

/// State Monad - 状态变换
pub fn State(comptime S: type, comptime T: type) type {
    return struct {
        /// 状态变换函数
        run: *const fn (S) struct { T, S },

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建 State
        pub fn init(run: *const fn (S) struct { T, S }) Self {
            return .{ .run = run };
        }

        // ============ 执行 ============

        /// 运行状态计算，返回值和最终状态
        pub fn runState(self: Self, initial: S) struct { T, S } {
            return self.run(initial);
        }

        /// 只返回值
        pub fn evalState(self: Self, initial: S) T {
            return self.run(initial)[0];
        }

        /// 只返回最终状态
        pub fn execState(self: Self, initial: S) S {
            return self.run(initial)[1];
        }
    };
}

/// 状态映射器 - 用于 map 操作
pub fn StateMapper(comptime S: type, comptime T: type, comptime U: type) type {
    return struct {
        inner: State(S, T),
        mapper: *const fn (T) U,

        const Self = @This();

        pub fn runState(self: Self, initial: S) struct { U, S } {
            const result = self.inner.run(initial);
            return .{ self.mapper(result[0]), result[1] };
        }
    };
}

/// 获取当前状态
pub fn get(comptime S: type) State(S, S) {
    return State(S, S).init(struct {
        fn run(s: S) struct { S, S } {
            return .{ s, s };
        }
    }.run);
}

/// 修改状态（使用 comptime 函数）
pub fn modify(comptime S: type, comptime f: *const fn (S) S) State(S, void) {
    return State(S, void).init(struct {
        fn run(s: S) struct { void, S } {
            return .{ {}, f(s) };
        }
    }.run);
}

/// gets - 使用函数获取状态的一部分
/// gets f = do { s <- get; pure (f s) }
pub fn gets(comptime S: type, comptime T: type, comptime f: *const fn (S) T) State(S, T) {
    return State(S, T).init(struct {
        fn run(s: S) struct { T, S } {
            return .{ f(s), s };
        }
    }.run);
}

/// put - 设置新状态，返回 void
pub fn put(comptime S: type) PutState(S) {
    return PutState(S){};
}

/// PutState - 设置状态的辅助类型
pub fn PutState(comptime S: type) type {
    return struct {
        const Self = @This();

        /// 设置状态
        pub fn set(newState: S) State(S, void) {
            _ = newState;
            // 由于 Zig 不支持闭包，需要编译时确定新状态
            @compileError("PutState.set requires closure support. Use StateWithValue instead.");
        }
    };
}

/// StateWithValue - 带预设值的状态操作
pub fn StateWithValue(comptime S: type, comptime T: type) type {
    return struct {
        value: T,
        newState: S,

        const Self = @This();

        /// 创建设置状态并返回值的操作
        pub fn init(value: T, newState: S) Self {
            return .{ .value = value, .newState = newState };
        }

        /// 运行状态操作
        pub fn runState(self: Self, _: S) struct { T, S } {
            return .{ self.value, self.newState };
        }

        /// 只返回值
        pub fn evalState(self: Self, _: S) T {
            return self.value;
        }

        /// 只返回新状态
        pub fn execState(self: Self, _: S) S {
            return self.newState;
        }
    };
}

/// putValue - 设置状态为给定值
pub fn putValue(comptime S: type, newState: S) StateWithValue(S, void) {
    return StateWithValue(S, void).init({}, newState);
}

/// modifyGet - 修改状态并返回旧值
pub fn ModifyGetState(comptime S: type) type {
    return struct {
        modifier: *const fn (S) S,

        const Self = @This();

        pub fn init(modifier: *const fn (S) S) Self {
            return .{ .modifier = modifier };
        }

        /// 运行：修改状态，返回旧值
        pub fn runState(self: Self, s: S) struct { S, S } {
            return .{ s, self.modifier(s) };
        }

        /// 只返回旧值
        pub fn evalState(self: Self, s: S) S {
            _ = self;
            return s;
        }

        /// 只返回新状态
        pub fn execState(self: Self, s: S) S {
            return self.modifier(s);
        }
    };
}

/// modifyGet - 修改状态并返回旧值
pub fn modifyGet(comptime S: type, modifier: *const fn (S) S) ModifyGetState(S) {
    return ModifyGetState(S).init(modifier);
}

/// 带值的 State - 解决闭包问题
pub fn StateValue(comptime S: type, comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// 创建带值的 State（不修改状态）
        pub fn pure(value: T) Self {
            return .{ .value = value };
        }

        /// 运行（返回值，状态不变）
        pub fn runState(self: Self, s: S) struct { T, S } {
            return .{ self.value, s };
        }

        /// 只返回值
        pub fn evalState(self: Self, _: S) T {
            return self.value;
        }

        /// 映射值
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) StateValue(S, U) {
            return StateValue(S, U).pure(f(self.value));
        }
    };
}

/// 有状态操作集合
pub fn StatefulOps(comptime S: type) type {
    return struct {
        /// 获取状态
        pub fn get_() State(S, S) {
            return get(S);
        }
    };
}

// ============ 测试 ============

test "State.init and runState" {
    const increment = State(i32, i32).init(struct {
        fn run(s: i32) struct { i32, i32 } {
            return .{ s, s + 1 };
        }
    }.run);

    const result = increment.runState(0);
    try std.testing.expectEqual(@as(i32, 0), result[0]); // 返回旧状态
    try std.testing.expectEqual(@as(i32, 1), result[1]); // 新状态
}

test "State.evalState and execState" {
    const increment = State(i32, i32).init(struct {
        fn run(s: i32) struct { i32, i32 } {
            return .{ s * 2, s + 1 };
        }
    }.run);

    try std.testing.expectEqual(@as(i32, 10), increment.evalState(5)); // 返回值
    try std.testing.expectEqual(@as(i32, 6), increment.execState(5)); // 新状态
}

test "get" {
    const getter = get(i32);

    const result = getter.runState(42);
    try std.testing.expectEqual(@as(i32, 42), result[0]);
    try std.testing.expectEqual(@as(i32, 42), result[1]);
}

test "modify" {
    const doubleState = struct {
        fn f(s: i32) i32 {
            return s * 2;
        }
    }.f;

    const double = modify(i32, doubleState);

    const result = double.runState(21);
    try std.testing.expectEqual(@as(i32, 42), result[1]);
}

test "StateValue.pure" {
    const sv = StateValue(i32, []const u8).pure("hello");

    const result = sv.runState(100);
    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqual(@as(i32, 100), result[1]);
}

test "StateValue.map" {
    const sv = StateValue(i32, i32).pure(21);
    const doubled = sv.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), doubled.evalState(0));
}

test "complex state transformation" {
    // 计数器：返回当前值，然后增加
    const counter = State(i32, i32).init(struct {
        fn run(count: i32) struct { i32, i32 } {
            return .{ count, count + 1 };
        }
    }.run);

    var s: i32 = 0;

    const r1 = counter.runState(s);
    try std.testing.expectEqual(@as(i32, 0), r1[0]);
    s = r1[1];

    const r2 = counter.runState(s);
    try std.testing.expectEqual(@as(i32, 1), r2[0]);
    s = r2[1];

    const r3 = counter.runState(s);
    try std.testing.expectEqual(@as(i32, 2), r3[0]);
    s = r3[1];

    try std.testing.expectEqual(@as(i32, 3), s);
}

test "state with struct" {
    const Counter = struct {
        count: i32,
        name: []const u8,
    };

    const incrementCounter = State(Counter, i32).init(struct {
        fn run(c: Counter) struct { i32, Counter } {
            return .{
                c.count,
                Counter{ .count = c.count + 1, .name = c.name },
            };
        }
    }.run);

    const initial = Counter{ .count = 0, .name = "test" };
    const result = incrementCounter.runState(initial);

    try std.testing.expectEqual(@as(i32, 0), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[1].count);
    try std.testing.expectEqualStrings("test", result[1].name);
}

test "gets" {
    const Counter = struct {
        count: i32,
        name: []const u8,
    };

    const getCount = struct {
        fn f(c: Counter) i32 {
            return c.count;
        }
    }.f;

    const getter = gets(Counter, i32, getCount);

    const initial = Counter{ .count = 42, .name = "test" };
    const result = getter.runState(initial);

    try std.testing.expectEqual(@as(i32, 42), result[0]);
    try std.testing.expectEqual(@as(i32, 42), result[1].count); // 状态不变
}

test "putValue" {
    const putter = putValue(i32, 100);

    const result = putter.runState(0);
    try std.testing.expectEqual(@as(i32, 100), result[1]); // 新状态
}

test "modifyGet" {
    const doubleState = struct {
        fn f(s: i32) i32 {
            return s * 2;
        }
    }.f;

    const modifier = modifyGet(i32, doubleState);

    const result = modifier.runState(21);
    try std.testing.expectEqual(@as(i32, 21), result[0]); // 旧值
    try std.testing.expectEqual(@as(i32, 42), result[1]); // 新状态
}

test "StateWithValue" {
    // 设置状态并返回一个值
    const sv = StateWithValue(i32, []const u8).init("result", 100);

    const result = sv.runState(0);
    try std.testing.expectEqualStrings("result", result[0]);
    try std.testing.expectEqual(@as(i32, 100), result[1]);
}
