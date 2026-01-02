//! Stream 模块
//!
//! Stream 是惰性无限序列，只在需要时计算元素。
//! 这使得可以表示和操作无限数据结构。
//!
//! 主要操作：
//! - `iterate` - 从初始值迭代生成
//! - `repeat` - 无限重复单个值
//! - `cycle` - 无限循环一个序列
//! - `unfold` - 通过展开函数生成
//! - `take` - 取前 n 个元素
//! - `drop` - 跳过前 n 个元素
//! - `map` - 映射转换
//! - `filter` - 过滤
//! - `zipWith` - 合并两个流

const std = @import("std");
const option_mod = @import("option.zig");
const Option = option_mod.Option;

// ============ Stream 类型 ============

/// Stream - 惰性无限流
/// 使用生成器函数来按需生成元素
pub fn Stream(comptime T: type) type {
    return struct {
        /// 生成器状态
        state: *anyopaque,
        /// 生成下一个元素的函数
        next_fn: *const fn (*anyopaque) ?T,
        /// 重置函数（可选，用于重复使用流）
        reset_fn: ?*const fn (*anyopaque) void,
        /// 清理函数
        deinit_fn: ?*const fn (*anyopaque, std.mem.Allocator) void,
        /// 用于分配的 allocator
        allocator: std.mem.Allocator,

        const Self = @This();

        // ============ 基本操作 ============

        /// 获取下一个元素
        pub fn next(self: *Self) ?T {
            return self.next_fn(self.state);
        }

        /// 重置流到初始状态
        pub fn reset(self: *Self) void {
            if (self.reset_fn) |f| {
                f(self.state);
            }
        }

        /// 释放资源
        pub fn deinit(self: *Self) void {
            if (self.deinit_fn) |f| {
                f(self.state, self.allocator);
            }
        }

        // ============ 消费操作 ============

        /// 取前 n 个元素
        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]T {
            var result = try std.ArrayList(T).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }

        /// 跳过前 n 个元素
        pub fn drop(self: *Self, n: usize) void {
            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next() == null) break;
            }
        }

        /// 获取第一个元素
        pub fn head(self: *Self) ?T {
            return self.next();
        }

        /// 折叠前 n 个元素
        pub fn foldN(self: *Self, n: usize, initial: T, f: *const fn (T, T) T) T {
            var acc = initial;
            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    acc = f(acc, val);
                } else {
                    break;
                }
            }
            return acc;
        }

        /// 检查前 n 个元素是否都满足谓词
        pub fn allN(self: *Self, n: usize, pred: *const fn (T) bool) bool {
            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    if (!pred(val)) return false;
                } else {
                    break;
                }
            }
            return true;
        }

        /// 检查前 n 个元素是否存在满足谓词的
        pub fn anyN(self: *Self, n: usize, pred: *const fn (T) bool) bool {
            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    if (pred(val)) return true;
                } else {
                    break;
                }
            }
            return false;
        }

        /// 在前 n 个元素中查找满足谓词的第一个
        pub fn findN(self: *Self, n: usize, pred: *const fn (T) bool) ?T {
            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    if (pred(val)) return val;
                } else {
                    break;
                }
            }
            return null;
        }
    };
}

// ============ 生成器状态类型 ============

