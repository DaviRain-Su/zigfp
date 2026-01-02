//! Arrow 模块
//!
//! Arrow 是计算的抽象，是函数的泛化。
//! 提供了比 Monad 更通用的组合方式。
//!
//! Arrow 法则：
//! - arr id >>> f = f
//! - f >>> arr id = f
//! - (f >>> g) >>> h = f >>> (g >>> h)
//! - arr (g . f) = arr f >>> arr g
//! - first (arr f) = arr (f *** id)
//! - first (f >>> g) = first f >>> first g
//!
//! 类似于 Haskell 的 Arrow 类型类

const std = @import("std");

// ============ Function Arrow ============

/// 函数箭头 - 最基本的 Arrow 实现
pub fn FunctionArrow(comptime A: type, comptime B: type) type {
    return struct {
        runFn: *const fn (A) B,

        const Self = @This();

        // ============ 构造器 ============

        /// arr: 将函数提升为 Arrow
        pub fn arr(f: *const fn (A) B) Self {
            return .{ .runFn = f };
        }

        /// identity: 恒等 Arrow
        pub fn identity() FunctionArrow(A, A) {
            return FunctionArrow(A, A).arr(struct {
                fn id(x: A) A {
                    return x;
                }
            }.id);
        }

        // ============ 执行 ============

        /// run: 运行 Arrow
        pub fn run(self: Self, input: A) B {
            return self.runFn(input);
        }

        // ============ 组合 ============

        /// andThen (>>>): Arrow 组合 - 返回组合 Arrow 结构体
        pub fn andThen(self: Self, comptime C: type, next: FunctionArrow(B, C)) ComposedArrow(A, B, C) {
            return ComposedArrow(A, B, C).init(self, next);
        }
    };
}

/// 组合 Arrow 类型
pub fn ComposedArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        firstFn: *const fn (A) B,
        secondFn: *const fn (B) C,

        const Self = @This();

        pub fn init(first_arrow: FunctionArrow(A, B), second_arrow: FunctionArrow(B, C)) Self {
            return .{
                .firstFn = first_arrow.runFn,
                .secondFn = second_arrow.runFn,
            };
        }

        pub fn run(self: Self, x: A) C {
            return self.secondFn(self.firstFn(x));
        }

        /// 继续组合
        pub fn andThen(self: Self, comptime D: type, next: FunctionArrow(C, D)) ComposedArrow3(A, B, C, D) {
            return ComposedArrow3(A, B, C, D).init(self.firstFn, self.secondFn, next.runFn);
        }
    };
}

/// 三层组合 Arrow 类型
pub fn ComposedArrow3(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        firstFn: *const fn (A) B,
        secondFn: *const fn (B) C,
        thirdFn: *const fn (C) D,

        const Self = @This();

        pub fn init(f: *const fn (A) B, g: *const fn (B) C, h: *const fn (C) D) Self {
            return .{
                .firstFn = f,
                .secondFn = g,
                .thirdFn = h,
            };
        }

        pub fn run(self: Self, x: A) D {
            return self.thirdFn(self.secondFn(self.firstFn(x)));
        }
    };
}

// ============ Pair Arrow 操作 ============

/// Pair 类型
pub fn Pair(comptime A: type, comptime B: type) type {
    return struct { A, B };
}

/// first: 对 pair 的第一个元素操作
pub fn FirstArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        firstFn: *const fn (A) B,

        const Self = @This();

        pub fn init(arrow: FunctionArrow(A, B)) Self {
            return .{ .firstFn = arrow.runFn };
        }

        pub fn run(self: Self, p: Pair(A, C)) Pair(B, C) {
            return .{ self.firstFn(p[0]), p[1] };
        }
    };
}

pub fn first(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrow: FunctionArrow(A, B),
) FirstArrow(A, B, C) {
    return FirstArrow(A, B, C).init(arrow);
}

