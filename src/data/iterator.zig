//! Iterator 模块 - 函数式迭代器
//!
//! 提供增强的迭代器操作，支持函数式链式调用。
//! 类似于 Rust 的 Iterator trait 或 Haskell 的 list 操作。

const std = @import("std");
const Allocator = std.mem.Allocator;
const option = @import("../core/option.zig");
const Option = option.Option;

/// 函数式迭代器包装器
/// 提供 map, filter, take, skip, fold 等函数式操作
pub fn Iterator(comptime T: type) type {
    return struct {
        nextFn: *const fn (*Self) ?T,
        context: *anyopaque,

        const Self = @This();

        /// 获取下一个元素
        pub fn next(self: *Self) ?T {
            return self.nextFn(self);
        }

        /// 收集所有元素到 ArrayList
        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }

        /// 收集到切片（调用者负责释放）
        pub fn toSlice(self: *Self, allocator: Allocator) ![]T {
            var list = try self.collect(allocator);
            return list.toOwnedSlice(allocator);
        }

        /// 对每个元素应用函数（副作用）
        pub fn forEach(self: *Self, f: *const fn (T) void) void {
            while (self.next()) |item| {
                f(item);
            }
        }

        /// 折叠/归约操作
        pub fn fold(self: *Self, comptime U: type, initial: U, f: *const fn (U, T) U) U {
            var acc = initial;
            while (self.next()) |item| {
                acc = f(acc, item);
            }
            return acc;
        }

        /// 求和（要求 T 支持加法）
        pub fn sum(self: *Self) T {
            return self.fold(T, 0, struct {
                fn add(acc: T, x: T) T {
                    return acc + x;
                }
            }.add);
        }

        /// 求积（要求 T 支持乘法）
        pub fn product(self: *Self) T {
            return self.fold(T, 1, struct {
                fn mul(acc: T, x: T) T {
                    return acc * x;
                }
            }.mul);
        }

        /// 计数
        pub fn count(self: *Self) usize {
            var n: usize = 0;
            while (self.next()) |_| {
                n += 1;
            }
            return n;
        }

        /// 查找第一个元素
        pub fn first(self: *Self) ?T {
            return self.next();
        }

        /// 查找最后一个元素
        pub fn last(self: *Self) ?T {
            var result: ?T = null;
            while (self.next()) |item| {
                result = item;
            }
            return result;
        }

        /// 查找满足条件的第一个元素
        pub fn find(self: *Self, predicate: *const fn (T) bool) ?T {
            while (self.next()) |item| {
                if (predicate(item)) return item;
            }
            return null;
        }

        /// 检查是否所有元素满足条件
        pub fn all(self: *Self, predicate: *const fn (T) bool) bool {
            while (self.next()) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }

        /// 检查是否存在元素满足条件
        pub fn any(self: *Self, predicate: *const fn (T) bool) bool {
            while (self.next()) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }

        /// 获取第 n 个元素（0-indexed）
        pub fn nth(self: *Self, n: usize) ?T {
            var i: usize = 0;
            while (self.next()) |item| {
                if (i == n) return item;
                i += 1;
            }
            return null;
        }

        /// 检查是否包含某元素
        pub fn contains(self: *Self, value: T) bool {
            while (self.next()) |item| {
                if (item == value) return true;
            }
            return false;
        }

        /// 获取最大值
        pub fn max(self: *Self) ?T {
            var result: ?T = self.next();
            if (result == null) return null;

            while (self.next()) |item| {
                if (item > result.?) {
                    result = item;
                }
            }
            return result;
        }

        /// 获取最小值
        pub fn min(self: *Self) ?T {
            var result: ?T = self.next();
            if (result == null) return null;

            while (self.next()) |item| {
                if (item < result.?) {
                    result = item;
                }
            }
            return result;
        }
    };
}

// ============ 迭代器构造器 ============

/// 从切片创建迭代器
pub fn fromSlice(comptime T: type, slice: []const T) SliceIterator(T) {
    return SliceIterator(T).init(slice);
}

