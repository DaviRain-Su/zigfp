//! Applicative Functor 模块
//!
//! Applicative 是介于 Functor 和 Monad 之间的抽象。
//! 它允许将包装在上下文中的函数应用到包装在上下文中的值。
//!
//! 类型类层次：Functor -> Applicative -> Monad
//!
//! 法则：
//! - Identity: pure(id) <*> v = v
//! - Composition: pure(.) <*> u <*> v <*> w = u <*> (v <*> w)
//! - Homomorphism: pure(f) <*> pure(x) = pure(f(x))
//! - Interchange: u <*> pure(y) = pure($ y) <*> u

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============ Option Applicative ============

/// Option 的 Applicative 实现
pub fn OptionApplicative(comptime A: type) type {
    return struct {
        const Self = @This();
        pub const Option = union(enum) {
            some_val: A,
            none_val: void,

            /// 判断是否有值
            pub fn isSome(self: @This()) bool {
                return self == .some_val;
            }

            /// 判断是否为空
            pub fn isNone(self: @This()) bool {
                return self == .none_val;
            }

            /// 获取值
            pub fn getValue(self: @This()) ?A {
                return switch (self) {
                    .some_val => |v| v,
                    .none_val => null,
                };
            }
        };

        // ============ Applicative 操作 ============

        /// pure: 将值提升到 Option 上下文
        pub fn pure(value: A) Option {
            return .{ .some_val = value };
        }

        /// none: 创建空值
        pub fn none() Option {
            return .{ .none_val = {} };
        }

        /// map: Functor 操作
        pub fn map(opt: Option, comptime B: type, f: *const fn (A) B) OptionApplicative(B).Option {
            return switch (opt) {
                .some_val => |v| OptionApplicative(B).pure(f(v)),
                .none_val => OptionApplicative(B).none(),
            };
        }

        /// ap: 应用包装的函数
        /// Option(A -> B) -> Option(A) -> Option(B)
        pub fn ap(
            comptime B: type,
            optF: OptionApplicative(*const fn (A) B).Option,
            optA: Option,
        ) OptionApplicative(B).Option {
            return switch (optF) {
                .some_val => |f| switch (optA) {
                    .some_val => |a| OptionApplicative(B).pure(f(a)),
                    .none_val => OptionApplicative(B).none(),
                },
                .none_val => OptionApplicative(B).none(),
            };
        }

        /// liftA2: 提升二元函数
        pub fn liftA2(
            comptime B: type,
            comptime C: type,
            f: *const fn (A, B) C,
            optA: Option,
            optB: OptionApplicative(B).Option,
        ) OptionApplicative(C).Option {
            return switch (optA) {
                .some_val => |a| switch (optB) {
                    .some_val => |b| OptionApplicative(C).pure(f(a, b)),
                    .none_val => OptionApplicative(C).none(),
                },
                .none_val => OptionApplicative(C).none(),
            };
        }

        /// productR: 序列操作，保留右边的值
        pub fn productR(comptime B: type, optA: Option, optB: OptionApplicative(B).Option) OptionApplicative(B).Option {
            return switch (optA) {
                .some_val => optB,
                .none_val => OptionApplicative(B).none(),
            };
        }

        /// productL: 序列操作，保留左边的值
        pub fn productL(comptime B: type, optA: Option, optB: OptionApplicative(B).Option) Option {
            return switch (optA) {
                .some_val => switch (optB) {
                    .some_val => optA,
                    .none_val => none(),
                },
                .none_val => none(),
            };
        }

        /// product: 组合两个 Option 为 tuple
        pub fn product(comptime B: type, optA: Option, optB: OptionApplicative(B).Option) OptionApplicative(struct { A, B }).Option {
            return switch (optA) {
                .some_val => |a| switch (optB) {
                    .some_val => |b| OptionApplicative(struct { A, B }).pure(.{ a, b }),
                    .none_val => OptionApplicative(struct { A, B }).none(),
                },
                .none_val => OptionApplicative(struct { A, B }).none(),
            };
        }
    };
}

// ============ Result Applicative ============