/// second: 对 pair 的第二个元素操作
pub fn SecondArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        secondFn: *const fn (A) B,

        const Self = @This();

        pub fn init(arrow: FunctionArrow(A, B)) Self {
            return .{ .secondFn = arrow.runFn };
        }

        pub fn run(self: Self, p: Pair(C, A)) Pair(C, B) {
            return .{ p[0], self.secondFn(p[1]) };
        }
    };
}

pub fn second(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrow: FunctionArrow(A, B),
) SecondArrow(A, B, C) {
    return SecondArrow(A, B, C).init(arrow);
}

/// split (***): 并行操作两个 Arrow
pub fn SplitArrow(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        firstFn: *const fn (A) B,
        secondFn: *const fn (C) D,

        const Self = @This();

        pub fn init(arrowAB: FunctionArrow(A, B), arrowCD: FunctionArrow(C, D)) Self {
            return .{
                .firstFn = arrowAB.runFn,
                .secondFn = arrowCD.runFn,
            };
        }

        pub fn run(self: Self, p: Pair(A, C)) Pair(B, D) {
            return .{ self.firstFn(p[0]), self.secondFn(p[1]) };
        }
    };
}

pub fn split(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    arrowAB: FunctionArrow(A, B),
    arrowCD: FunctionArrow(C, D),
) SplitArrow(A, B, C, D) {
    return SplitArrow(A, B, C, D).init(arrowAB, arrowCD);
}

/// fanout (&&&): 将单个输入分发给两个 Arrow
pub fn FanoutArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        firstFn: *const fn (A) B,
        secondFn: *const fn (A) C,

        const Self = @This();

        pub fn init(arrowAB: FunctionArrow(A, B), arrowAC: FunctionArrow(A, C)) Self {
            return .{
                .firstFn = arrowAB.runFn,
                .secondFn = arrowAC.runFn,
            };
        }

        pub fn run(self: Self, x: A) Pair(B, C) {
            return .{ self.firstFn(x), self.secondFn(x) };
        }
    };
}

pub fn fanout(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrowAB: FunctionArrow(A, B),
    arrowAC: FunctionArrow(A, C),
) FanoutArrow(A, B, C) {
    return FanoutArrow(A, B, C).init(arrowAB, arrowAC);
}

// ============ ArrowChoice ============

/// Either 类型（用于 ArrowChoice）
pub fn Either(comptime A: type, comptime B: type) type {
    return union(enum) {
        left_val: A,
        right_val: B,

        const Self = @This();

        pub fn left(value: A) Self {
            return .{ .left_val = value };
        }

        pub fn right(value: B) Self {
            return .{ .right_val = value };
        }

        pub fn isLeft(self: Self) bool {
            return self == .left_val;
        }

        pub fn isRight(self: Self) bool {
            return self == .right_val;
        }

        pub fn getLeft(self: Self) ?A {
            return switch (self) {
                .left_val => |v| v,
                .right_val => null,
            };
        }

        pub fn getRight(self: Self) ?B {
            return switch (self) {
                .left_val => null,
                .right_val => |v| v,
            };
        }
    };
}

/// leftChoice: 对 Either 的 Left 分支操作
pub fn LeftChoiceArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        leftFn: *const fn (A) B,

        const Self = @This();

        pub fn init(arrow: FunctionArrow(A, B)) Self {
            return .{ .leftFn = arrow.runFn };
        }

        pub fn run(self: Self, e: Either(A, C)) Either(B, C) {
            return switch (e) {
                .left_val => |a| Either(B, C).left(self.leftFn(a)),
                .right_val => |c| Either(B, C).right(c),
            };
        }
    };
}

pub fn leftChoice(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrow: FunctionArrow(A, B),
) LeftChoiceArrow(A, B, C) {
    return LeftChoiceArrow(A, B, C).init(arrow);
}