/// iterate 生成器状态
fn IterateState(comptime T: type) type {
    return struct {
        current: T,
        step_fn: *const fn (T) T,
        initial: T,

        const Self = @This();

        fn next(ptr: *anyopaque) ?T {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const result = self.current;
            self.current = self.step_fn(self.current);
            return result;
        }

        fn reset(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.current = self.initial;
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

/// repeat 生成器状态
fn RepeatState(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        fn next(ptr: *anyopaque) ?T {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.value;
        }

        fn reset(_: *anyopaque) void {
            // repeat 不需要重置
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

/// cycle 生成器状态
fn CycleState(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize,

        const Self = @This();

        fn next(ptr: *anyopaque) ?T {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.items.len == 0) return null;

            const result = self.items[self.index];
            self.index = (self.index + 1) % self.items.len;
            return result;
        }

        fn reset(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.index = 0;
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

/// range 生成器状态
fn RangeState(comptime T: type) type {
    return struct {
        current: T,
        end: T,
        step: T,
        initial: T,

        const Self = @This();

        fn next(ptr: *anyopaque) ?T {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.step > 0 and self.current >= self.end) return null;
            if (self.step < 0 and self.current <= self.end) return null;

            const result = self.current;
            self.current += self.step;
            return result;
        }

        fn reset(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.current = self.initial;
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

/// unfold 生成器状态
fn UnfoldState(comptime S: type, comptime A: type) type {
    return struct {
        state: S,
        step_fn: *const fn (S) ?struct { A, S },
        initial: S,

        const Self = @This();

        fn next(ptr: *anyopaque) ?A {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.step_fn(self.state)) |result| {
                self.state = result[1];
                return result[0];
            }
            return null;
        }

        fn reset(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.state = self.initial;
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

// ============ 流构造函数 ============

/// 从步进函数迭代生成无限流
/// iterate(0, +1) = 0, 1, 2, 3, ...
pub fn iterate(comptime T: type, allocator: std.mem.Allocator, initial: T, step_fn: *const fn (T) T) !Stream(T) {
    const State = IterateState(T);
    const state = try allocator.create(State);
    state.* = .{
        .current = initial,
        .step_fn = step_fn,
        .initial = initial,
    };

    return Stream(T){
        .state = state,
        .next_fn = &State.next,
        .reset_fn = &State.reset,
        .deinit_fn = &State.deinit,
        .allocator = allocator,
    };
}

/// 无限重复单个值
/// repeat(42) = 42, 42, 42, ...
pub fn repeatStream(comptime T: type, allocator: std.mem.Allocator, value: T) !Stream(T) {
    const State = RepeatState(T);
    const state = try allocator.create(State);
    state.* = .{ .value = value };

    return Stream(T){
        .state = state,
        .next_fn = &State.next,
        .reset_fn = &State.reset,
        .deinit_fn = &State.deinit,
        .allocator = allocator,
    };
}

/// 无限循环一个序列
/// cycle([1, 2, 3]) = 1, 2, 3, 1, 2, 3, ...
pub fn cycle(comptime T: type, allocator: std.mem.Allocator, items: []const T) !Stream(T) {
    const State = CycleState(T);
    const state = try allocator.create(State);
    state.* = .{
        .items = items,
        .index = 0,
    };

    return Stream(T){
        .state = state,
        .next_fn = &State.next,
        .reset_fn = &State.reset,
        .deinit_fn = &State.deinit,
        .allocator = allocator,
    };
}

/// 生成有限范围的流
/// range(0, 5, 1) = 0, 1, 2, 3, 4
pub fn rangeStream(comptime T: type, allocator: std.mem.Allocator, start: T, end: T, step: T) !Stream(T) {
    const State = RangeState(T);
    const state = try allocator.create(State);
    state.* = .{
        .current = start,
        .end = end,
        .step = step,
        .initial = start,
    };

    return Stream(T){
        .state = state,
        .next_fn = &State.next,
        .reset_fn = &State.reset,
        .deinit_fn = &State.deinit,
        .allocator = allocator,
    };
}

/// 通过展开函数生成流
/// unfold(state, step) 其中 step(s) = Some(a, s') 或 None
pub fn unfold(
    comptime S: type,
    comptime A: type,
    allocator: std.mem.Allocator,
    initial: S,
    step_fn: *const fn (S) ?struct { A, S },
) !Stream(A) {
    const State = UnfoldState(S, A);
    const state = try allocator.create(State);
    state.* = .{
        .state = initial,
        .step_fn = step_fn,
        .initial = initial,
    };

    return Stream(A){
        .state = state,
        .next_fn = &State.next,
        .reset_fn = &State.reset,
        .deinit_fn = &State.deinit,
        .allocator = allocator,
    };
}

// ============ 流转换 ============

/// map 转换流
pub fn MapStream(comptime A: type, comptime B: type) type {
    return struct {
        source: *Stream(A),
        map_fn: *const fn (A) B,

        const Self = @This();

        pub fn next(self: *Self) ?B {
            if (self.source.next()) |val| {
                return self.map_fn(val);
            }
            return null;
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]B {
            var result = try std.ArrayList(B).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }
    };
}

/// 创建映射流
pub fn mapStream(comptime A: type, comptime B: type, source: *Stream(A), map_fn: *const fn (A) B) MapStream(A, B) {
    return .{
        .source = source,
        .map_fn = map_fn,
    };
}

/// filter 过滤流
pub fn FilterStream(comptime T: type) type {
    return struct {
        source: *Stream(T),
        pred_fn: *const fn (T) bool,

        const Self = @This();

        pub fn next(self: *Self) ?T {
            while (self.source.next()) |val| {
                if (self.pred_fn(val)) {
                    return val;
                }
            }
            return null;
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]T {
            var result = try std.ArrayList(T).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }
    };
}

/// 创建过滤流
pub fn filterStream(comptime T: type, source: *Stream(T), pred_fn: *const fn (T) bool) FilterStream(T) {
    return .{
        .source = source,
        .pred_fn = pred_fn,
    };
}

/// zipWith 合并两个流
pub fn ZipWithStream(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        source_a: *Stream(A),
        source_b: *Stream(B),
        zip_fn: *const fn (A, B) C,

        const Self = @This();

        pub fn next(self: *Self) ?C {
            const a = self.source_a.next() orelse return null;
            const b = self.source_b.next() orelse return null;
            return self.zip_fn(a, b);
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]C {
            var result = try std.ArrayList(C).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }
    };
}

/// 创建 zipWith 流
pub fn zipWith(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    source_a: *Stream(A),
    source_b: *Stream(B),
    zip_fn: *const fn (A, B) C,
) ZipWithStream(A, B, C) {
    return .{
        .source_a = source_a,
        .source_b = source_b,
        .zip_fn = zip_fn,
    };
}

/// takeWhile 流
pub fn TakeWhileStream(comptime T: type) type {
    return struct {
        source: *Stream(T),
        pred_fn: *const fn (T) bool,
        done: bool,

        const Self = @This();

        pub fn next(self: *Self) ?T {
            if (self.done) return null;

            if (self.source.next()) |val| {
                if (self.pred_fn(val)) {
                    return val;
                } else {
                    self.done = true;
                    return null;
                }
            }
            return null;
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]T {
            var result = try std.ArrayList(T).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }
    };
}

/// 创建 takeWhile 流
pub fn takeWhile(comptime T: type, source: *Stream(T), pred_fn: *const fn (T) bool) TakeWhileStream(T) {
    return .{
        .source = source,
        .pred_fn = pred_fn,
        .done = false,
    };
}

/// scanl 累积扫描流
pub fn ScanlStream(comptime A: type, comptime B: type) type {
    return struct {
        source: *Stream(A),
        acc: B,
        fold_fn: *const fn (B, A) B,
        emitted_initial: bool,

        const Self = @This();

        pub fn next(self: *Self) ?B {
            if (!self.emitted_initial) {
                self.emitted_initial = true;
                return self.acc;
            }

            if (self.source.next()) |val| {
                self.acc = self.fold_fn(self.acc, val);
                return self.acc;
            }
            return null;
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator, n: usize) ![]B {
            var result = try std.ArrayList(B).initCapacity(allocator, n);
            errdefer result.deinit(allocator);

            var count: usize = 0;
            while (count < n) : (count += 1) {
                if (self.next()) |val| {
                    try result.append(allocator, val);
                } else {
                    break;
                }
            }

            return result.toOwnedSlice(allocator);
        }
    };
}

/// 创建 scanl 流
pub fn scanl(
    comptime A: type,
    comptime B: type,
    source: *Stream(A),
    initial: B,
    fold_fn: *const fn (B, A) B,
) ScanlStream(A, B) {
    return .{
        .source = source,
        .acc = initial,
        .fold_fn = fold_fn,
        .emitted_initial = false,
    };
}

// ============ 测试 ============

test "iterate - natural numbers" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const first10 = try stream.take(allocator, 10);
    defer allocator.free(first10);

    try std.testing.expectEqual(@as(usize, 10), first10.len);
    try std.testing.expectEqual(@as(i64, 0), first10[0]);
    try std.testing.expectEqual(@as(i64, 1), first10[1]);
    try std.testing.expectEqual(@as(i64, 9), first10[9]);
}

test "iterate - powers of 2" {
    const allocator = std.testing.allocator;

    const double = struct {
        fn f(n: i64) i64 {
            return n * 2;
        }
    }.f;

    var stream = try iterate(i64, allocator, 1, &double);
    defer stream.deinit();

    const first5 = try stream.take(allocator, 5);
    defer allocator.free(first5);

    try std.testing.expectEqual(@as(i64, 1), first5[0]);
    try std.testing.expectEqual(@as(i64, 2), first5[1]);
    try std.testing.expectEqual(@as(i64, 4), first5[2]);
    try std.testing.expectEqual(@as(i64, 8), first5[3]);
    try std.testing.expectEqual(@as(i64, 16), first5[4]);
}

test "repeat" {
    const allocator = std.testing.allocator;

    var stream = try repeatStream(i32, allocator, 42);
    defer stream.deinit();

    const first5 = try stream.take(allocator, 5);
    defer allocator.free(first5);

    for (first5) |val| {
        try std.testing.expectEqual(@as(i32, 42), val);
    }
}

test "cycle" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3 };
    var stream = try cycle(i32, allocator, &items);
    defer stream.deinit();

    const first7 = try stream.take(allocator, 7);
    defer allocator.free(first7);

    try std.testing.expectEqual(@as(i32, 1), first7[0]);
    try std.testing.expectEqual(@as(i32, 2), first7[1]);
    try std.testing.expectEqual(@as(i32, 3), first7[2]);
    try std.testing.expectEqual(@as(i32, 1), first7[3]);
    try std.testing.expectEqual(@as(i32, 2), first7[4]);
    try std.testing.expectEqual(@as(i32, 3), first7[5]);
    try std.testing.expectEqual(@as(i32, 1), first7[6]);
}

test "rangeStream" {
    const allocator = std.testing.allocator;

    var stream = try rangeStream(i32, allocator, 0, 5, 1);
    defer stream.deinit();

    const result = try stream.take(allocator, 10);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 0), result[0]);
    try std.testing.expectEqual(@as(i32, 4), result[4]);
}

test "rangeStream with step" {
    const allocator = std.testing.allocator;

    var stream = try rangeStream(i32, allocator, 0, 10, 2);
    defer stream.deinit();

    const result = try stream.take(allocator, 10);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 0), result[0]);
    try std.testing.expectEqual(@as(i32, 2), result[1]);
    try std.testing.expectEqual(@as(i32, 8), result[4]);
}

test "unfold - fibonacci" {
    const allocator = std.testing.allocator;

    const fibStep = struct {
        fn f(state: struct { i64, i64 }) ?struct { i64, struct { i64, i64 } } {
            return .{ state[0], .{ state[1], state[0] + state[1] } };
        }
    }.f;

    var stream = try unfold(struct { i64, i64 }, i64, allocator, .{ 0, 1 }, &fibStep);
    defer stream.deinit();

    const first10 = try stream.take(allocator, 10);
    defer allocator.free(first10);

    // 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
    try std.testing.expectEqual(@as(i64, 0), first10[0]);
    try std.testing.expectEqual(@as(i64, 1), first10[1]);
    try std.testing.expectEqual(@as(i64, 1), first10[2]);
    try std.testing.expectEqual(@as(i64, 2), first10[3]);
    try std.testing.expectEqual(@as(i64, 3), first10[4]);
    try std.testing.expectEqual(@as(i64, 5), first10[5]);
    try std.testing.expectEqual(@as(i64, 8), first10[6]);
    try std.testing.expectEqual(@as(i64, 13), first10[7]);
    try std.testing.expectEqual(@as(i64, 21), first10[8]);
    try std.testing.expectEqual(@as(i64, 34), first10[9]);
}

test "Stream.drop" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    stream.drop(5);

    const next5 = try stream.take(allocator, 5);
    defer allocator.free(next5);

    try std.testing.expectEqual(@as(i64, 5), next5[0]);
    try std.testing.expectEqual(@as(i64, 9), next5[4]);
}

test "Stream.head" {
    const allocator = std.testing.allocator;

    var stream = try repeatStream(i32, allocator, 42);
    defer stream.deinit();

    const h = stream.head();
    try std.testing.expectEqual(@as(?i32, 42), h);
}

test "Stream.foldN" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 1, &succ);
    defer stream.deinit();

    const add = struct {
        fn f(a: i64, b: i64) i64 {
            return a + b;
        }
    }.f;

    // 1 + 2 + 3 + 4 + 5 = 15
    const sum = stream.foldN(5, 0, &add);
    try std.testing.expectEqual(@as(i64, 15), sum);
}

