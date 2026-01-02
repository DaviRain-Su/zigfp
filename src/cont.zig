//! Continuation Monad 模块
//!
//! Continuation 是一种强大的控制流抽象，表示"剩余的计算"。
//! 由于 Zig 不支持闭包，这里提供一个基于 comptime 的简化实现。
//!
//! Cont R A = (A -> R) -> R

const std = @import("std");

/// Continuation 结果
pub fn ContResult(comptime R: type, comptime A: type) type {
    return struct {
        value: A,

        const Self = @This();

        /// 应用 continuation
        pub fn apply(self: Self, k: *const fn (A) R) R {
            return k(self.value);
        }
    };
}

/// 简化的 Continuation Monad
///
/// 由于 Zig 不支持闭包，我们使用值包装而非函数包装
pub fn Cont(comptime R: type, comptime A: type) type {
    return struct {
        value: A,

        const Self = @This();

        // ============ 构造器 ============

        /// 创建包含纯值的 Continuation
        pub fn pure(value: A) Self {
            return .{ .value = value };
        }

        // ============ 执行 ============

        /// 运行 Continuation，提供最终的 continuation 函数
        pub fn runCont(self: Self, k: *const fn (A) R) R {
            return k(self.value);
        }

        /// 获取内部值
        pub fn getValue(self: Self) A {
            return self.value;
        }

        // ============ Functor ============

        /// 对值应用函数
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) Cont(R, B) {
            return Cont(R, B).pure(f(self.value));
        }

        // ============ Monad ============

        /// 链式操作
        pub fn flatMap(self: Self, comptime B: type, f: *const fn (A) Cont(R, B)) Cont(R, B) {
            return f(self.value);
        }

        /// 序列操作，忽略第一个结果
        pub fn andThen(self: Self, comptime B: type, next: Cont(R, B)) Cont(R, B) {
            _ = self;
            return next;
        }

        /// 组合两个 Continuation 的值
        pub fn zip(self: Self, comptime B: type, other: Cont(R, B)) Cont(R, struct { A, B }) {
            return Cont(R, struct { A, B }).pure(.{ self.value, other.value });
        }
    };
}

// ============ CPS 风格函数 ============

/// CPS 风格的函数类型
pub fn CPS(comptime A: type, comptime R: type) type {
    return struct {
        runFn: *const fn (*const fn (A) R) R,

        const Self = @This();

        /// 创建 CPS 函数
        pub fn init(f: *const fn (*const fn (A) R) R) Self {
            return .{ .runFn = f };
        }

        /// 运行 CPS 函数
        pub fn run(self: Self, k: *const fn (A) R) R {
            return self.runFn(k);
        }

        /// 创建返回固定值的 CPS
        pub fn pure(comptime value: A) Self {
            return .{
                .runFn = struct {
                    fn run(k: *const fn (A) R) R {
                        return k(value);
                    }
                }.run,
            };
        }
    };
}

// ============ 控制流操作 ============

/// 提前返回 - 创建一个忽略 continuation 直接返回结果的计算
pub fn earlyReturn(comptime R: type, comptime A: type, result: R) CPS(A, R) {
    _ = result;
    return CPS(A, R).init(struct {
        fn run(_: *const fn (A) R) R {
            // 由于 Zig 限制，无法捕获 result
            return undefined;
        }
    }.run);
}

/// 条件执行
pub fn when(comptime R: type, condition: bool, thenCont: Cont(R, void), elseCont: Cont(R, void)) Cont(R, void) {
    if (condition) {
        return thenCont;
    } else {
        return elseCont;
    }
}

/// 循环执行
pub fn loop(
    comptime S: type,
    comptime R: type,
    initial: S,
    condition: *const fn (S) bool,
    body: *const fn (S) S,
    final: *const fn (S) R,
) R {
    var state = initial;
    while (condition(state)) {
        state = body(state);
    }
    return final(state);
}

// ============ Trampoline 集成 ============

