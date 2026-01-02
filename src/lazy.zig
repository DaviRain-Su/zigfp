//! Lazy 类型 - 惰性求值
//!
//! `Lazy(T)` 延迟计算直到需要时，结果会被缓存（记忆化）。

const std = @import("std");

/// Lazy 类型 - 惰性求值包装器
pub fn Lazy(comptime T: type) type {
    return struct {
        state: State,

        const Self = @This();

        const State = union(enum) {
            /// 未求值：存储计算函数
            unevaluated: *const fn () T,
            /// 已求值：缓存结果
            evaluated: T,
        };

        // ============ 构造函数 ============

        /// 从计算函数创建惰性值（未求值）
        pub fn init(f: *const fn () T) Self {
            return .{ .state = .{ .unevaluated = f } };
        }

        /// 从已有值创建（已求值状态）
        pub fn of(value: T) Self {
            return .{ .state = .{ .evaluated = value } };
        }

        // ============ 求值 ============

        /// 强制求值，返回结果并缓存
        pub fn force(self: *Self) T {
            switch (self.state) {
                .evaluated => |v| return v,
                .unevaluated => |f| {
                    const result = f();
                    self.state = .{ .evaluated = result };
                    return result;
                },
            }
        }

        /// 检查是否已求值
        pub fn isEvaluated(self: Self) bool {
            return self.state == .evaluated;
        }

        // ============ Functor 操作 ============

        /// 惰性映射（立即求值版本）
        /// 注意：由于 Zig 的限制，这个 map 会立即求值原始 Lazy
        pub fn map(self: *Self, comptime U: type, f: *const fn (T) U) Lazy(U) {
            return Lazy(U).of(f(self.force()));
        }

        // ============ Applicative 操作 ============

        /// 将值包装为已求值的 Lazy（等价于 of）
        pub fn pure(value: T) Self {
            return Self.of(value);
        }
    };
}

// ============ 测试 ============

test "Lazy.init and Lazy.of" {
    const compute = struct {
        fn f() i32 {
            return 42;
        }
    }.f;

    var lazy = Lazy(i32).init(compute);
    try std.testing.expect(!lazy.isEvaluated());

    const eager = Lazy(i32).of(42);
    try std.testing.expect(eager.isEvaluated());
}

test "Lazy.force" {
    const compute = struct {
        fn f() i32 {
            return 42;
        }
    }.f;

    var lazy = Lazy(i32).init(compute);
    try std.testing.expect(!lazy.isEvaluated());

    const value = lazy.force();
    try std.testing.expectEqual(@as(i32, 42), value);
    try std.testing.expect(lazy.isEvaluated());

    // 再次调用 force 应该返回缓存的值
    const value2 = lazy.force();
    try std.testing.expectEqual(@as(i32, 42), value2);
}

test "Lazy memoization" {
    // 使用静态变量跟踪调用次数
    const Counter = struct {
        var count: usize = 0;

        fn compute() i32 {
            count += 1;
            return 42;
        }

        fn reset() void {
            count = 0;
        }
    };

    Counter.reset();

    var lazy = Lazy(i32).init(Counter.compute);
    try std.testing.expectEqual(@as(usize, 0), Counter.count);

    _ = lazy.force();
    try std.testing.expectEqual(@as(usize, 1), Counter.count);

    _ = lazy.force();
    try std.testing.expectEqual(@as(usize, 1), Counter.count); // 仍然是 1，没有重新计算

    _ = lazy.force();
    try std.testing.expectEqual(@as(usize, 1), Counter.count); // 仍然是 1
}

test "Lazy.map" {
    const compute = struct {
        fn f() i32 {
            return 21;
        }
    }.f;

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    var lazy = Lazy(i32).init(compute);
    var doubled = lazy.map(i32, double);

    try std.testing.expectEqual(@as(i32, 42), doubled.force());
}

test "Lazy.pure" {
    const lazy = Lazy(i32).pure(42);
    try std.testing.expect(lazy.isEvaluated());
}

test "Lazy with complex computation" {
    const fibonacci = struct {
        fn compute() u64 {
            // 简单的斐波那契计算
            var a: u64 = 0;
            var b: u64 = 1;
            for (0..20) |_| {
                const temp = a + b;
                a = b;
                b = temp;
            }
            return b;
        }
    }.compute;

    var lazy = Lazy(u64).init(fibonacci);
    try std.testing.expect(!lazy.isEvaluated());

    const result = lazy.force();
    try std.testing.expectEqual(@as(u64, 10946), result);
    try std.testing.expect(lazy.isEvaluated());
}
