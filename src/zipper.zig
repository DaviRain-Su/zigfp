//! Zipper 模块
//!
//! Zipper 是一种数据结构，它提供了高效的"焦点"导航和局部更新。
//! 通过维护一个上下文（已访问的部分）和当前焦点，可以在 O(1) 时间内进行局部操作。
//!
//! 主要类型：
//! - `ListZipper(T)` - 列表 Zipper，可以左右移动焦点
//! - `TreeZipper(T)` - 树 Zipper，可以上下左右移动焦点（简化版）
//!
//! Zipper 是 Comonad，可以使用 extract、extend 等操作

const std = @import("std");
const option_mod = @import("option.zig");
const Option = option_mod.Option;

/// 树方向枚举
const TreeDirection = enum { left, right };

// ============ ListZipper ============

/// ListZipper - 列表 Zipper
/// 表示为: 左边元素（逆序）, 焦点, 右边元素
/// 例如: [1, 2, 3, 4, 5] 焦点在 3 表示为:
///   left = [2, 1] (逆序), focus = 3, right = [4, 5]
pub fn ListZipper(comptime T: type) type {
    return struct {
        /// 焦点左边的元素（逆序存储，最近的在前）
        left: []const T,
        /// 当前焦点
        focus: T,
        /// 焦点右边的元素
        right: []const T,
        /// 分配器
        allocator: std.mem.Allocator,

        const Self = @This();

        // ============ 构造器 ============

        /// 从切片创建 Zipper，焦点在指定索引
        pub fn fromSlice(allocator: std.mem.Allocator, items: []const T, focus_idx: usize) !Self {
            if (items.len == 0) {
                return error.EmptySlice;
            }
            if (focus_idx >= items.len) {
                return error.IndexOutOfBounds;
            }

            // 左边元素需要逆序
            var leftList = try std.ArrayList(T).initCapacity(allocator, focus_idx);
            errdefer leftList.deinit(allocator);

            var i: usize = focus_idx;
            while (i > 0) {
                i -= 1;
                try leftList.append(allocator, items[i]);
            }

            // 右边元素保持顺序
            const rightLen = items.len - focus_idx - 1;
            var rightList = try std.ArrayList(T).initCapacity(allocator, rightLen);
            errdefer rightList.deinit(allocator);

            for (items[focus_idx + 1 ..]) |item| {
                try rightList.append(allocator, item);
            }

            return Self{
                .left = try leftList.toOwnedSlice(allocator),
                .focus = items[focus_idx],
                .right = try rightList.toOwnedSlice(allocator),
                .allocator = allocator,
            };
        }

        /// 创建单元素 Zipper
        pub fn singleton(allocator: std.mem.Allocator, value: T) !Self {
            return Self{
                .left = &.{},
                .focus = value,
                .right = &.{},
                .allocator = allocator,
            };
        }

        /// 释放资源
        pub fn deinit(self: Self) void {
            if (self.left.len > 0) {
                self.allocator.free(self.left);
            }
            if (self.right.len > 0) {
                self.allocator.free(self.right);
            }
        }

        // ============ 访问器 ============

        /// 获取焦点元素
        pub fn extract(self: Self) T {
            return self.focus;
        }

        /// 检查是否可以左移
        pub fn canMoveLeft(self: Self) bool {
            return self.left.len > 0;
        }

        /// 检查是否可以右移
        pub fn canMoveRight(self: Self) bool {
            return self.right.len > 0;
        }

        /// 获取焦点索引（在整个列表中的位置）
        pub fn focusIndex(self: Self) usize {
            return self.left.len;
        }

        /// 获取列表总长度
        pub fn length(self: Self) usize {
            return self.left.len + 1 + self.right.len;
        }

        // ============ 移动操作 ============

        /// 左移焦点
        pub fn moveLeft(self: Self) !Self {
            if (self.left.len == 0) {
                return error.AtLeftmost;
            }

            const newFocus = self.left[0];

            // 新的左边是原来左边去掉第一个
            var newLeft = try std.ArrayList(T).initCapacity(self.allocator, self.left.len - 1);
            errdefer newLeft.deinit(self.allocator);
            for (self.left[1..]) |item| {
                try newLeft.append(self.allocator, item);
            }

            // 新的右边是原来的焦点加上原来的右边
            var newRight = try std.ArrayList(T).initCapacity(self.allocator, self.right.len + 1);
            errdefer newRight.deinit(self.allocator);
            try newRight.append(self.allocator, self.focus);
            for (self.right) |item| {
                try newRight.append(self.allocator, item);
            }

            // 释放旧的
            self.deinit();

            return Self{
                .left = try newLeft.toOwnedSlice(self.allocator),
                .focus = newFocus,
                .right = try newRight.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }

        /// 右移焦点
        pub fn moveRight(self: Self) !Self {
            if (self.right.len == 0) {
                return error.AtRightmost;
            }

            const newFocus = self.right[0];

            // 新的左边是原来的焦点加到原来左边的前面
            var newLeft = try std.ArrayList(T).initCapacity(self.allocator, self.left.len + 1);
            errdefer newLeft.deinit(self.allocator);
            try newLeft.append(self.allocator, self.focus);
            for (self.left) |item| {
                try newLeft.append(self.allocator, item);
            }

            // 新的右边是原来右边去掉第一个
            var newRight = try std.ArrayList(T).initCapacity(self.allocator, self.right.len - 1);
            errdefer newRight.deinit(self.allocator);
            for (self.right[1..]) |item| {
                try newRight.append(self.allocator, item);
            }

            // 释放旧的
            self.deinit();

            return Self{
                .left = try newLeft.toOwnedSlice(self.allocator),
                .focus = newFocus,
                .right = try newRight.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }

        /// 移动到最左边
        pub fn moveToLeft(self: Self) !Self {
            var current = self;
            while (current.canMoveLeft()) {
                current = try current.moveLeft();
            }
            return current;
        }

        /// 移动到最右边
        pub fn moveToRight(self: Self) !Self {
            var current = self;
            while (current.canMoveRight()) {
                current = try current.moveRight();
            }
            return current;
        }

        // ============ 修改操作 ============

        /// 修改焦点元素
        pub fn modify(self: Self, f: *const fn (T) T) Self {
            return Self{
                .left = self.left,
                .focus = f(self.focus),
                .right = self.right,
                .allocator = self.allocator,
            };
        }

        /// 设置焦点元素
        pub fn set(self: Self, value: T) Self {
            return Self{
                .left = self.left,
                .focus = value,
                .right = self.right,
                .allocator = self.allocator,
            };
        }

        /// 在焦点左边插入元素
        pub fn insertLeft(self: Self, value: T) !Self {
            var newLeft = try std.ArrayList(T).initCapacity(self.allocator, self.left.len + 1);
            errdefer newLeft.deinit(self.allocator);
            try newLeft.append(self.allocator, value);
            for (self.left) |item| {
                try newLeft.append(self.allocator, item);
            }

            if (self.left.len > 0) {
                self.allocator.free(self.left);
            }

            return Self{
                .left = try newLeft.toOwnedSlice(self.allocator),
                .focus = self.focus,
                .right = self.right,
                .allocator = self.allocator,
            };
        }

        /// 在焦点右边插入元素
        pub fn insertRight(self: Self, value: T) !Self {
            var newRight = try std.ArrayList(T).initCapacity(self.allocator, self.right.len + 1);
            errdefer newRight.deinit(self.allocator);
            try newRight.append(self.allocator, value);
            for (self.right) |item| {
                try newRight.append(self.allocator, item);
            }

            if (self.right.len > 0) {
                self.allocator.free(self.right);
            }

            return Self{
                .left = self.left,
                .focus = self.focus,
                .right = try newRight.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }

        /// 删除焦点元素，焦点移到右边（如果可能）
        pub fn delete(self: Self) !?Self {
            if (self.right.len > 0) {
                // 焦点移到右边
                const newFocus = self.right[0];

                var newRight = try std.ArrayList(T).initCapacity(self.allocator, self.right.len - 1);
                errdefer newRight.deinit(self.allocator);
                for (self.right[1..]) |item| {
                    try newRight.append(self.allocator, item);
                }

                if (self.right.len > 0) {
                    self.allocator.free(self.right);
                }

                return Self{
                    .left = self.left,
                    .focus = newFocus,
                    .right = try newRight.toOwnedSlice(self.allocator),
                    .allocator = self.allocator,
                };
            } else if (self.left.len > 0) {
                // 焦点移到左边
                const newFocus = self.left[0];

                var newLeft = try std.ArrayList(T).initCapacity(self.allocator, self.left.len - 1);
                errdefer newLeft.deinit(self.allocator);
                for (self.left[1..]) |item| {
                    try newLeft.append(self.allocator, item);
                }

                if (self.left.len > 0) {
                    self.allocator.free(self.left);
                }

                return Self{
                    .left = try newLeft.toOwnedSlice(self.allocator),
                    .focus = newFocus,
                    .right = self.right,
                    .allocator = self.allocator,
                };
            } else {
                // 只有一个元素，删除后为空
                return null;
            }
        }

        // ============ 转换操作 ============

        /// 转换回切片
        pub fn toSlice(self: Self) ![]T {
            var result = try std.ArrayList(T).initCapacity(self.allocator, self.length());
            errdefer result.deinit(self.allocator);

            // 左边元素逆序添加
            var i: usize = self.left.len;
            while (i > 0) {
                i -= 1;
                try result.append(self.allocator, self.left[i]);
            }

            // 焦点
            try result.append(self.allocator, self.focus);

            // 右边元素
            for (self.right) |item| {
                try result.append(self.allocator, item);
            }

            return result.toOwnedSlice(self.allocator);
        }

        // ============ Comonad 操作 ============

        /// extend: 对每个位置应用函数
        pub fn extend(self: Self, f: *const fn (Self) T) !Self {
            // 注意：这是一个简化版本，完整实现需要遍历所有位置
            // 这里只修改焦点
            return Self{
                .left = self.left,
                .focus = f(self),
                .right = self.right,
                .allocator = self.allocator,
            };
        }

        /// duplicate: 创建 Zipper 的 Zipper
        /// 简化版本：只返回当前状态的包装
        pub fn duplicate(self: Self) !Self {
            return self;
        }

        // ============ Functor 操作 ============

        /// map: 对所有元素应用函数
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) !ListZipper(U) {
            var newLeft = try std.ArrayList(U).initCapacity(self.allocator, self.left.len);
            errdefer newLeft.deinit(self.allocator);
            for (self.left) |item| {
                try newLeft.append(self.allocator, f(item));
            }

            var newRight = try std.ArrayList(U).initCapacity(self.allocator, self.right.len);
            errdefer newRight.deinit(self.allocator);
            for (self.right) |item| {
                try newRight.append(self.allocator, f(item));
            }

            return ListZipper(U){
                .left = try newLeft.toOwnedSlice(self.allocator),
                .focus = f(self.focus),
                .right = try newRight.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        }
    };
}

// ============ BinaryTree ============

/// 二叉树节点
pub fn BinaryTree(comptime T: type) type {
    return struct {
        value: T,
        left_child: ?*@This(),
        right_child: ?*@This(),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, value: T) !*Self {
            const node = try allocator.create(Self);
            node.* = .{
                .value = value,
                .left_child = null,
                .right_child = null,
            };
            return node;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.left_child) |left| {
                left.deinit(allocator);
            }
            if (self.right_child) |right| {
                right.deinit(allocator);
            }
            allocator.destroy(self);
        }

        pub fn setLeft(self: *Self, allocator: std.mem.Allocator, value: T) !*Self {
            if (self.left_child) |old| {
                old.deinit(allocator);
            }
            self.left_child = try Self.init(allocator, value);
            return self.left_child.?;
        }

        pub fn setRight(self: *Self, allocator: std.mem.Allocator, value: T) !*Self {
            if (self.right_child) |old| {
                old.deinit(allocator);
            }
            self.right_child = try Self.init(allocator, value);
            return self.right_child.?;
        }
    };
}

// ============ TreeZipper (简化版) ============

/// TreeZipper - 树 Zipper（简化实现）
/// 注意：这是概念演示，实际的树 zipper 需要更复杂的内存管理
pub fn TreeZipper(comptime T: type) type {
    return struct {
        /// 当前焦点子树
        focus: *BinaryTree(T),
        /// 分配器
        allocator: std.mem.Allocator,

        const Self = @This();

        // ============ 构造器 ============

        /// 从树根创建 Zipper
        pub fn fromTree(allocator: std.mem.Allocator, tree: *BinaryTree(T)) Self {
            return Self{
                .focus = tree,
                .allocator = allocator,
            };
        }

        /// 释放资源（不释放树本身）
        pub fn deinit(self: Self) void {
            // 简化实现：不管理复杂的状态
            _ = self;
        }

        // ============ 访问器 ============

        /// 获取焦点值
        pub fn extract(self: Self) T {
            return self.focus.value;
        }

        /// 检查是否可以下移到左子树
        pub fn canMoveDown(self: Self) bool {
            return self.focus.left_child != null;
        }

        /// 检查是否可以下移到右子树
        pub fn canMoveDownRight(self: Self) bool {
            return self.focus.right_child != null;
        }

        // ============ 移动操作 ============

        /// 向下移动到左子树
        pub fn moveDownLeft(self: Self) !Self {
            if (self.focus.left_child == null) {
                return error.NoLeftChild;
            }

            return Self{
                .focus = self.focus.left_child.?,
                .allocator = self.allocator,
            };
        }

        /// 向下移动到右子树
        pub fn moveDownRight(self: Self) !Self {
            if (self.focus.right_child == null) {
                return error.NoRightChild;
            }

            return Self{
                .focus = self.focus.right_child.?,
                .allocator = self.allocator,
            };
        }

        // ============ 修改操作 ============

        /// 修改焦点值
        pub fn modify(self: Self, f: *const fn (T) T) Self {
            self.focus.value = f(self.focus.value);
            return self;
        }

        /// 设置焦点值
        pub fn set(self: Self, value: T) Self {
            self.focus.value = value;
            return self;
        }
    };
}

// ============ 便捷函数 ============

/// 创建 ListZipper
pub fn listZipper(comptime T: type, allocator: std.mem.Allocator, items: []const T, focusIndex: usize) !ListZipper(T) {
    return ListZipper(T).fromSlice(allocator, items, focusIndex);
}

/// 创建 TreeZipper
pub fn treeZipper(comptime T: type, allocator: std.mem.Allocator, tree: *BinaryTree(T)) TreeZipper(T) {
    return TreeZipper(T).fromTree(allocator, tree);
}

// ============ 测试 ============

test "ListZipper.fromSlice" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 2);
    defer zipper.deinit();

    try std.testing.expectEqual(@as(i32, 3), zipper.extract());
    try std.testing.expectEqual(@as(usize, 2), zipper.focusIndex());
    try std.testing.expectEqual(@as(usize, 5), zipper.length());
}