test "Stream.reset" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    // 取前 5 个
    const first5 = try stream.take(allocator, 5);
    defer allocator.free(first5);
    try std.testing.expectEqual(@as(i64, 4), first5[4]);

    // 重置
    stream.reset();

    // 再取前 5 个应该一样
    const again5 = try stream.take(allocator, 5);
    defer allocator.free(again5);
    try std.testing.expectEqual(@as(i64, 0), again5[0]);
    try std.testing.expectEqual(@as(i64, 4), again5[4]);
}

test "mapStream" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const double = struct {
        fn f(n: i64) i64 {
            return n * 2;
        }
    }.f;

    var mapped = mapStream(i64, i64, &stream, &double);

    const result = try mapped.take(allocator, 5);
    defer allocator.free(result);

    // 0*2, 1*2, 2*2, 3*2, 4*2 = 0, 2, 4, 6, 8
    try std.testing.expectEqual(@as(i64, 0), result[0]);
    try std.testing.expectEqual(@as(i64, 2), result[1]);
    try std.testing.expectEqual(@as(i64, 4), result[2]);
    try std.testing.expectEqual(@as(i64, 6), result[3]);
    try std.testing.expectEqual(@as(i64, 8), result[4]);
}

test "filterStream" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const isEven = struct {
        fn f(n: i64) bool {
            return @mod(n, 2) == 0;
        }
    }.f;

    var filtered = filterStream(i64, &stream, &isEven);

    const result = try filtered.take(allocator, 5);
    defer allocator.free(result);

    // 0, 2, 4, 6, 8
    try std.testing.expectEqual(@as(i64, 0), result[0]);
    try std.testing.expectEqual(@as(i64, 2), result[1]);
    try std.testing.expectEqual(@as(i64, 4), result[2]);
    try std.testing.expectEqual(@as(i64, 6), result[3]);
    try std.testing.expectEqual(@as(i64, 8), result[4]);
}

