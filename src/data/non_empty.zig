//! NonEmptyList - 保证非空的列表类型
//!
//! `NonEmptyList(T)` 是一个至少包含一个元素的列表。
//! 与普通切片不同，它保证永远非空，因此 `head` 和 `last` 等操作总是成功。
//!
//! ## 示例
//!
//! ```zig
//! const nel = NonEmptyList(i32).singleton(1)
//!     .cons(allocator, 2)
//!     .cons(allocator, 3);  // [3, 2, 1]
//!
//! const first = nel.head();  // 3 (总是成功)
//! const sum = nel.foldl1(add);  // 6
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Option = @import("../core/option.zig").Option;

/// NonEmptyList - 非空列表
pub fn NonEmptyList(comptime T: type) type {
    return struct {
        /// 第一个元素（保证存在）
        head_val: T,
        /// 剩余元素（可以为空）
        tail_slice: []const T,
        /// 分配器（用于动态操作）
        allocator: ?Allocator,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建单元素非空列表
        pub fn singleton(value: T) Self {
            return .{
                .head_val = value,
                .tail_slice = &[_]T{},
                .allocator = null,
            };
        }

        /// 从头元素和尾部切片创建
        pub fn init(head_val: T, tail_slice: []const T) Self {
            return .{
                .head_val = head_val,
                .tail_slice = tail_slice,
                .allocator = null,
            };
        }

        /// 从切片创建（可能失败）
        pub fn fromSlice(slice: []const T) Option(Self) {
            if (slice.len == 0) {
                return Option(Self).None();
            }
            return Option(Self).Some(.{
                .head_val = slice[0],
                .tail_slice = slice[1..],
                .allocator = null,
            });
        }

        /// 从切片创建，使用分配器复制数据
        pub fn fromSliceAlloc(allocator: Allocator, slice: []const T) !?Self {
            if (slice.len == 0) {
                return null;
            }
            const new_tail = if (slice.len > 1)
                try allocator.dupe(T, slice[1..])
            else
                &[_]T{};

            return Self{
                .head_val = slice[0],
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        // ============ 访问操作 ============

        /// 获取第一个元素（总是成功）
        pub fn head(self: Self) T {
            return self.head_val;
        }

        /// 获取剩余元素（作为切片，可能为空）
        pub fn tail(self: Self) []const T {
            return self.tail_slice;
        }

        /// 获取最后一个元素（总是成功）
        pub fn last(self: Self) T {
            if (self.tail_slice.len == 0) {
                return self.head_val;
            }
            return self.tail_slice[self.tail_slice.len - 1];
        }

        /// 获取除最后一个元素外的所有元素
        pub fn initSlice(self: Self) []const T {
            if (self.tail_slice.len == 0) {
                return &[_]T{};
            }
            // 返回 head + tail[0..len-1]
            // 由于内存布局问题，这里需要特殊处理
            return self.tail_slice[0 .. self.tail_slice.len - 1];
        }

        /// 获取列表长度（总是 >= 1）
        pub fn len(self: Self) usize {
            return 1 + self.tail_slice.len;
        }

        /// 转换为切片（需要分配器）
        pub fn toSlice(self: Self, allocator: Allocator) ![]T {
            const result = try allocator.alloc(T, self.len());
            result[0] = self.head_val;
            if (self.tail_slice.len > 0) {
                @memcpy(result[1..], self.tail_slice);
            }
            return result;
        }

        /// 按索引获取元素
        pub fn get(self: Self, index: usize) Option(T) {
            if (index == 0) {
                return Option(T).Some(self.head_val);
            }
            if (index - 1 < self.tail_slice.len) {
                return Option(T).Some(self.tail_slice[index - 1]);
            }
            return Option(T).None();
        }

        // ============ 修改操作 ============

        /// 在头部添加元素（返回新列表，需要分配器）
        pub fn cons(self: Self, allocator: Allocator, value: T) !Self {
            // 新的 tail = [old_head] ++ old_tail
            const new_tail = try allocator.alloc(T, self.len());
            new_tail[0] = self.head_val;
            if (self.tail_slice.len > 0) {
                @memcpy(new_tail[1..], self.tail_slice);
            }

            return Self{
                .head_val = value,
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        /// 在尾部添加元素
        pub fn snoc(self: Self, allocator: Allocator, value: T) !Self {
            const new_tail = try allocator.alloc(T, self.tail_slice.len + 1);
            if (self.tail_slice.len > 0) {
                @memcpy(new_tail[0..self.tail_slice.len], self.tail_slice);
            }
            new_tail[self.tail_slice.len] = value;

            return Self{
                .head_val = self.head_val,
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        /// 连接两个非空列表
        pub fn append(self: Self, allocator: Allocator, other: Self) !Self {
            // new_tail = old_tail ++ [other.head] ++ other.tail
            const new_len = self.tail_slice.len + 1 + other.tail_slice.len;
            const new_tail = try allocator.alloc(T, new_len);

            var pos: usize = 0;
            if (self.tail_slice.len > 0) {
                @memcpy(new_tail[0..self.tail_slice.len], self.tail_slice);
                pos = self.tail_slice.len;
            }
            new_tail[pos] = other.head_val;
            pos += 1;
            if (other.tail_slice.len > 0) {
                @memcpy(new_tail[pos..], other.tail_slice);
            }

            return Self{
                .head_val = self.head_val,
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        /// 反转列表
        /// [1, 2, 3] -> [3, 2, 1]
        pub fn reverse(self: Self, allocator: Allocator) !Self {
            if (self.tail_slice.len == 0) {
                return self;
            }

            const new_tail = try allocator.alloc(T, self.tail_slice.len);
            // new_head = last element of original list
            const new_head = self.tail_slice[self.tail_slice.len - 1];

            // new_tail should be: tail[len-2..0] ++ [head]
            // For [1, 2, 3]: head=1, tail=[2, 3]
            // reverse should be: head=3, tail=[2, 1]
            // So new_tail[0] = tail[len-2] = 2, new_tail[1] = head = 1

            // 复制 tail[0..len-1] 的反向，然后是 head
            for (0..self.tail_slice.len - 1) |i| {
                new_tail[i] = self.tail_slice[self.tail_slice.len - 2 - i];
            }
            new_tail[self.tail_slice.len - 1] = self.head_val;

            return Self{
                .head_val = new_head,
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        // ============ 函数式操作 ============

        /// 映射操作
        pub fn map(self: Self, allocator: Allocator, comptime U: type, f: *const fn (T) U) !NonEmptyList(U) {
            const new_tail = try allocator.alloc(U, self.tail_slice.len);
            for (self.tail_slice, 0..) |item, i| {
                new_tail[i] = f(item);
            }

            return NonEmptyList(U){
                .head_val = f(self.head_val),
                .tail_slice = new_tail,
                .allocator = allocator,
            };
        }

        /// 左折叠（带初始值）
        pub fn foldl(self: Self, comptime U: type, initial: U, f: *const fn (U, T) U) U {
            var acc = f(initial, self.head_val);
            for (self.tail_slice) |item| {
                acc = f(acc, item);
            }
            return acc;
        }

        /// 左折叠（无初始值，使用第一个元素）
        pub fn foldl1(self: Self, f: *const fn (T, T) T) T {
            var acc = self.head_val;
            for (self.tail_slice) |item| {
                acc = f(acc, item);
            }
            return acc;
        }

        /// 右折叠（带初始值）
        pub fn foldr(self: Self, comptime U: type, initial: U, f: *const fn (T, U) U) U {
            var acc = initial;
            // 从尾部开始
            var i: usize = self.tail_slice.len;
            while (i > 0) {
                i -= 1;
                acc = f(self.tail_slice[i], acc);
            }
            acc = f(self.head_val, acc);
            return acc;
        }

        /// 右折叠（无初始值）
        pub fn foldr1(self: Self, f: *const fn (T, T) T) T {
            if (self.tail_slice.len == 0) {
                return self.head_val;
            }

            var acc = self.tail_slice[self.tail_slice.len - 1];
            var i: usize = self.tail_slice.len - 1;
            while (i > 0) {
                i -= 1;
                acc = f(self.tail_slice[i], acc);
            }
            acc = f(self.head_val, acc);
            return acc;
        }

        /// 过滤（返回 Option，因为结果可能为空）
        pub fn filter(self: Self, allocator: Allocator, predicate: *const fn (T) bool) !Option(Self) {
            var result = try std.ArrayList(T).initCapacity(allocator, self.len());
            errdefer result.deinit(allocator);

            if (predicate(self.head_val)) {
                try result.append(allocator, self.head_val);
            }
            for (self.tail_slice) |item| {
                if (predicate(item)) {
                    try result.append(allocator, item);
                }
            }

            if (result.items.len == 0) {
                result.deinit(allocator);
                return Option(Self).None();
            }

            // 头部元素
            const head_element = result.items[0];

            // 复制尾部到新的切片
            const tail_len = result.items.len - 1;
            const new_tail = if (tail_len > 0)
                try allocator.dupe(T, result.items[1..])
            else
                &[_]T{};

            result.deinit(allocator);

            return Option(Self).Some(Self{
                .head_val = head_element,
                .tail_slice = new_tail,
                .allocator = if (tail_len > 0) allocator else null,
            });
        }

        /// 对每个元素执行副作用
        pub fn forEach(self: Self, f: *const fn (T) void) void {
            f(self.head_val);
            for (self.tail_slice) |item| {
                f(item);
            }
        }

        /// 检查是否所有元素满足谓词
        pub fn all(self: Self, predicate: *const fn (T) bool) bool {
            if (!predicate(self.head_val)) return false;
            for (self.tail_slice) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }

        /// 检查是否存在元素满足谓词
        pub fn any(self: Self, predicate: *const fn (T) bool) bool {
            if (predicate(self.head_val)) return true;
            for (self.tail_slice) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }

        /// 查找第一个满足谓词的元素
        pub fn find(self: Self, predicate: *const fn (T) bool) Option(T) {
            if (predicate(self.head_val)) return Option(T).Some(self.head_val);
            for (self.tail_slice) |item| {
                if (predicate(item)) return Option(T).Some(item);
            }
            return Option(T).None();
        }

        // ============ 释放资源 ============

        /// 释放分配的内存
        pub fn deinit(self: Self) void {
            if (self.allocator) |alloc| {
                if (self.tail_slice.len > 0) {
                    alloc.free(self.tail_slice);
                }
            }
        }
    };
}

// ============ 辅助函数 ============

/// 从数组创建非空列表
pub fn nonEmptyFromArray(comptime T: type, comptime N: usize, arr: *const [N]T) NonEmptyList(T) {
    if (N == 0) {
        @compileError("Cannot create NonEmptyList from empty array");
    }
    return NonEmptyList(T).init(arr[0], arr[1..]);
}

// ============ 测试 ============

test "NonEmptyList.singleton" {
    const nel = NonEmptyList(i32).singleton(42);
    try std.testing.expectEqual(@as(i32, 42), nel.head());
    try std.testing.expectEqual(@as(usize, 1), nel.len());
    try std.testing.expectEqual(@as(usize, 0), nel.tail().len);
}

test "NonEmptyList.init" {
    const tail = [_]i32{ 2, 3, 4 };
    const nel = NonEmptyList(i32).init(1, &tail);

    try std.testing.expectEqual(@as(i32, 1), nel.head());
    try std.testing.expectEqual(@as(usize, 4), nel.len());
    try std.testing.expectEqualSlices(i32, &tail, nel.tail());
}

test "NonEmptyList.fromSlice" {
    // 非空切片
    const slice = [_]i32{ 1, 2, 3 };
    const nel = NonEmptyList(i32).fromSlice(&slice);
    try std.testing.expect(nel.isSome());
    try std.testing.expectEqual(@as(i32, 1), nel.unwrap().head());
    try std.testing.expectEqual(@as(usize, 3), nel.unwrap().len());

    // 空切片
    const empty: []const i32 = &[_]i32{};
    const nel_empty = NonEmptyList(i32).fromSlice(empty);
    try std.testing.expect(nel_empty.isNone());
}

test "NonEmptyList.head and last" {
    const tail = [_]i32{ 2, 3, 4 };
    const nel = NonEmptyList(i32).init(1, &tail);

    try std.testing.expectEqual(@as(i32, 1), nel.head());
    try std.testing.expectEqual(@as(i32, 4), nel.last());

    // 单元素
    const single = NonEmptyList(i32).singleton(42);
    try std.testing.expectEqual(@as(i32, 42), single.head());
    try std.testing.expectEqual(@as(i32, 42), single.last());
}

test "NonEmptyList.get" {
    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);

    try std.testing.expectEqual(@as(i32, 1), nel.get(0).unwrap());
    try std.testing.expectEqual(@as(i32, 2), nel.get(1).unwrap());
    try std.testing.expectEqual(@as(i32, 3), nel.get(2).unwrap());
    try std.testing.expect(nel.get(3).isNone());
}

test "NonEmptyList.cons" {
    const allocator = std.testing.allocator;

    const nel = NonEmptyList(i32).singleton(3);
    const nel2 = try nel.cons(allocator, 2);
    defer nel2.deinit();
    const nel3 = try nel2.cons(allocator, 1);
    defer nel3.deinit();

    try std.testing.expectEqual(@as(i32, 1), nel3.head());
    try std.testing.expectEqual(@as(usize, 3), nel3.len());
    try std.testing.expectEqual(@as(i32, 2), nel3.get(1).unwrap());
    try std.testing.expectEqual(@as(i32, 3), nel3.get(2).unwrap());
}

test "NonEmptyList.snoc" {
    const allocator = std.testing.allocator;

    const nel = NonEmptyList(i32).singleton(1);
    const nel2 = try nel.snoc(allocator, 2);
    defer nel2.deinit();

    try std.testing.expectEqual(@as(i32, 1), nel2.head());
    try std.testing.expectEqual(@as(i32, 2), nel2.last());
    try std.testing.expectEqual(@as(usize, 2), nel2.len());
}

test "NonEmptyList.append" {
    const allocator = std.testing.allocator;

    const tail1 = [_]i32{2};
    const nel1 = NonEmptyList(i32).init(1, &tail1);
    const tail2 = [_]i32{4};
    const nel2 = NonEmptyList(i32).init(3, &tail2);

    const combined = try nel1.append(allocator, nel2);
    defer combined.deinit();

    try std.testing.expectEqual(@as(usize, 4), combined.len());
    try std.testing.expectEqual(@as(i32, 1), combined.get(0).unwrap());
    try std.testing.expectEqual(@as(i32, 2), combined.get(1).unwrap());
    try std.testing.expectEqual(@as(i32, 3), combined.get(2).unwrap());
    try std.testing.expectEqual(@as(i32, 4), combined.get(3).unwrap());
}

test "NonEmptyList.reverse" {
    const allocator = std.testing.allocator;

    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);
    const reversed = try nel.reverse(allocator);
    defer reversed.deinit();

    try std.testing.expectEqual(@as(i32, 3), reversed.head());
    try std.testing.expectEqual(@as(i32, 2), reversed.get(1).unwrap());
    try std.testing.expectEqual(@as(i32, 1), reversed.last());
}

test "NonEmptyList.map" {
    const allocator = std.testing.allocator;

    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const doubled = try nel.map(allocator, i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer doubled.deinit();

    try std.testing.expectEqual(@as(i32, 2), doubled.head());
    try std.testing.expectEqual(@as(i32, 4), doubled.get(1).unwrap());
    try std.testing.expectEqual(@as(i32, 6), doubled.get(2).unwrap());
}

test "NonEmptyList.foldl and foldl1" {
    const tail = [_]i32{ 2, 3, 4 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    // foldl with initial
    const sum_with_init = nel.foldl(i32, 10, add);
    try std.testing.expectEqual(@as(i32, 20), sum_with_init); // 10 + 1 + 2 + 3 + 4

    // foldl1 without initial
    const sum = nel.foldl1(add);
    try std.testing.expectEqual(@as(i32, 10), sum); // 1 + 2 + 3 + 4
}

test "NonEmptyList.foldr and foldr1" {
    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const sub = struct {
        fn f(a: i32, b: i32) i32 {
            return a - b;
        }
    }.f;

    // foldr: 1 - (2 - (3 - 0)) = 1 - (2 - 3) = 1 - (-1) = 2
    const foldr_result = nel.foldr(i32, 0, sub);
    try std.testing.expectEqual(@as(i32, 2), foldr_result);

    // foldr1: 1 - (2 - 3) = 1 - (-1) = 2
    const foldr1_result = nel.foldr1(sub);
    try std.testing.expectEqual(@as(i32, 2), foldr1_result);
}

test "NonEmptyList.filter" {
    const allocator = std.testing.allocator;

    const tail = [_]i32{ 2, 3, 4, 5 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    const filtered = try nel.filter(allocator, isEven);
    try std.testing.expect(filtered.isSome());
    const result = filtered.unwrap();
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.len());
    try std.testing.expectEqual(@as(i32, 2), result.head());
    try std.testing.expectEqual(@as(i32, 4), result.last());
}

test "NonEmptyList.filter to empty" {
    const allocator = std.testing.allocator;

    const nel = NonEmptyList(i32).singleton(1);

    const isNegative = struct {
        fn f(x: i32) bool {
            return x < 0;
        }
    }.f;

    const filtered = try nel.filter(allocator, isNegative);
    try std.testing.expect(filtered.isNone());
}

test "NonEmptyList.all and any" {
    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    try std.testing.expect(nel.all(isPositive));
    try std.testing.expect(!nel.all(isEven));
    try std.testing.expect(nel.any(isEven));
}

test "NonEmptyList.find" {
    const tail = [_]i32{ 2, 3, 4 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    const found = nel.find(isEven);
    try std.testing.expect(found.isSome());
    try std.testing.expectEqual(@as(i32, 2), found.unwrap());
}

test "NonEmptyList.toSlice" {
    const allocator = std.testing.allocator;

    const tail = [_]i32{ 2, 3 };
    const nel = NonEmptyList(i32).init(1, &tail);

    const slice = try nel.toSlice(allocator);
    defer allocator.free(slice);

    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, slice);
}

test "nonEmptyFromArray" {
    const arr = [_]i32{ 1, 2, 3 };
    const nel = nonEmptyFromArray(i32, 3, &arr);

    try std.testing.expectEqual(@as(i32, 1), nel.head());
    try std.testing.expectEqual(@as(usize, 3), nel.len());
}