/// CPS 风格的 Trampoline，用于栈安全的递归
pub fn TrampolineCPS(comptime A: type) type {
    return union(enum) {
        done_val: A,
        more_fn: struct {
            f: *const fn () TrampolineCPS(A),
        },

        const Self = @This();

        pub fn done(value: A) Self {
            return .{ .done_val = value };
        }

        pub fn more(f: *const fn () Self) Self {
            return .{ .more_fn = .{ .f = f } };
        }

        pub fn run(self: Self) A {
            var current = self;
            while (true) {
                switch (current) {
                    .done_val => |v| return v,
                    .more_fn => |m| current = m.f(),
                }
            }
        }

        pub fn isDone(self: Self) bool {
            return self == .done_val;
        }

        /// 对结果应用函数（在完成时）
        pub fn map(self: Self, f: *const fn (A) A) Self {
            switch (self) {
                .done_val => |v| return Self.done(f(v)),
                .more_fn => return self, // 保持延迟
            }
        }
    };
}

// ============ 实用工具 ============

/// 将普通函数转换为 CPS 风格
pub fn toCPS(
    comptime A: type,
    comptime B: type,
    comptime R: type,
    f: *const fn (A) B,
    a: A,
    k: *const fn (B) R,
) R {
    return k(f(a));
}

/// CPS 风格的 identity
pub fn identityCPS(comptime A: type, comptime R: type, a: A, k: *const fn (A) R) R {
    return k(a);
}

/// CPS 风格的 compose
pub fn composeCPS(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime R: type,
    f: *const fn (A) B,
    g: *const fn (B) C,
    a: A,
    k: *const fn (C) R,
) R {
    return k(g(f(a)));
}

// ============ 测试 ============

test "Cont.pure and runCont" {
    const c = Cont(i32, i32).pure(42);

    const result = c.runCont(struct {
        fn k(x: i32) i32 {
            return x * 2;
        }
    }.k);

    try std.testing.expectEqual(@as(i32, 84), result);
}

test "Cont.getValue" {
    const c = Cont(i32, i32).pure(42);
    try std.testing.expectEqual(@as(i32, 42), c.getValue());
}

test "Cont.map" {
    const c = Cont(i32, i32).pure(21);
    const mapped = c.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 42), mapped.getValue());
}

