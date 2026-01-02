//! Traversable 模块
//!
//! Traversable 表示可以遍历并收集效果的数据结构。
//! 核心操作是 traverse 和 sequence。
//!
//! traverse: (A -> F(B)) -> T(A) -> F(T(B))
//! sequence: T(F(A)) -> F(T(A))
//!
//! 类似于 Haskell 的 Traversable 类型类

const std = @import("std");
const Allocator = std.mem.Allocator;

// 使用统一的类型定义
const Option = @import("../core/option.zig").Option;
const result_mod = @import("../core/result.zig");
const Result = result_mod.Result;

// ============ Slice Traversable ============

/// 切片/数组的 Traversable 实现
pub fn SliceTraversable(comptime A: type) type {
    return struct {
        const Self = @This();

        // ============ traverse with Option ============

        /// traverseOption: 遍历切片，如果任何元素返回 None，则整体返回 None
        pub fn traverseOption(
            allocator: Allocator,
            slice: []const A,
            comptime B: type,
            f: *const fn (A) Option(B),
        ) !Option([]B) {
            const result = try allocator.alloc(B, slice.len);
            errdefer allocator.free(result);

            for (slice, 0..) |item, i| {
                const opt = f(item);
                switch (opt) {
                    .some => |v| result[i] = v,
                    .none => {
                        allocator.free(result);
                        return Option([]B).None();
                    },
                }
            }

            return Option([]B).Some(result);
        }

        /// sequenceOption: 将 Option 列表转换为列表的 Option
        pub fn sequenceOption(
            allocator: Allocator,
            comptime B: type,
            opts: []const Option(B),
        ) !Option([]B) {
            const result = try allocator.alloc(B, opts.len);
            errdefer allocator.free(result);

            for (opts, 0..) |opt, i| {
                switch (opt) {
                    .some => |v| result[i] = v,
                    .none => {
                        allocator.free(result);
                        return Option([]B).None();
                    },
                }
            }

            return Option([]B).Some(result);
        }

        // ============ traverse with Result ============

        /// traverseResult: 遍历切片，如果任何元素返回 Err，则整体返回 Err
        pub fn traverseResult(
            allocator: Allocator,
            slice: []const A,
            comptime B: type,
            comptime E: type,
            f: *const fn (A) Result(B, E),
        ) !Result([]B, E) {
            const result = try allocator.alloc(B, slice.len);
            errdefer allocator.free(result);

            for (slice, 0..) |item, i| {
                const res = f(item);
                switch (res) {
                    .ok => |v| result[i] = v,
                    .err => |e| {
                        allocator.free(result);
                        return result_mod.err([]B, E, e);
                    },
                }
            }

            return result_mod.ok([]B, E, result);
        }

        /// sequenceResult: 将 Result 列表转换为列表的 Result
        pub fn sequenceResult(
            allocator: Allocator,
            comptime B: type,
            comptime E: type,
            results: []const Result(B, E),
        ) !Result([]B, E) {
            const result = try allocator.alloc(B, results.len);
            errdefer allocator.free(result);

            for (results, 0..) |res, i| {
                switch (res) {
                    .ok => |v| result[i] = v,
                    .err => |e| {
                        allocator.free(result);
                        return result_mod.err([]B, E, e);
                    },
                }
            }

            return result_mod.ok([]B, E, result);
        }

        // ============ mapAccum ============

        /// mapAccumL: 带累积的左遍历
        pub fn mapAccumL(
            allocator: Allocator,
            slice: []const A,
            comptime S: type,
            comptime B: type,
            initial: S,
            f: *const fn (S, A) struct { S, B },
        ) !struct { state: S, values: []B } {
            const result = try allocator.alloc(B, slice.len);
            errdefer allocator.free(result);

            var state = initial;
            for (slice, 0..) |item, i| {
                const pair = f(state, item);
                state = pair[0];
                result[i] = pair[1];
            }

            return .{ .state = state, .values = result };
        }

        /// mapAccumR: 带累积的右遍历
        pub fn mapAccumR(
            allocator: Allocator,
            slice: []const A,
            comptime S: type,
            comptime B: type,
            initial: S,
            f: *const fn (S, A) struct { S, B },
        ) !struct { state: S, values: []B } {
            const result = try allocator.alloc(B, slice.len);
            errdefer allocator.free(result);

            var state = initial;
            var i = slice.len;
            while (i > 0) {
                i -= 1;
                const pair = f(state, slice[i]);
                state = pair[0];
                result[i] = pair[1];
            }

            return .{ .state = state, .values = result };
        }

        // ============ scan ============

        /// scanl: 左扫描（返回所有中间累积值）
        pub fn scanl(
            allocator: Allocator,
            slice: []const A,
            comptime B: type,
            initial: B,
            f: *const fn (B, A) B,
        ) ![]B {
            const result = try allocator.alloc(B, slice.len + 1);
            errdefer allocator.free(result);

            result[0] = initial;
            var acc = initial;
            for (slice, 0..) |item, i| {
                acc = f(acc, item);
                result[i + 1] = acc;
            }

            return result;
        }

        /// scanr: 右扫描（返回所有中间累积值）
        pub fn scanr(
            allocator: Allocator,
            slice: []const A,
            comptime B: type,
            initial: B,
            f: *const fn (A, B) B,
        ) ![]B {
            const result = try allocator.alloc(B, slice.len + 1);
            errdefer allocator.free(result);

            result[slice.len] = initial;
            var acc = initial;
            var i = slice.len;
            while (i > 0) {
                i -= 1;
                acc = f(slice[i], acc);
                result[i] = acc;
            }

            return result;
        }

        // ============ zipWith ============

        /// zipWith: 用函数合并两个切片
        pub fn zipWith(
            allocator: Allocator,
            sliceA: []const A,
            comptime B: type,
            sliceB: []const B,
            comptime C: type,
            f: *const fn (A, B) C,
        ) ![]C {
            const len = @min(sliceA.len, sliceB.len);
            const result = try allocator.alloc(C, len);

            for (0..len) |i| {
                result[i] = f(sliceA[i], sliceB[i]);
            }

            return result;
        }

        // ============ partition ============

        /// partition: 根据谓词分割切片
        pub fn partition(
            allocator: Allocator,
            slice: []const A,
            pred: *const fn (A) bool,
        ) !struct { matching: []A, notMatching: []A } {
            var matching = try std.ArrayList(A).initCapacity(allocator, slice.len);
            errdefer matching.deinit(allocator);
            var notMatching = try std.ArrayList(A).initCapacity(allocator, slice.len);
            errdefer notMatching.deinit(allocator);

            for (slice) |item| {
                if (pred(item)) {
                    try matching.append(allocator, item);
                } else {
                    try notMatching.append(allocator, item);
                }
            }

            return .{
                .matching = try matching.toOwnedSlice(allocator),
                .notMatching = try notMatching.toOwnedSlice(allocator),
            };
        }
    };
}