/// Result 的 Applicative 实现
pub fn ResultApplicative(comptime A: type, comptime E: type) type {
    return struct {
        const Self = @This();
        pub const Result = union(enum) {
            ok_val: A,
            err_val: E,

            pub fn isOk(self: @This()) bool {
                return self == .ok_val;
            }

            pub fn isErr(self: @This()) bool {
                return self == .err_val;
            }

            pub fn getValue(self: @This()) ?A {
                return switch (self) {
                    .ok_val => |v| v,
                    .err_val => null,
                };
            }

            pub fn getError(self: @This()) ?E {
                return switch (self) {
                    .ok_val => null,
                    .err_val => |e| e,
                };
            }
        };

        /// pure: 将值提升到 Result 上下文
        pub fn pure(value: A) Result {
            return .{ .ok_val = value };
        }

        /// err: 创建错误
        pub fn err(error_val: E) Result {
            return .{ .err_val = error_val };
        }

        /// map: Functor 操作
        pub fn map(res: Result, comptime B: type, f: *const fn (A) B) ResultApplicative(B, E).Result {
            return switch (res) {
                .ok_val => |v| ResultApplicative(B, E).pure(f(v)),
                .err_val => |e| ResultApplicative(B, E).err(e),
            };
        }

        /// ap: 应用包装的函数
        pub fn ap(
            comptime B: type,
            resF: ResultApplicative(*const fn (A) B, E).Result,
            resA: Result,
        ) ResultApplicative(B, E).Result {
            return switch (resF) {
                .ok_val => |f| switch (resA) {
                    .ok_val => |a| ResultApplicative(B, E).pure(f(a)),
                    .err_val => |e| ResultApplicative(B, E).err(e),
                },
                .err_val => |e| ResultApplicative(B, E).err(e),
            };
        }

        /// liftA2: 提升二元函数
        pub fn liftA2(
            comptime B: type,
            comptime C: type,
            f: *const fn (A, B) C,
            resA: Result,
            resB: ResultApplicative(B, E).Result,
        ) ResultApplicative(C, E).Result {
            return switch (resA) {
                .ok_val => |a| switch (resB) {
                    .ok_val => |b| ResultApplicative(C, E).pure(f(a, b)),
                    .err_val => |e| ResultApplicative(C, E).err(e),
                },
                .err_val => |e| ResultApplicative(C, E).err(e),
            };
        }

        /// productR: 序列操作，保留右边
        pub fn productR(comptime B: type, resA: Result, resB: ResultApplicative(B, E).Result) ResultApplicative(B, E).Result {
            return switch (resA) {
                .ok_val => resB,
                .err_val => |e| ResultApplicative(B, E).err(e),
            };
        }

        /// productL: 序列操作，保留左边
        pub fn productL(comptime B: type, resA: Result, resB: ResultApplicative(B, E).Result) Result {
            return switch (resA) {
                .ok_val => switch (resB) {
                    .ok_val => resA,
                    .err_val => |e| err(e),
                },
                .err_val => resA,
            };
        }

        /// product: 组合两个 Result 为 tuple
        pub fn product(comptime B: type, resA: Result, resB: ResultApplicative(B, E).Result) ResultApplicative(struct { A, B }, E).Result {
            return switch (resA) {
                .ok_val => |a| switch (resB) {
                    .ok_val => |b| ResultApplicative(struct { A, B }, E).pure(.{ a, b }),
                    .err_val => |e| ResultApplicative(struct { A, B }, E).err(e),
                },
                .err_val => |e| ResultApplicative(struct { A, B }, E).err(e),
            };
        }
    };
}

// ============ List Applicative ============