test "zipWith" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream1 = try iterate(i64, allocator, 0, &succ);
    defer stream1.deinit();

    var stream2 = try iterate(i64, allocator, 10, &succ);
    defer stream2.deinit();

    const add = struct {
        fn f(a: i64, b: i64) i64 {
            return a + b;
        }
    }.f;

    var zipped = zipWith(i64, i64, i64, &stream1, &stream2, &add);

    const result = try zipped.take(allocator, 5);
    defer allocator.free(result);

    // (0+10), (1+11), (2+12), (3+13), (4+14) = 10, 12, 14, 16, 18
    try std.testing.expectEqual(@as(i64, 10), result[0]);
    try std.testing.expectEqual(@as(i64, 12), result[1]);
    try std.testing.expectEqual(@as(i64, 14), result[2]);
    try std.testing.expectEqual(@as(i64, 16), result[3]);
    try std.testing.expectEqual(@as(i64, 18), result[4]);
}

test "takeWhile" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const lessThan5 = struct {
        fn f(n: i64) bool {
            return n < 5;
        }
    }.f;

    var tw = takeWhile(i64, &stream, &lessThan5);

    const result = try tw.take(allocator, 10);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i64, 0), result[0]);
    try std.testing.expectEqual(@as(i64, 4), result[4]);
}