/// 切片迭代器
pub fn SliceIterator(comptime T: type) type {
    return struct {
        slice: []const T,
        index: usize,

        const Self = @This();

        pub fn init(slice: []const T) Self {
            return .{ .slice = slice, .index = 0 };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.slice.len) return null;
            const item = self.slice[self.index];
            self.index += 1;
            return item;
        }

        /// 折叠操作
        pub fn fold(self: *Self, comptime U: type, initial: U, f: *const fn (U, T) U) U {
            var acc = initial;
            while (self.next()) |item| {
                acc = f(acc, item);
            }
            return acc;
        }

        /// 求和
        pub fn sum(self: *Self) T {
            var total: T = 0;
            while (self.next()) |item| {
                total += item;
            }
            return total;
        }

        /// 求积
        pub fn product(self: *Self) T {
            var total: T = 1;
            while (self.next()) |item| {
                total *= item;
            }
            return total;
        }

        /// 计数
        pub fn count(self: *Self) usize {
            var n: usize = 0;
            while (self.next()) |_| {
                n += 1;
            }
            return n;
        }

        /// 收集到 ArrayList
        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }

        /// 查找满足条件的第一个元素
        pub fn find(self: *Self, predicate: *const fn (T) bool) ?T {
            while (self.next()) |item| {
                if (predicate(item)) return item;
            }
            return null;
        }

        /// 检查所有元素是否满足条件
        pub fn all(self: *Self, predicate: *const fn (T) bool) bool {
            while (self.next()) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }

        /// 检查是否存在元素满足条件
        pub fn any(self: *Self, predicate: *const fn (T) bool) bool {
            while (self.next()) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }

        /// 获取最大值
        pub fn max(self: *Self) ?T {
            var result: ?T = self.next();
            if (result == null) return null;

            while (self.next()) |item| {
                if (item > result.?) {
                    result = item;
                }
            }
            return result;
        }

        /// 获取最小值
        pub fn min(self: *Self) ?T {
            var result: ?T = self.next();
            if (result == null) return null;

            while (self.next()) |item| {
                if (item < result.?) {
                    result = item;
                }
            }
            return result;
        }

        /// 重置迭代器
        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

/// Map 迭代器 - 对每个元素应用转换函数
pub fn MapIterator(comptime T: type, comptime U: type) type {
    return struct {
        source: *SliceIterator(T),
        mapFn: *const fn (T) U,

        const Self = @This();

        pub fn init(source: *SliceIterator(T), mapFn: *const fn (T) U) Self {
            return .{ .source = source, .mapFn = mapFn };
        }

        pub fn next(self: *Self) ?U {
            if (self.source.next()) |item| {
                return self.mapFn(item);
            }
            return null;
        }

        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(U) {
            var list = try std.ArrayList(U).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }

        pub fn fold(self: *Self, comptime V: type, initial: V, f: *const fn (V, U) V) V {
            var acc = initial;
            while (self.next()) |item| {
                acc = f(acc, item);
            }
            return acc;
        }
    };
}

/// Filter 迭代器 - 过滤元素
pub fn FilterIterator(comptime T: type) type {
    return struct {
        source: *SliceIterator(T),
        predicate: *const fn (T) bool,

        const Self = @This();

        pub fn init(source: *SliceIterator(T), predicate: *const fn (T) bool) Self {
            return .{ .source = source, .predicate = predicate };
        }

        pub fn next(self: *Self) ?T {
            while (self.source.next()) |item| {
                if (self.predicate(item)) return item;
            }
            return null;
        }

        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }

        pub fn count(self: *Self) usize {
            var n: usize = 0;
            while (self.next()) |_| {
                n += 1;
            }
            return n;
        }
    };
}

/// Take 迭代器 - 只取前 n 个元素
pub fn TakeIterator(comptime T: type) type {
    return struct {
        source: *SliceIterator(T),
        remaining: usize,

        const Self = @This();

        pub fn init(source: *SliceIterator(T), n: usize) Self {
            return .{ .source = source, .remaining = n };
        }

        pub fn next(self: *Self) ?T {
            if (self.remaining == 0) return null;
            self.remaining -= 1;
            return self.source.next();
        }

        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }
    };
}

/// Skip 迭代器 - 跳过前 n 个元素
pub fn SkipIterator(comptime T: type) type {
    return struct {
        source: *SliceIterator(T),
        skipped: bool,
        skip_count: usize,

        const Self = @This();

        pub fn init(source: *SliceIterator(T), n: usize) Self {
            return .{ .source = source, .skipped = false, .skip_count = n };
        }

        pub fn next(self: *Self) ?T {
            if (!self.skipped) {
                var i: usize = 0;
                while (i < self.skip_count) : (i += 1) {
                    _ = self.source.next();
                }
                self.skipped = true;
            }
            return self.source.next();
        }

        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }
    };
}

/// Range 迭代器 - 生成数字范围
pub fn RangeIterator(comptime T: type) type {
    return struct {
        current: T,
        end: T,
        step: T,

        const Self = @This();

        pub fn init(start: T, end: T) Self {
            return .{ .current = start, .end = end, .step = 1 };
        }

        pub fn initWithStep(start: T, end: T, step: T) Self {
            return .{ .current = start, .end = end, .step = step };
        }

        pub fn next(self: *Self) ?T {
            if (self.current >= self.end) return null;
            const result = self.current;
            self.current += self.step;
            return result;
        }

        pub fn sum(self: *Self) T {
            var total: T = 0;
            while (self.next()) |item| {
                total += item;
            }
            return total;
        }

        pub fn collect(self: *Self, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list;
        }
    };
}