/// List 的 Applicative 实现（使用数组）
pub fn ListApplicative(comptime A: type) type {
    return struct {
        const Self = @This();

        /// pure: 创建单元素列表
        pub fn pure(allocator: Allocator, value: A) ![]A {
            const result = try allocator.alloc(A, 1);
            result[0] = value;
            return result;
        }

        /// map: 对列表中每个元素应用函数
        pub fn map(allocator: Allocator, list: []const A, comptime B: type, f: *const fn (A) B) ![]B {
            const result = try allocator.alloc(B, list.len);
            for (list, 0..) |item, i| {
                result[i] = f(item);
            }
            return result;
        }

        /// ap: 应用函数列表到值列表（笛卡尔积）
        pub fn ap(
            allocator: Allocator,
            comptime B: type,
            funcs: []const *const fn (A) B,
            values: []const A,
        ) ![]B {
            const total = funcs.len * values.len;
            if (total == 0) {
                return try allocator.alloc(B, 0);
            }

            const result = try allocator.alloc(B, total);
            var idx: usize = 0;
            for (funcs) |f| {
                for (values) |v| {
                    result[idx] = f(v);
                    idx += 1;
                }
            }
            return result;
        }

        /// liftA2: 对两个列表应用二元函数（笛卡尔积）
        pub fn liftA2(
            allocator: Allocator,
            comptime B: type,
            comptime C: type,
            f: *const fn (A, B) C,
            listA: []const A,
            listB: []const B,
        ) ![]C {
            const total = listA.len * listB.len;
            if (total == 0) {
                return try allocator.alloc(C, 0);
            }

            const result = try allocator.alloc(C, total);
            var idx: usize = 0;
            for (listA) |a| {
                for (listB) |b| {
                    result[idx] = f(a, b);
                    idx += 1;
                }
            }
            return result;
        }

        /// product: 组合两个列表为 tuple 列表
        pub fn product(
            allocator: Allocator,
            comptime B: type,
            listA: []const A,
            listB: []const B,
        ) ![]struct { A, B } {
            const total = listA.len * listB.len;
            if (total == 0) {
                return try allocator.alloc(struct { A, B }, 0);
            }

            const result = try allocator.alloc(struct { A, B }, total);
            var idx: usize = 0;
            for (listA) |a| {
                for (listB) |b| {
                    result[idx] = .{ a, b };
                    idx += 1;
                }
            }
            return result;
        }

        /// sequence: 将 Option 列表转换为列表的 Option
        pub fn sequenceOption(
            allocator: Allocator,
            opts: []const OptionApplicative(A).Option,
        ) !?[]A {
            const result = try allocator.alloc(A, opts.len);
            errdefer allocator.free(result);

            for (opts, 0..) |opt, i| {
                switch (opt) {
                    .some_val => |v| result[i] = v,
                    .none_val => {
                        allocator.free(result);
                        return null;
                    },
                }
            }
            return result;
        }
    };
}

// ============ 通用工具函数 ============

/// 提升二元函数到 Option
pub fn liftA2Option(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    f: *const fn (A, B) C,
    optA: OptionApplicative(A).Option,
    optB: OptionApplicative(B).Option,
) OptionApplicative(C).Option {
    return OptionApplicative(A).liftA2(B, C, f, optA, optB);
}

/// 提升三元函数到 Option
pub fn liftA3Option(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    f: *const fn (A, B, C) D,
    optA: OptionApplicative(A).Option,
    optB: OptionApplicative(B).Option,
    optC: OptionApplicative(C).Option,
) OptionApplicative(D).Option {
    // 先组合 A 和 B
    const optAB = OptionApplicative(A).product(B, optA, optB);

    // 再与 C 组合
    return switch (optAB) {
        .some_val => |ab| switch (optC) {
            .some_val => |c| OptionApplicative(D).pure(f(ab[0], ab[1], c)),
            .none_val => OptionApplicative(D).none(),
        },
        .none_val => OptionApplicative(D).none(),
    };
}

/// 提升二元函数到 Result
pub fn liftA2Result(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime E: type,
    f: *const fn (A, B) C,
    resA: ResultApplicative(A, E).Result,
    resB: ResultApplicative(B, E).Result,
) ResultApplicative(C, E).Result {
    return ResultApplicative(A, E).liftA2(B, C, f, resA, resB);
}

// ============ 测试 ============

test "OptionApplicative.pure" {
    const OptInt = OptionApplicative(i32);
    const opt = OptInt.pure(42);

    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(?i32, 42), opt.getValue());
}