test "scanl - running sum" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 1, &succ);
    defer stream.deinit();

    const add = struct {
        fn f(a: i64, b: i64) i64 {
            return a + b;
        }
    }.f;

    var scanned = scanl(i64, i64, &stream, 0, &add);

    const result = try scanned.take(allocator, 6);
    defer allocator.free(result);

    // 0, 0+1=1, 1+2=3, 3+3=6, 6+4=10, 10+5=15
    try std.testing.expectEqual(@as(i64, 0), result[0]);
    try std.testing.expectEqual(@as(i64, 1), result[1]);
    try std.testing.expectEqual(@as(i64, 3), result[2]);
    try std.testing.expectEqual(@as(i64, 6), result[3]);
    try std.testing.expectEqual(@as(i64, 10), result[4]);
    try std.testing.expectEqual(@as(i64, 15), result[5]);
}

test "Stream.allN" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const lessThan10 = struct {
        fn f(n: i64) bool {
            return n < 10;
        }
    }.f;

    // 前 5 个 (0-4) 都小于 10
    try std.testing.expect(stream.allN(5, &lessThan10));

    stream.reset();

    const lessThan3 = struct {
        fn f(n: i64) bool {
            return n < 3;
        }
    }.f;

    // 前 5 个 (0-4) 不全小于 3
    try std.testing.expect(!stream.allN(5, &lessThan3));
}

test "Stream.anyN" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const greaterThan3 = struct {
        fn f(n: i64) bool {
            return n > 3;
        }
    }.f;

    // 前 5 个 (0-4) 有大于 3 的 (4)
    try std.testing.expect(stream.anyN(5, &greaterThan3));

    stream.reset();

    const greaterThan10 = struct {
        fn f(n: i64) bool {
            return n > 10;
        }
    }.f;

    // 前 5 个 (0-4) 没有大于 10 的
    try std.testing.expect(!stream.anyN(5, &greaterThan10));
}

test "Stream.findN" {
    const allocator = std.testing.allocator;

    const succ = struct {
        fn f(n: i64) i64 {
            return n + 1;
        }
    }.f;

    var stream = try iterate(i64, allocator, 0, &succ);
    defer stream.deinit();

    const greaterThan3 = struct {
        fn f(n: i64) bool {
            return n > 3;
        }
    }.f;

    // 前 10 个中第一个大于 3 的是 4
    const found = stream.findN(10, &greaterThan3);
    try std.testing.expectEqual(@as(?i64, 4), found);

    stream.reset();

    const greaterThan100 = struct {
        fn f(n: i64) bool {
            return n > 100;
        }
    }.f;

    // 前 10 个中没有大于 100 的
    const notFound = stream.findN(10, &greaterThan100);
    try std.testing.expect(notFound == null);
}