// ============ Option Traversable ============

/// Option 的 Traversable 实现
pub fn OptionTraversable(comptime A: type) type {
    return struct {
        const Self = @This();

        /// traverseOption: Option 中的 Option
        pub fn traverseOption(
            opt: Option(A),
            comptime B: type,
            f: *const fn (A) Option(B),
        ) Option(Option(B)) {
            return switch (opt) {
                .some => |v| {
                    const result = f(v);
                    return switch (result) {
                        .some => |b| Option(Option(B)).Some(Option(B).Some(b)),
                        .none => Option(Option(B)).Some(Option(B).None()),
                    };
                },
                .none => Option(Option(B)).Some(Option(B).None()),
            };
        }

        /// sequenceOption: Option(Option(A)) -> Option(Option(A))
        pub fn sequenceOption(
            opt: Option(Option(A)),
        ) Option(Option(A)) {
            return switch (opt) {
                .some => |inner| switch (inner) {
                    .some => Option(Option(A)).Some(inner),
                    .none => Option(Option(A)).None(),
                },
                .none => Option(Option(A)).Some(Option(A).None()),
            };
        }

        /// map: Functor 操作
        pub fn map(opt: Option(A), comptime B: type, f: *const fn (A) B) Option(B) {
            return switch (opt) {
                .some => |v| Option(B).Some(f(v)),
                .none => Option(B).None(),
            };
        }
    };
}