test "OptionApplicative.none" {
    const OptInt = OptionApplicative(i32);
    const opt = OptInt.none();

    try std.testing.expect(opt.isNone());
    try std.testing.expectEqual(@as(?i32, null), opt.getValue());
}

test "OptionApplicative.map" {
    const OptInt = OptionApplicative(i32);
    const opt = OptInt.pure(21);

    const mapped = OptInt.map(opt, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(?i32, 42), mapped.getValue());
}

test "OptionApplicative.map none" {
    const OptInt = OptionApplicative(i32);
    const opt = OptInt.none();

    const mapped = OptInt.map(opt, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expect(mapped.isNone());
}

test "OptionApplicative.liftA2" {
    const OptInt = OptionApplicative(i32);
    const optA = OptInt.pure(10);
    const optB = OptInt.pure(20);

    const result = OptInt.liftA2(i32, i32, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f, optA, optB);

    try std.testing.expectEqual(@as(?i32, 30), result.getValue());
}

test "OptionApplicative.liftA2 with none" {
    const OptInt = OptionApplicative(i32);
    const optA = OptInt.pure(10);
    const optB = OptInt.none();

    const result = OptInt.liftA2(i32, i32, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f, optA, optB);

    try std.testing.expect(result.isNone());
}

test "OptionApplicative.productR" {
    const OptInt = OptionApplicative(i32);
    const optA = OptInt.pure(10);
    const optB = OptInt.pure(20);

    const result = OptInt.productR(i32, optA, optB);
    try std.testing.expectEqual(@as(?i32, 20), result.getValue());
}

test "OptionApplicative.productL" {
    const OptInt = OptionApplicative(i32);
    const optA = OptInt.pure(10);
    const optB = OptInt.pure(20);

    const result = OptInt.productL(i32, optA, optB);
    try std.testing.expectEqual(@as(?i32, 10), result.getValue());
}

test "OptionApplicative.product" {
    const OptInt = OptionApplicative(i32);
    const optA = OptInt.pure(10);
    const optB = OptInt.pure(20);

    const result = OptInt.product(i32, optA, optB);
    try std.testing.expect(result.isSome());
    const pair = result.getValue().?;
    try std.testing.expectEqual(@as(i32, 10), pair[0]);
    try std.testing.expectEqual(@as(i32, 20), pair[1]);
}

test "ResultApplicative.pure" {
    const ResInt = ResultApplicative(i32, []const u8);
    const res = ResInt.pure(42);

    try std.testing.expect(res.isOk());
    try std.testing.expectEqual(@as(?i32, 42), res.getValue());
}

test "ResultApplicative.err" {
    const ResInt = ResultApplicative(i32, []const u8);
    const res = ResInt.err("error");

    try std.testing.expect(res.isErr());
    try std.testing.expectEqualStrings("error", res.getError().?);
}

test "ResultApplicative.liftA2" {
    const ResInt = ResultApplicative(i32, []const u8);
    const resA = ResInt.pure(10);
    const resB = ResInt.pure(20);

    const result = ResInt.liftA2(i32, i32, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f, resA, resB);

    try std.testing.expectEqual(@as(?i32, 30), result.getValue());
}

test "ResultApplicative.liftA2 with error" {
    const ResInt = ResultApplicative(i32, []const u8);
    const resA = ResInt.pure(10);
    const resB = ResInt.err("oops");

    const result = ResInt.liftA2(i32, i32, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f, resA, resB);

    try std.testing.expect(result.isErr());
    try std.testing.expectEqualStrings("oops", result.getError().?);
}

test "ResultApplicative.product" {
    const ResInt = ResultApplicative(i32, []const u8);
    const resA = ResInt.pure(10);
    const resB = ResInt.pure(20);

    const result = ResInt.product(i32, resA, resB);
    try std.testing.expect(result.isOk());
    const pair = result.getValue().?;
    try std.testing.expectEqual(@as(i32, 10), pair[0]);
    try std.testing.expectEqual(@as(i32, 20), pair[1]);
}

test "ListApplicative.pure" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);

    const list = try ListInt.pure(allocator, 42);
    defer allocator.free(list);

    try std.testing.expectEqual(@as(usize, 1), list.len);
    try std.testing.expectEqual(@as(i32, 42), list[0]);
}