/// 创建范围迭代器
pub fn range(comptime T: type, start: T, end: T) RangeIterator(T) {
    return RangeIterator(T).init(start, end);
}

/// 创建带步长的范围迭代器
pub fn rangeStep(comptime T: type, start: T, end: T, step: T) RangeIterator(T) {
    return RangeIterator(T).initWithStep(start, end, step);
}

/// Repeat 迭代器 - 无限重复某个值
pub fn RepeatIterator(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn next(self: *Self) ?T {
            return self.value;
        }

        /// 取前 n 个
        pub fn take(self: *Self, n: usize, allocator: Allocator) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(allocator, 16);
            errdefer list.deinit(allocator);

            var i: usize = 0;
            while (i < n) : (i += 1) {
                try list.append(allocator, self.value);
            }

            return list;
        }
    };
}

/// 创建重复迭代器
pub fn repeat(comptime T: type, value: T) RepeatIterator(T) {
    return RepeatIterator(T).init(value);
}

/// Zip 迭代器 - 合并两个迭代器
pub fn ZipIterator(comptime T: type, comptime U: type) type {
    return struct {
        first: *SliceIterator(T),
        second: *SliceIterator(U),

        const Self = @This();
        const Pair = struct { T, U };

        pub fn init(first: *SliceIterator(T), second: *SliceIterator(U)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn next(self: *Self) ?Pair {
            const a = self.first.next() orelse return null;
            const b = self.second.next() orelse return null;
            return .{ a, b };
        }
    };
}

/// Enumerate 迭代器 - 添加索引
pub fn EnumerateIterator(comptime T: type) type {
    return struct {
        source: *SliceIterator(T),
        index: usize,

        const Self = @This();
        const Indexed = struct { usize, T };

        pub fn init(source: *SliceIterator(T)) Self {
            return .{ .source = source, .index = 0 };
        }

        pub fn next(self: *Self) ?Indexed {
            if (self.source.next()) |item| {
                const result = Indexed{ self.index, item };
                self.index += 1;
                return result;
            }
            return null;
        }
    };
}

// ============ 测试 ============

test "SliceIterator basic" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = fromSlice(i32, &data);

    try std.testing.expectEqual(@as(?i32, 1), iter.next());
    try std.testing.expectEqual(@as(?i32, 2), iter.next());
    try std.testing.expectEqual(@as(?i32, 3), iter.next());
    try std.testing.expectEqual(@as(?i32, 4), iter.next());
    try std.testing.expectEqual(@as(?i32, 5), iter.next());
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "SliceIterator sum" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = fromSlice(i32, &data);

    try std.testing.expectEqual(@as(i32, 15), iter.sum());
}

test "SliceIterator product" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = fromSlice(i32, &data);

    try std.testing.expectEqual(@as(i32, 120), iter.product());
}

test "SliceIterator fold" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = fromSlice(i32, &data);

    const result = iter.fold(i32, 0, struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), result);
}

test "SliceIterator find" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = fromSlice(i32, &data);

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    try std.testing.expectEqual(@as(?i32, 2), iter.find(isEven));
}

test "SliceIterator all/any" {
    const data = [_]i32{ 2, 4, 6, 8 };
    var iter1 = fromSlice(i32, &data);
    var iter2 = fromSlice(i32, &data);

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    const isNegative = struct {
        fn f(x: i32) bool {
            return x < 0;
        }
    }.f;

    try std.testing.expect(iter1.all(isEven));
    try std.testing.expect(!iter2.any(isNegative));
}

test "SliceIterator max/min" {
    const data = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    var iter1 = fromSlice(i32, &data);
    var iter2 = fromSlice(i32, &data);

    try std.testing.expectEqual(@as(?i32, 9), iter1.max());
    try std.testing.expectEqual(@as(?i32, 1), iter2.min());
}

test "SliceIterator collect" {
    const allocator = std.testing.allocator;
    const data = [_]i32{ 1, 2, 3 };
    var iter = fromSlice(i32, &data);

    var list = try iter.collect(allocator);
    defer list.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), list.items.len);
    try std.testing.expectEqual(@as(i32, 1), list.items[0]);
    try std.testing.expectEqual(@as(i32, 2), list.items[1]);
    try std.testing.expectEqual(@as(i32, 3), list.items[2]);
}

test "MapIterator" {
    const data = [_]i32{ 1, 2, 3 };
    var source = fromSlice(i32, &data);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    var mapped = MapIterator(i32, i32).init(&source, double);

    try std.testing.expectEqual(@as(?i32, 2), mapped.next());
    try std.testing.expectEqual(@as(?i32, 4), mapped.next());
    try std.testing.expectEqual(@as(?i32, 6), mapped.next());
    try std.testing.expectEqual(@as(?i32, null), mapped.next());
}