// ============ 通用工具函数 ============

/// 遍历切片并收集 Option 结果
pub fn traverseSliceOption(
    allocator: Allocator,
    comptime A: type,
    comptime B: type,
    slice: []const A,
    f: *const fn (A) Option(B),
) !Option([]B) {
    return SliceTraversable(A).traverseOption(allocator, slice, B, f);
}

/// 序列化 Option 切片
pub fn sequenceSliceOption(
    allocator: Allocator,
    comptime A: type,
    opts: []const Option(A),
) !Option([]A) {
    return SliceTraversable(void).sequenceOption(allocator, A, opts);
}

/// 遍历切片并收集 Result 结果
pub fn traverseSliceResult(
    allocator: Allocator,
    comptime A: type,
    comptime B: type,
    comptime E: type,
    slice: []const A,
    f: *const fn (A) Result(B, E),
) !Result([]B, E) {
    return SliceTraversable(A).traverseResult(allocator, slice, B, E, f);
}

/// 序列化 Result 切片
pub fn sequenceSliceResult(
    allocator: Allocator,
    comptime A: type,
    comptime E: type,
    results: []const Result(A, E),
) !Result([]A, E) {
    return SliceTraversable(void).sequenceResult(allocator, A, E, results);
}

// ============ 测试 ============

test "SliceTraversable.traverseOption all some" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.traverseOption(allocator, &nums, i32, struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f);

    try std.testing.expect(result.isSome());
    const values = result.toNullable().?;
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqual(@as(i32, 2), values[0]);
    try std.testing.expectEqual(@as(i32, 4), values[1]);
    try std.testing.expectEqual(@as(i32, 6), values[2]);
}

test "SliceTraversable.traverseOption with none" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.traverseOption(allocator, &nums, i32, struct {
        fn f(x: i32) Option(i32) {
            if (x == 2) return Option(i32).None();
            return Option(i32).Some(x * 2);
        }
    }.f);

    try std.testing.expect(result.isNone());
}

test "SliceTraversable.sequenceOption all some" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const opts = [_]Option(i32){
        Option(i32).Some(1),
        Option(i32).Some(2),
        Option(i32).Some(3),
    };

    const result = try Trav.sequenceOption(allocator, i32, &opts);
    try std.testing.expect(result.isSome());
    const values = result.toNullable().?;
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqual(@as(i32, 1), values[0]);
    try std.testing.expectEqual(@as(i32, 2), values[1]);
    try std.testing.expectEqual(@as(i32, 3), values[2]);
}

test "SliceTraversable.sequenceOption with none" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const opts = [_]Option(i32){
        Option(i32).Some(1),
        Option(i32).None(),
        Option(i32).Some(3),
    };

    const result = try Trav.sequenceOption(allocator, i32, &opts);
    try std.testing.expect(result.isNone());
}

test "SliceTraversable.traverseResult all ok" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.traverseResult(allocator, &nums, i32, []const u8, struct {
        fn f(x: i32) Result(i32, []const u8) {
            return result_mod.ok(i32, []const u8, x * 2);
        }
    }.f);

    try std.testing.expect(result.isOk());
    const values = result.unwrap();
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqual(@as(i32, 2), values[0]);
    try std.testing.expectEqual(@as(i32, 4), values[1]);
    try std.testing.expectEqual(@as(i32, 6), values[2]);
}

test "SliceTraversable.traverseResult with error" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.traverseResult(allocator, &nums, i32, []const u8, struct {
        fn f(x: i32) Result(i32, []const u8) {
            if (x == 2) return result_mod.err(i32, []const u8, "error at 2");
            return result_mod.ok(i32, []const u8, x * 2);
        }
    }.f);

    try std.testing.expect(result.isErr());
    try std.testing.expectEqualStrings("error at 2", result.unwrapErr());
}

test "SliceTraversable.mapAccumL" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.mapAccumL(allocator, &nums, i32, i32, 0, struct {
        fn f(acc: i32, x: i32) struct { i32, i32 } {
            return .{ acc + x, acc };
        }
    }.f);
    defer allocator.free(result.values);

    // acc: 0 -> 1 -> 3 -> 6
    // values: [0, 1, 3]
    try std.testing.expectEqual(@as(i32, 6), result.state);
    try std.testing.expectEqual(@as(usize, 3), result.values.len);
    try std.testing.expectEqual(@as(i32, 0), result.values[0]);
    try std.testing.expectEqual(@as(i32, 1), result.values[1]);
    try std.testing.expectEqual(@as(i32, 3), result.values[2]);
}