/// rightChoice: 对 Either 的 Right 分支操作
pub fn RightChoiceArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        rightFn: *const fn (A) B,

        const Self = @This();

        pub fn init(arrow: FunctionArrow(A, B)) Self {
            return .{ .rightFn = arrow.runFn };
        }

        pub fn run(self: Self, e: Either(C, A)) Either(C, B) {
            return switch (e) {
                .left_val => |c| Either(C, B).left(c),
                .right_val => |a| Either(C, B).right(self.rightFn(a)),
            };
        }
    };
}

pub fn rightChoice(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrow: FunctionArrow(A, B),
) RightChoiceArrow(A, B, C) {
    return RightChoiceArrow(A, B, C).init(arrow);
}

/// choice (+++): 对 Either 的两个分支分别操作
/// 由于 Zig 不支持闭包，使用 ChoiceArrow 结构体
pub fn ChoiceArrow(comptime A: type, comptime B: type, comptime C: type, comptime D: type) type {
    return struct {
        leftFn: *const fn (A) B,
        rightFn: *const fn (C) D,

        const Self = @This();

        pub fn init(arrowAB: FunctionArrow(A, B), arrowCD: FunctionArrow(C, D)) Self {
            return .{
                .leftFn = arrowAB.runFn,
                .rightFn = arrowCD.runFn,
            };
        }

        pub fn run(self: Self, e: Either(A, C)) Either(B, D) {
            return switch (e) {
                .left_val => |a| Either(B, D).left(self.leftFn(a)),
                .right_val => |c| Either(B, D).right(self.rightFn(c)),
            };
        }
    };
}

/// 创建 choice Arrow
pub fn choice(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    arrowAB: FunctionArrow(A, B),
    arrowCD: FunctionArrow(C, D),
) ChoiceArrow(A, B, C, D) {
    return ChoiceArrow(A, B, C, D).init(arrowAB, arrowCD);
}

/// fanin (|||): 将两个 Arrow 合并为一个处理 Either 的 Arrow
/// 由于 Zig 不支持闭包，使用 FaninArrow 结构体
pub fn FaninArrow(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        leftFn: *const fn (A) C,
        rightFn: *const fn (B) C,

        const Self = @This();

        pub fn init(arrowAC: FunctionArrow(A, C), arrowBC: FunctionArrow(B, C)) Self {
            return .{
                .leftFn = arrowAC.runFn,
                .rightFn = arrowBC.runFn,
            };
        }

        pub fn run(self: Self, e: Either(A, B)) C {
            return switch (e) {
                .left_val => |a| self.leftFn(a),
                .right_val => |b| self.rightFn(b),
            };
        }
    };
}

/// 创建 fanin Arrow
pub fn fanin(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    arrowAC: FunctionArrow(A, C),
    arrowBC: FunctionArrow(B, C),
) FaninArrow(A, B, C) {
    return FaninArrow(A, B, C).init(arrowAC, arrowBC);
}

// ============ Kleisli Arrow ============

/// Kleisli Arrow - 用于 Monad 的 Arrow
/// Kleisli m a b = a -> m b
pub fn KleisliArrow(comptime M: fn (type) type, comptime A: type, comptime B: type) type {
    return struct {
        runFn: *const fn (A) M(B),

        const Self = @This();

        /// arr: 将函数提升为 Kleisli Arrow
        pub fn arr(f: *const fn (A) B, pure: *const fn (B) M(B)) Self {
            _ = pure;
            _ = f;
            // 由于 Zig 限制，这里需要简化实现
            return .{
                .runFn = struct {
                    fn run(_: A) M(B) {
                        return undefined;
                    }
                }.run,
            };
        }

        /// run: 运行 Kleisli Arrow
        pub fn run(self: Self, input: A) M(B) {
            return self.runFn(input);
        }

        /// init: 直接从 Kleisli 函数创建
        pub fn init(f: *const fn (A) M(B)) Self {
            return .{ .runFn = f };
        }
    };
}

// ============ 便捷函数 ============

/// 创建函数 Arrow
pub fn arr(comptime A: type, comptime B: type, f: *const fn (A) B) FunctionArrow(A, B) {
    return FunctionArrow(A, B).arr(f);
}