test "ListZipper.singleton" {
    const allocator = std.testing.allocator;

    const zipper = try ListZipper(i32).singleton(allocator, 42);
    // singleton 不分配内存，不需要 deinit

    try std.testing.expectEqual(@as(i32, 42), zipper.extract());
    try std.testing.expectEqual(@as(usize, 0), zipper.focusIndex());
    try std.testing.expectEqual(@as(usize, 1), zipper.length());
    try std.testing.expect(!zipper.canMoveLeft());
    try std.testing.expect(!zipper.canMoveRight());
}

test "ListZipper.moveLeft and moveRight" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 2);

    // 焦点在 3
    try std.testing.expectEqual(@as(i32, 3), zipper.extract());

    // 左移到 2
    zipper = try zipper.moveLeft();
    try std.testing.expectEqual(@as(i32, 2), zipper.extract());

    // 左移到 1
    zipper = try zipper.moveLeft();
    try std.testing.expectEqual(@as(i32, 1), zipper.extract());

    // 不能再左移
    try std.testing.expect(!zipper.canMoveLeft());

    // 右移到 2
    zipper = try zipper.moveRight();
    try std.testing.expectEqual(@as(i32, 2), zipper.extract());

    // 右移到 3
    zipper = try zipper.moveRight();
    try std.testing.expectEqual(@as(i32, 3), zipper.extract());

    // 右移到 4
    zipper = try zipper.moveRight();
    try std.testing.expectEqual(@as(i32, 4), zipper.extract());

    // 右移到 5
    zipper = try zipper.moveRight();
    try std.testing.expectEqual(@as(i32, 5), zipper.extract());

    // 不能再右移
    try std.testing.expect(!zipper.canMoveRight());

    zipper.deinit();
}