test "Cont.flatMap" {
    const c = Cont(i32, i32).pure(10);
    const chained = c.flatMap(i32, struct {
        fn f(x: i32) Cont(i32, i32) {
            return Cont(i32, i32).pure(x + 5);
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 15), chained.getValue());
}

test "Cont.andThen" {
    const first = Cont(i32, i32).pure(10);
    const second = Cont(i32, i32).pure(20);
    const result = first.andThen(i32, second);

    try std.testing.expectEqual(@as(i32, 20), result.getValue());
}

test "Cont.zip" {
    const c1 = Cont(i32, i32).pure(10);
    const c2 = Cont(i32, i32).pure(20);
    const zipped = c1.zip(i32, c2);

    const pair = zipped.getValue();
    try std.testing.expectEqual(@as(i32, 10), pair[0]);
    try std.testing.expectEqual(@as(i32, 20), pair[1]);
}

test "CPS.pure" {
    const cps = comptime CPS(i32, i32).pure(42);

    const result = cps.run(struct {
        fn k(x: i32) i32 {
            return x * 2;
        }
    }.k);

    try std.testing.expectEqual(@as(i32, 84), result);
}

test "CPS.init" {
    const cps = CPS(i32, i32).init(struct {
        fn run(k: *const fn (i32) i32) i32 {
            return k(10) + k(20);
        }
    }.run);

    const result = cps.run(struct {
        fn k(x: i32) i32 {
            return x * 2;
        }
    }.k);

    // k(10) + k(20) = 20 + 40 = 60
    try std.testing.expectEqual(@as(i32, 60), result);
}

test "when" {
    const thenBranch = Cont(i32, void).pure({});
    const elseBranch = Cont(i32, void).pure({});

    const result1 = when(i32, true, thenBranch, elseBranch);
    const result2 = when(i32, false, thenBranch, elseBranch);

    // 两个都是 void，主要测试不崩溃
    _ = result1;
    _ = result2;
}

test "loop" {
    const State = struct { sum: i32, n: i32 };

    // 计算 1 + 2 + 3 + 4 + 5
    const result = loop(
        State,
        i32,
        State{ .sum = 0, .n = 1 },
        struct {
            fn condition(s: State) bool {
                return s.n <= 5;
            }
        }.condition,
        struct {
            fn body(s: State) State {
                return State{ .sum = s.sum + s.n, .n = s.n + 1 };
            }
        }.body,
        struct {
            fn final(s: State) i32 {
                return s.sum;
            }
        }.final,
    );

    try std.testing.expectEqual(@as(i32, 15), result);
}

test "TrampolineCPS.done" {
    const t = TrampolineCPS(i32).done(42);
    try std.testing.expect(t.isDone());
    try std.testing.expectEqual(@as(i32, 42), t.run());
}

test "TrampolineCPS.more" {
    const t = TrampolineCPS(i32).more(struct {
        fn f() TrampolineCPS(i32) {
            return TrampolineCPS(i32).done(100);
        }
    }.f);

    try std.testing.expect(!t.isDone());
    try std.testing.expectEqual(@as(i32, 100), t.run());
}

test "TrampolineCPS chain" {
    const step3 = struct {
        fn f() TrampolineCPS(i32) {
            return TrampolineCPS(i32).done(42);
        }
    }.f;

    const step2 = struct {
        fn f() TrampolineCPS(i32) {
            return TrampolineCPS(i32).more(step3);
        }
    }.f;

    const t = TrampolineCPS(i32).more(step2);
    try std.testing.expectEqual(@as(i32, 42), t.run());
}

test "toCPS" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = toCPS(i32, i32, i32, double, 21, struct {
        fn k(x: i32) i32 {
            return x;
        }
    }.k);

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "identityCPS" {
    const result = identityCPS(i32, i32, 42, struct {
        fn k(x: i32) i32 {
            return x * 2;
        }
    }.k);

    try std.testing.expectEqual(@as(i32, 84), result);
}

test "composeCPS" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result = composeCPS(i32, i32, i32, i32, double, addOne, 5, struct {
        fn k(x: i32) i32 {
            return x;
        }
    }.k);

    // double(5) = 10, addOne(10) = 11
    try std.testing.expectEqual(@as(i32, 11), result);
}

test "Cont Monad law: left identity" {
    // pure a >>= f  ==  f a
    const a: i32 = 5;
    const f = struct {
        fn func(x: i32) Cont(i32, i32) {
            return Cont(i32, i32).pure(x * 2);
        }
    }.func;

    const left = Cont(i32, i32).pure(a).flatMap(i32, f);
    const right = f(a);

    try std.testing.expectEqual(left.getValue(), right.getValue());
}

test "Cont Monad law: right identity" {
    // m >>= pure  ==  m
    const m = Cont(i32, i32).pure(42);

    const left = m.flatMap(i32, struct {
        fn f(x: i32) Cont(i32, i32) {
            return Cont(i32, i32).pure(x);
        }
    }.f);

    try std.testing.expectEqual(left.getValue(), m.getValue());
}

test "Cont Monad law: associativity" {
    // (m >>= f) >>= g  ==  m >>= (\x -> f x >>= g)
    const m = Cont(i32, i32).pure(5);

    const f = struct {
        fn func(x: i32) Cont(i32, i32) {
            return Cont(i32, i32).pure(x * 2);
        }
    }.func;

    const g = struct {
        fn func(x: i32) Cont(i32, i32) {
            return Cont(i32, i32).pure(x + 1);
        }
    }.func;

    const left = m.flatMap(i32, f).flatMap(i32, g);
    const right = m.flatMap(i32, struct {
        fn func(x: i32) Cont(i32, i32) {
            return f(x).flatMap(i32, g);
        }
    }.func);

    try std.testing.expectEqual(left.getValue(), right.getValue());
}