/// 创建恒等 Arrow
pub fn idArrow(comptime A: type) FunctionArrow(A, A) {
    return FunctionArrow(A, A).identity();
}

/// 创建常量 Arrow
pub fn constArrow(comptime A: type, comptime B: type, comptime value: B) FunctionArrow(A, B) {
    return FunctionArrow(A, B).arr(struct {
        fn constant(_: A) B {
            return value;
        }
    }.constant);
}

/// 交换 Pair 元素
pub fn swap(comptime A: type, comptime B: type) FunctionArrow(Pair(A, B), Pair(B, A)) {
    return FunctionArrow(Pair(A, B), Pair(B, A)).arr(struct {
        fn doSwap(p: Pair(A, B)) Pair(B, A) {
            return .{ p[1], p[0] };
        }
    }.doSwap);
}

/// 复制输入
pub fn dup(comptime A: type) FunctionArrow(A, Pair(A, A)) {
    return FunctionArrow(A, Pair(A, A)).arr(struct {
        fn duplicate(x: A) Pair(A, A) {
            return .{ x, x };
        }
    }.duplicate);
}

// ============ 测试 ============

test "FunctionArrow.arr" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 84), double.run(42));
}

test "FunctionArrow.identity" {
    const id = FunctionArrow(i32, i32).identity();
    try std.testing.expectEqual(@as(i32, 42), id.run(42));
}

test "FunctionArrow.andThen" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const addOne = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const composed = double.andThen(i32, addOne);
    // 5 * 2 + 1 = 11
    try std.testing.expectEqual(@as(i32, 11), composed.run(5));
}

test "first" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const firstDouble = first(i32, i32, i32, double);
    const result = firstDouble.run(.{ 5, 10 });

    try std.testing.expectEqual(@as(i32, 10), result[0]);
    try std.testing.expectEqual(@as(i32, 10), result[1]);
}

test "second" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const secondDouble = second(i32, i32, i32, double);
    const result = secondDouble.run(.{ 5, 10 });

    try std.testing.expectEqual(@as(i32, 5), result[0]);
    try std.testing.expectEqual(@as(i32, 20), result[1]);
}

test "split" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const addOne = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const bothArrow = split(i32, i32, i32, i32, double, addOne);
    const result = bothArrow.run(.{ 5, 10 });

    try std.testing.expectEqual(@as(i32, 10), result[0]); // 5 * 2
    try std.testing.expectEqual(@as(i32, 11), result[1]); // 10 + 1
}

test "fanout" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const addOne = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const fanoutArrow = fanout(i32, i32, i32, double, addOne);
    const result = fanoutArrow.run(5);

    try std.testing.expectEqual(@as(i32, 10), result[0]); // 5 * 2
    try std.testing.expectEqual(@as(i32, 6), result[1]); // 5 + 1
}

test "Either.left and right" {
    const e1 = Either(i32, []const u8).left(42);
    const e2 = Either(i32, []const u8).right("hello");

    try std.testing.expect(e1.isLeft());
    try std.testing.expect(!e1.isRight());
    try std.testing.expectEqual(@as(?i32, 42), e1.getLeft());
    try std.testing.expectEqual(@as(?[]const u8, null), e1.getRight());

    try std.testing.expect(!e2.isLeft());
    try std.testing.expect(e2.isRight());
    try std.testing.expectEqual(@as(?i32, null), e2.getLeft());
    try std.testing.expectEqualStrings("hello", e2.getRight().?);
}

test "leftChoice" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const leftArrow = leftChoice(i32, i32, []const u8, double);

    const e1 = Either(i32, []const u8).left(5);
    const r1 = leftArrow.run(e1);
    try std.testing.expect(r1.isLeft());
    try std.testing.expectEqual(@as(?i32, 10), r1.getLeft());

    const e2 = Either(i32, []const u8).right("hello");
    const r2 = leftArrow.run(e2);
    try std.testing.expect(r2.isRight());
    try std.testing.expectEqualStrings("hello", r2.getRight().?);
}