test "ListZipper.modify" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 2);
    defer zipper.deinit();

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const modified = zipper.modify(&double);
    try std.testing.expectEqual(@as(i32, 6), modified.extract());
}

test "ListZipper.set" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 2);
    defer zipper.deinit();

    const newZipper = zipper.set(100);
    try std.testing.expectEqual(@as(i32, 100), newZipper.extract());
}

test "ListZipper.toSlice" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 2);
    defer zipper.deinit();

    const slice = try zipper.toSlice();
    defer allocator.free(slice);

    try std.testing.expectEqual(@as(usize, 5), slice.len);
    try std.testing.expectEqual(@as(i32, 1), slice[0]);
    try std.testing.expectEqual(@as(i32, 2), slice[1]);
    try std.testing.expectEqual(@as(i32, 3), slice[2]);
    try std.testing.expectEqual(@as(i32, 4), slice[3]);
    try std.testing.expectEqual(@as(i32, 5), slice[4]);
}

test "ListZipper.insertLeft" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 1);

    // 焦点在 2，在左边插入 10
    zipper = try zipper.insertLeft(10);

    const slice = try zipper.toSlice();
    defer allocator.free(slice);
    defer zipper.deinit();

    // 应该是 [1, 10, 2, 3]
    try std.testing.expectEqual(@as(usize, 4), slice.len);
    try std.testing.expectEqual(@as(i32, 1), slice[0]);
    try std.testing.expectEqual(@as(i32, 10), slice[1]);
    try std.testing.expectEqual(@as(i32, 2), slice[2]);
    try std.testing.expectEqual(@as(i32, 3), slice[3]);
}