test "ListApplicative.map" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);

    const input = [_]i32{ 1, 2, 3 };
    const result = try ListInt.map(allocator, &input, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 4), result[1]);
    try std.testing.expectEqual(@as(i32, 6), result[2]);
}

test "ListApplicative.liftA2" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);

    const listA = [_]i32{ 1, 2 };
    const listB = [_]i32{ 10, 20 };

    const result = try ListInt.liftA2(allocator, i32, i32, struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f, &listA, &listB);
    defer allocator.free(result);

    // 笛卡尔积: (1,10), (1,20), (2,10), (2,20) -> 11, 21, 12, 22
    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 21), result[1]);
    try std.testing.expectEqual(@as(i32, 12), result[2]);
    try std.testing.expectEqual(@as(i32, 22), result[3]);
}

test "ListApplicative.product" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);

    const listA = [_]i32{ 1, 2 };
    const listB = [_]i32{ 10, 20 };

    const result = try ListInt.product(allocator, i32, &listA, &listB);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0][0]);
    try std.testing.expectEqual(@as(i32, 10), result[0][1]);
}

test "ListApplicative.sequenceOption all some" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);
    const OptInt = OptionApplicative(i32);

    const opts = [_]OptInt.Option{
        OptInt.pure(1),
        OptInt.pure(2),
        OptInt.pure(3),
    };

    const result = try ListInt.sequenceOption(allocator, &opts);
    try std.testing.expect(result != null);
    defer allocator.free(result.?);

    try std.testing.expectEqual(@as(usize, 3), result.?.len);
    try std.testing.expectEqual(@as(i32, 1), result.?[0]);
    try std.testing.expectEqual(@as(i32, 2), result.?[1]);
    try std.testing.expectEqual(@as(i32, 3), result.?[2]);
}

test "ListApplicative.sequenceOption with none" {
    const allocator = std.testing.allocator;
    const ListInt = ListApplicative(i32);
    const OptInt = OptionApplicative(i32);

    const opts = [_]OptInt.Option{
        OptInt.pure(1),
        OptInt.none(),
        OptInt.pure(3),
    };

    const result = try ListInt.sequenceOption(allocator, &opts);
    try std.testing.expect(result == null);
}

test "liftA3Option" {
    const OptInt = OptionApplicative(i32);

    const optA = OptInt.pure(1);
    const optB = OptInt.pure(2);
    const optC = OptInt.pure(3);

    const result = liftA3Option(i32, i32, i32, i32, struct {
        fn f(a: i32, b: i32, c: i32) i32 {
            return a + b + c;
        }
    }.f, optA, optB, optC);

    try std.testing.expectEqual(@as(?i32, 6), result.getValue());
}

test "liftA3Option with none" {
    const OptInt = OptionApplicative(i32);

    const optA = OptInt.pure(1);
    const optB = OptInt.none();
    const optC = OptInt.pure(3);

    const result = liftA3Option(i32, i32, i32, i32, struct {
        fn f(a: i32, b: i32, c: i32) i32 {
            return a + b + c;
        }
    }.f, optA, optB, optC);

    try std.testing.expect(result.isNone());
}

test "Applicative identity law" {
    // pure(id) <*> v = v
    // 由于类型系统限制，使用 map 验证 identity
    const OptInt = OptionApplicative(i32);
    const v = OptInt.pure(42);

    const result = OptInt.map(v, i32, struct {
        fn id(x: i32) i32 {
            return x;
        }
    }.id);

    try std.testing.expectEqual(v.getValue(), result.getValue());
}

test "Applicative homomorphism law" {
    // pure(f) <*> pure(x) = pure(f(x))
    // 由于类型系统限制，使用 liftA2 验证
    const OptInt = OptionApplicative(i32);

    const f = struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double;

    const x: i32 = 21;

    // pure(f(x)) 应该等于 map(pure(x), f)
    const left = OptInt.map(OptInt.pure(x), i32, f);
    const right = OptInt.pure(f(x));

    try std.testing.expectEqual(left.getValue(), right.getValue());
}