test "SliceTraversable.scanl" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.scanl(allocator, &nums, i32, 0, struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add);
    defer allocator.free(result);

    // [0, 1, 3, 6]
    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(i32, 0), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[1]);
    try std.testing.expectEqual(@as(i32, 3), result[2]);
    try std.testing.expectEqual(@as(i32, 6), result[3]);
}

test "SliceTraversable.scanr" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3 };
    const result = try Trav.scanr(allocator, &nums, i32, 0, struct {
        fn add(x: i32, acc: i32) i32 {
            return x + acc;
        }
    }.add);
    defer allocator.free(result);

    // [6, 5, 3, 0]
    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(i32, 6), result[0]);
    try std.testing.expectEqual(@as(i32, 5), result[1]);
    try std.testing.expectEqual(@as(i32, 3), result[2]);
    try std.testing.expectEqual(@as(i32, 0), result[3]);
}

test "SliceTraversable.zipWith" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20, 30 };

    const result = try Trav.zipWith(allocator, &a, i32, &b, i32, struct {
        fn add(x: i32, y: i32) i32 {
            return x + y;
        }
    }.add);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
    try std.testing.expectEqual(@as(i32, 33), result[2]);
}

test "SliceTraversable.zipWith different lengths" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const a = [_]i32{ 1, 2, 3, 4, 5 };
    const b = [_]i32{ 10, 20 };

    const result = try Trav.zipWith(allocator, &a, i32, &b, i32, struct {
        fn add(x: i32, y: i32) i32 {
            return x + y;
        }
    }.add);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 22), result[1]);
}

test "SliceTraversable.partition" {
    const allocator = std.testing.allocator;
    const Trav = SliceTraversable(i32);

    const nums = [_]i32{ 1, 2, 3, 4, 5, 6 };
    const result = try Trav.partition(allocator, &nums, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    defer allocator.free(result.matching);
    defer allocator.free(result.notMatching);

    try std.testing.expectEqual(@as(usize, 3), result.matching.len);
    try std.testing.expectEqual(@as(i32, 2), result.matching[0]);
    try std.testing.expectEqual(@as(i32, 4), result.matching[1]);
    try std.testing.expectEqual(@as(i32, 6), result.matching[2]);

    try std.testing.expectEqual(@as(usize, 3), result.notMatching.len);
    try std.testing.expectEqual(@as(i32, 1), result.notMatching[0]);
    try std.testing.expectEqual(@as(i32, 3), result.notMatching[1]);
    try std.testing.expectEqual(@as(i32, 5), result.notMatching[2]);
}

test "OptionTraversable.map" {
    const OptTrav = OptionTraversable(i32);

    const s = Option(i32).Some(21);
    const mapped = OptTrav.map(s, i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expect(mapped.isSome());
    try std.testing.expectEqual(@as(?i32, 42), mapped.toNullable());

    const n = Option(i32).None();
    const mappedNone = OptTrav.map(n, i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expect(mappedNone.isNone());
}

test "traverseSliceOption" {
    const allocator = std.testing.allocator;

    const nums = [_]i32{ 1, 2, 3 };
    const result = try traverseSliceOption(allocator, i32, i32, &nums, struct {
        fn f(x: i32) Option(i32) {
            return Option(i32).Some(x * 2);
        }
    }.f);

    try std.testing.expect(result.isSome());
    const values = result.toNullable().?;
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
}

test "traverseSliceResult" {
    const allocator = std.testing.allocator;

    const nums = [_]i32{ 1, 2, 3 };
    const result = try traverseSliceResult(allocator, i32, i32, []const u8, &nums, struct {
        fn f(x: i32) Result(i32, []const u8) {
            return result_mod.ok(i32, []const u8, x * 2);
        }
    }.f);

    try std.testing.expect(result.isOk());
    const values = result.unwrap();
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
}