test "ListZipper.insertRight" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 1);

    // 焦点在 2，在右边插入 10
    zipper = try zipper.insertRight(10);

    const slice = try zipper.toSlice();
    defer allocator.free(slice);
    defer zipper.deinit();

    // 应该是 [1, 2, 10, 3]
    try std.testing.expectEqual(@as(usize, 4), slice.len);
    try std.testing.expectEqual(@as(i32, 1), slice[0]);
    try std.testing.expectEqual(@as(i32, 2), slice[1]);
    try std.testing.expectEqual(@as(i32, 10), slice[2]);
    try std.testing.expectEqual(@as(i32, 3), slice[3]);
}

test "ListZipper.map" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3 };
    var zipper = try ListZipper(i32).fromSlice(allocator, &items, 1);
    defer zipper.deinit();

    const double = struct {
        fn f(x: i32) i64 {
            return @as(i64, x) * 2;
        }
    }.f;

    var mapped = try zipper.map(i64, &double);
    defer mapped.deinit();

    try std.testing.expectEqual(@as(i64, 4), mapped.extract());

    const slice = try mapped.toSlice();
    defer allocator.free(slice);

    try std.testing.expectEqual(@as(i64, 2), slice[0]);
    try std.testing.expectEqual(@as(i64, 4), slice[1]);
    try std.testing.expectEqual(@as(i64, 6), slice[2]);
}