test "FilterIterator" {
    const data = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var source = fromSlice(i32, &data);

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    var filtered = FilterIterator(i32).init(&source, isEven);

    try std.testing.expectEqual(@as(?i32, 2), filtered.next());
    try std.testing.expectEqual(@as(?i32, 4), filtered.next());
    try std.testing.expectEqual(@as(?i32, 6), filtered.next());
    try std.testing.expectEqual(@as(?i32, null), filtered.next());
}

test "TakeIterator" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var source = fromSlice(i32, &data);

    var taken = TakeIterator(i32).init(&source, 3);

    try std.testing.expectEqual(@as(?i32, 1), taken.next());
    try std.testing.expectEqual(@as(?i32, 2), taken.next());
    try std.testing.expectEqual(@as(?i32, 3), taken.next());
    try std.testing.expectEqual(@as(?i32, null), taken.next());
}

test "SkipIterator" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    var source = fromSlice(i32, &data);

    var skipped = SkipIterator(i32).init(&source, 2);

    try std.testing.expectEqual(@as(?i32, 3), skipped.next());
    try std.testing.expectEqual(@as(?i32, 4), skipped.next());
    try std.testing.expectEqual(@as(?i32, 5), skipped.next());
    try std.testing.expectEqual(@as(?i32, null), skipped.next());
}

test "RangeIterator" {
    var iter = range(i32, 0, 5);

    try std.testing.expectEqual(@as(?i32, 0), iter.next());
    try std.testing.expectEqual(@as(?i32, 1), iter.next());
    try std.testing.expectEqual(@as(?i32, 2), iter.next());
    try std.testing.expectEqual(@as(?i32, 3), iter.next());
    try std.testing.expectEqual(@as(?i32, 4), iter.next());
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "RangeIterator sum" {
    var iter = range(i32, 1, 6);
    try std.testing.expectEqual(@as(i32, 15), iter.sum());
}

test "RangeIterator with step" {
    var iter = rangeStep(i32, 0, 10, 2);

    try std.testing.expectEqual(@as(?i32, 0), iter.next());
    try std.testing.expectEqual(@as(?i32, 2), iter.next());
    try std.testing.expectEqual(@as(?i32, 4), iter.next());
    try std.testing.expectEqual(@as(?i32, 6), iter.next());
    try std.testing.expectEqual(@as(?i32, 8), iter.next());
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "RepeatIterator take" {
    const allocator = std.testing.allocator;
    var iter = repeat(i32, 42);

    var list = try iter.take(5, allocator);
    defer list.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 5), list.items.len);
    for (list.items) |item| {
        try std.testing.expectEqual(@as(i32, 42), item);
    }
}

test "ZipIterator" {
    const data1 = [_]i32{ 1, 2, 3 };
    const data2 = [_]i32{ 10, 20, 30 };
    var iter1 = fromSlice(i32, &data1);
    var iter2 = fromSlice(i32, &data2);

    var zipped = ZipIterator(i32, i32).init(&iter1, &iter2);

    const pair1 = zipped.next().?;
    try std.testing.expectEqual(@as(i32, 1), pair1[0]);
    try std.testing.expectEqual(@as(i32, 10), pair1[1]);

    const pair2 = zipped.next().?;
    try std.testing.expectEqual(@as(i32, 2), pair2[0]);
    try std.testing.expectEqual(@as(i32, 20), pair2[1]);

    const pair3 = zipped.next().?;
    try std.testing.expectEqual(@as(i32, 3), pair3[0]);
    try std.testing.expectEqual(@as(i32, 30), pair3[1]);

    try std.testing.expectEqual(@as(?ZipIterator(i32, i32).Pair, null), zipped.next());
}

test "EnumerateIterator" {
    const data = [_]i32{ 10, 20, 30 };
    var source = fromSlice(i32, &data);

    var enumerated = EnumerateIterator(i32).init(&source);

    const item1 = enumerated.next().?;
    try std.testing.expectEqual(@as(usize, 0), item1[0]);
    try std.testing.expectEqual(@as(i32, 10), item1[1]);

    const item2 = enumerated.next().?;
    try std.testing.expectEqual(@as(usize, 1), item2[0]);
    try std.testing.expectEqual(@as(i32, 20), item2[1]);

    const item3 = enumerated.next().?;
    try std.testing.expectEqual(@as(usize, 2), item3[0]);
    try std.testing.expectEqual(@as(i32, 30), item3[1]);
}

test "SliceIterator reset" {
    const data = [_]i32{ 1, 2, 3 };
    var iter = fromSlice(i32, &data);

    _ = iter.next();
    _ = iter.next();
    iter.reset();

    try std.testing.expectEqual(@as(?i32, 1), iter.next());
}