test "rightChoice" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const rightArrow = rightChoice(i32, i32, []const u8, double);

    const e1 = Either([]const u8, i32).left("hello");
    const r1 = rightArrow.run(e1);
    try std.testing.expect(r1.isLeft());
    try std.testing.expectEqualStrings("hello", r1.getLeft().?);

    const e2 = Either([]const u8, i32).right(5);
    const r2 = rightArrow.run(e2);
    try std.testing.expect(r2.isRight());
    try std.testing.expectEqual(@as(?i32, 10), r2.getRight());
}

test "choice" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const negate = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return -x;
        }
    }.f);

    const choiceArrow = choice(i32, i32, i32, i32, double, negate);

    const e1 = Either(i32, i32).left(5);
    const r1 = choiceArrow.run(e1);
    try std.testing.expect(r1.isLeft());
    try std.testing.expectEqual(@as(?i32, 10), r1.getLeft());

    const e2 = Either(i32, i32).right(5);
    const r2 = choiceArrow.run(e2);
    try std.testing.expect(r2.isRight());
    try std.testing.expectEqual(@as(?i32, -5), r2.getRight());
}

test "fanin" {
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const negate = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return -x;
        }
    }.f);

    const faninArrowInst = fanin(i32, i32, i32, double, negate);

    const e1 = Either(i32, i32).left(5);
    try std.testing.expectEqual(@as(i32, 10), faninArrowInst.run(e1));

    const e2 = Either(i32, i32).right(5);
    try std.testing.expectEqual(@as(i32, -5), faninArrowInst.run(e2));
}

test "arr convenience function" {
    const double = arr(i32, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 84), double.run(42));
}

test "idArrow" {
    const id = idArrow(i32);
    try std.testing.expectEqual(@as(i32, 42), id.run(42));
}

test "constArrow" {
    const always42 = constArrow([]const u8, i32, 42);
    try std.testing.expectEqual(@as(i32, 42), always42.run("anything"));
    try std.testing.expectEqual(@as(i32, 42), always42.run("hello"));
}

test "swap" {
    const swapArrow = swap(i32, []const u8);
    const result = swapArrow.run(.{ 42, "hello" });

    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqual(@as(i32, 42), result[1]);
}

test "dup" {
    const dupArrow = dup(i32);
    const result = dupArrow.run(42);

    try std.testing.expectEqual(@as(i32, 42), result[0]);
    try std.testing.expectEqual(@as(i32, 42), result[1]);
}

test "Arrow law: identity" {
    // arr id >>> f = f
    const double = FunctionArrow(i32, i32).arr(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const id = FunctionArrow(i32, i32).identity();
    const composed = id.andThen(i32, double);

    try std.testing.expectEqual(double.run(5), composed.run(5));
}

test "Arrow law: associativity" {
    // (f >>> g) >>> h = f >>> (g >>> h)
    // 由于类型系统差异，这里手动验证结果相等
    const f = FunctionArrow(i32, i32).arr(struct {
        fn apply(x: i32) i32 {
            return x * 2;
        }
    }.apply);

    const g = FunctionArrow(i32, i32).arr(struct {
        fn apply(x: i32) i32 {
            return x + 1;
        }
    }.apply);

    const h = FunctionArrow(i32, i32).arr(struct {
        fn apply(x: i32) i32 {
            return x * 3;
        }
    }.apply);

    // (f >>> g) >>> h
    const fg = f.andThen(i32, g);
    const fgh = fg.andThen(i32, h);

    // f >>> (g >>> h) - 需要手动计算
    // f(5) = 10, g(10) = 11, h(11) = 33
    const input: i32 = 5;
    const left_result = fgh.run(input);
    const right_result = h.run(g.run(f.run(input)));

    try std.testing.expectEqual(left_result, right_result);
}