test "BinaryTree basic operations" {
    const allocator = std.testing.allocator;

    var tree = try BinaryTree(i32).init(allocator, 1);
    defer tree.deinit(allocator);

    _ = try tree.setLeft(allocator, 2);
    _ = try tree.setRight(allocator, 3);

    try std.testing.expectEqual(@as(i32, 1), tree.value);
    try std.testing.expectEqual(@as(i32, 2), tree.left_child.?.value);
    try std.testing.expectEqual(@as(i32, 3), tree.right_child.?.value);
}

test "TreeZipper.fromTree and extract" {
    const allocator = std.testing.allocator;

    var tree = try BinaryTree(i32).init(allocator, 1);
    defer tree.deinit(allocator);

    _ = try tree.setLeft(allocator, 2);
    _ = try tree.setRight(allocator, 3);

    const zipper = TreeZipper(i32).fromTree(allocator, tree);

    try std.testing.expectEqual(@as(i32, 1), zipper.extract());
    try std.testing.expect(zipper.canMoveDown());
    try std.testing.expect(zipper.canMoveDownRight());
}

test "TreeZipper navigation" {
    const allocator = std.testing.allocator;

    var tree = try BinaryTree(i32).init(allocator, 1);
    defer tree.deinit(allocator);

    _ = try tree.setLeft(allocator, 2);
    _ = try tree.setRight(allocator, 3);

    var zipper = TreeZipper(i32).fromTree(allocator, tree);

    // 向下移动到左子树
    zipper = try zipper.moveDownLeft();
    try std.testing.expectEqual(@as(i32, 2), zipper.extract());

    // 回到根节点
    zipper = TreeZipper(i32).fromTree(allocator, tree);

    // 向下移动到右子树
    zipper = try zipper.moveDownRight();
    try std.testing.expectEqual(@as(i32, 3), zipper.extract());

    zipper.deinit();
}

test "TreeZipper.modify" {
    const allocator = std.testing.allocator;

    var tree = try BinaryTree(i32).init(allocator, 1);
    defer tree.deinit(allocator);

    var zipper = TreeZipper(i32).fromTree(allocator, tree);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    _ = zipper.modify(&double);
    try std.testing.expectEqual(@as(i32, 2), zipper.extract());
}

test "TreeZipper.set" {
    const allocator = std.testing.allocator;

    var tree = try BinaryTree(i32).init(allocator, 1);
    defer tree.deinit(allocator);

    var zipper = TreeZipper(i32).fromTree(allocator, tree);

    _ = zipper.set(100);
    try std.testing.expectEqual(@as(i32, 100), zipper.extract());
}

test "listZipper convenience function" {
    const allocator = std.testing.allocator;

    const items = [_]i32{ 1, 2, 3 };
    var zipper = try listZipper(i32, allocator, &items, 1);
    defer zipper.deinit();

    try std.testing.expectEqual(@as(i32, 2), zipper.extract());
}
