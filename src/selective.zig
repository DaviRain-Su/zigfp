//! Selective Applicative Functors 模块
//!
//! Selective 是介于 Applicative 和 Monad 之间的抽象。
//! 它允许基于条件进行选择，而不需要完整的 Monad 能力。
//!
//! 核心操作:
//! - `select` - 基于Either进行条件选择
//! - `branch` - 分支选择
//! - `ifS` - 条件选择
//! - `selectM` - 选择多个选项
//!
//! 与 Applicative 和 Monad 的关系:
//! - Functor ⊂ Applicative ⊂ Selective ⊂ Monad

const std = @import("std");
const Option = @import("option.zig").Option;

/// Either 类型用于选择操作
pub fn Either(comptime A: type, comptime B: type) type {
    return union(enum) {
        left: A,
        right: B,
    };
}

/// Selective 工具集合
/// 实现选择性应用函子操作
pub const selective = struct {
    /// Option Selective 实现
    pub const option = struct {
        /// select: Option(Either(A, B)) → (A → Option(B)) → Option(B)
        /// 基于Either进行条件选择
        pub fn select(
            comptime A: type,
            comptime B: type,
            opt_either: Option(Either(A, B)),
            selector: *const fn (A) Option(B),
        ) Option(B) {
            return switch (opt_either) {
                .some => |either| switch (either) {
                    .left => |a| selector(a),
                    .right => |b| Option(B).Some(b),
                },
                .none => Option(B).None(),
            };
        }

        /// branch: Option(Either(A, B)) → (A → Option(C)) → (B → Option(C)) → Option(C)
        /// 分支选择 - 为左右分支提供不同的处理函数
        pub fn branch(
            comptime A: type,
            comptime B: type,
            comptime C: type,
            opt_either: Option(Either(A, B)),
            left_handler: *const fn (A) Option(C),
            right_handler: *const fn (B) Option(C),
        ) Option(C) {
            return switch (opt_either) {
                .some => |either| switch (either) {
                    .left => |a| left_handler(a),
                    .right => |b| right_handler(b),
                },
                .none => Option(C).None(),
            };
        }

        /// ifS: Option(Bool) → Option(A) → Option(A) → Option(A)
        /// 条件选择 - 基于布尔值选择不同选项
        pub fn ifS(
            comptime A: type,
            opt_condition: Option(bool),
            then_branch: Option(A),
            else_branch: Option(A),
        ) Option(A) {
            return switch (opt_condition) {
                .some => |condition| if (condition) then_branch else else_branch,
                .none => Option(A).None(),
            };
        }

        /// whenS: Option(Bool) → Option(Unit) → Option(Unit)
        /// 当条件为真时执行操作
        pub fn whenS(
            opt_condition: Option(bool),
            action: Option(void),
        ) Option(void) {
            return ifS(void, opt_condition, action, Option(void).Some({}));
        }

        /// selectM: Select first successful option from multiple choices
        pub fn selectM(
            comptime A: type,
            comptime B: type,
            options: []const Option(Either(A, B)),
            selector: *const fn (A) Option(B),
        ) Option(B) {
            for (options) |opt| {
                const result = select(A, B, opt, selector);
                if (result.isSome()) {
                    return result;
                }
            }
            return Option(B).None();
        }
    };
};

// ============ 便捷函数 ============

/// Option select 操作
pub fn selectOption(
    comptime A: type,
    comptime B: type,
    opt_either: Option(Either(A, B)),
    selector: *const fn (A) Option(B),
) Option(B) {
    return selective.option.select(A, B, opt_either, selector);
}

/// Option branch 操作
pub fn branchOption(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    opt_either: Option(Either(A, B)),
    left_handler: *const fn (A) Option(C),
    right_handler: *const fn (B) Option(C),
) Option(C) {
    return selective.option.branch(A, B, C, opt_either, left_handler, right_handler);
}

/// Option ifS 操作
pub fn ifSOption(
    comptime A: type,
    opt_condition: Option(bool),
    then_branch: Option(A),
    else_branch: Option(A),
) Option(A) {
    return selective.option.ifS(A, opt_condition, then_branch, else_branch);
}

/// Option whenS 操作
pub fn whenSOption(
    opt_condition: Option(bool),
    action: Option(void),
) Option(void) {
    return selective.option.whenS(opt_condition, action);
}

/// Option selectM 操作
pub fn selectMOption(
    comptime A: type,
    comptime B: type,
    options: []const Option(Either(A, B)),
    selector: *const fn (A) Option(B),
) Option(B) {
    return selective.option.selectM(A, B, options, selector);
}

// ============ 高级组合 ============

/// Selective 组合工具
pub const combinators = struct {
    /// 从Either创建选择器
    pub fn eitherToSelector(
        comptime A: type,
        comptime B: type,
        either: Either(A, B),
    ) Option(Either(A, B)) {
        return Option(Either(A, B)).Some(either);
    }

    /// 创建条件选择器
    pub fn conditionalSelector(
        comptime A: type,
        comptime B: type,
        condition: bool,
        left_value: A,
        right_value: B,
    ) Option(Either(A, B)) {
        const either = if (condition)
            Either(A, B){ .left = left_value }
        else
            Either(A, B){ .right = right_value };
        return Option(Either(A, B)).Some(either);
    }

    /// 选择第一个成功的选项
    pub fn firstSuccess(
        comptime A: type,
        comptime B: type,
        attempts: []const Option(Either(A, B)),
        selector: *const fn (A) Option(B),
    ) Option(B) {
        for (attempts) |attempt| {
            const result = selectOption(A, B, attempt, selector);
            if (result.isSome()) {
                return result;
            }
        }
        return Option(B).None();
    }

    /// 条件执行多个操作
    pub fn conditionalExecution(
        conditions: []const Option(bool),
        actions: []const Option(void),
    ) Option(void) {
        std.debug.assert(conditions.len == actions.len);

        for (conditions, actions) |condition, action| {
            const result = whenSOption(condition, action);
            if (result.isNone()) {
                return Option(void).None();
            }
        }
        return Option(void).Some({});
    }
};

// ============ 实用示例 ============

/// 解析示例：根据输入选择不同的解析策略
pub const parsing = struct {
    /// 简单的数值解析器选择器
    pub fn parseNumber(input: []const u8) Option(i32) {
        // 尝试不同的解析策略
        const strategies = [_]Option(Either([]const u8, i32)){
            Option(Either([]const u8, i32)).Some(Either([]const u8, i32){ .left = input }), // 尝试解析
        };

        const selector = struct {
            fn selectStrategy(s: []const u8) Option(i32) {
                // 简单的解析逻辑
                if (std.mem.eql(u8, s, "42")) {
                    return Option(i32).Some(42);
                } else if (std.mem.eql(u8, s, "24")) {
                    return Option(i32).Some(24);
                }
                return Option(i32).None();
            }
        }.selectStrategy;

        return selectMOption([]const u8, i32, &strategies, selector);
    }
};

// ============ 测试 ============

test "Option select - left case" {
    const either_left = Either(i32, []const u8){ .left = 42 };
    const opt_either = Option(Either(i32, []const u8)).Some(either_left);

    const selector = struct {
        fn selectLeft(x: i32) Option([]const u8) {
            _ = x;
            return Option([]const u8).Some("selected");
        }
    }.selectLeft;

    const result = selective.option.select(i32, []const u8, opt_either, selector);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("selected", result.unwrap());
}

test "Option select - right case" {
    const either_right = Either(i32, []const u8){ .right = "hello" };
    const opt_either = Option(Either(i32, []const u8)).Some(either_right);

    const selector = struct {
        fn selectLeft(x: i32) Option([]const u8) {
            _ = x;
            return Option([]const u8).Some("left");
        }
    }.selectLeft;

    const result = selective.option.select(i32, []const u8, opt_either, selector);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("hello", result.unwrap());
}

test "Option select - none case" {
    const opt_none = Option(Either(i32, []const u8)).None();

    const selector = struct {
        fn selectLeft(x: i32) Option([]const u8) {
            _ = x;
            return Option([]const u8).Some("left");
        }
    }.selectLeft;

    const result = selective.option.select(i32, []const u8, opt_none, selector);
    try std.testing.expect(result.isNone());
}

test "Option branch" {
    const either_left = Either(i32, bool){ .left = 42 };
    const opt_either = Option(Either(i32, bool)).Some(either_left);

    const left_handler = struct {
        fn handleLeft(x: i32) Option([]const u8) {
            _ = x;
            return Option([]const u8).Some("left_handled");
        }
    }.handleLeft;

    const right_handler = struct {
        fn handleRight(b: bool) Option([]const u8) {
            return Option([]const u8).Some(if (b) "true" else "false");
        }
    }.handleRight;

    const result = selective.option.branch(i32, bool, []const u8, opt_either, left_handler, right_handler);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("left_handled", result.unwrap());
}

test "Option ifS" {
    const condition_true = Option(bool).Some(true);
    const condition_false = Option(bool).Some(false);
    const condition_none = Option(bool).None();

    const then_val = Option(i32).Some(42);
    const else_val = Option(i32).Some(24);

    const result_true = selective.option.ifS(i32, condition_true, then_val, else_val);
    try std.testing.expect(result_true.isSome());
    try std.testing.expectEqual(@as(i32, 42), result_true.unwrap());

    const result_false = selective.option.ifS(i32, condition_false, then_val, else_val);
    try std.testing.expect(result_false.isSome());
    try std.testing.expectEqual(@as(i32, 24), result_false.unwrap());

    const result_none = selective.option.ifS(i32, condition_none, then_val, else_val);
    try std.testing.expect(result_none.isNone());
}

test "Option whenS" {
    const condition_true = Option(bool).Some(true);
    const condition_false = Option(bool).Some(false);

    const action = Option(void).Some({});

    const result_true = selective.option.whenS(condition_true, action);
    try std.testing.expect(result_true.isSome());

    const result_false = selective.option.whenS(condition_false, action);
    try std.testing.expect(result_false.isSome());
}

test "convenience functions" {
    const either_left = Either(i32, []const u8){ .left = 42 };
    const opt_either = Option(Either(i32, []const u8)).Some(either_left);

    const selector = struct {
        fn selectLeft(x: i32) Option([]const u8) {
            _ = x;
            return Option([]const u8).Some("selected");
        }
    }.selectLeft;

    const result = selectOption(i32, []const u8, opt_either, selector);
    try std.testing.expect(result.isSome());
}

test "combinators - conditionalSelector" {
    const selector = combinators.conditionalSelector(i32, []const u8, true, 42, "default");

    try std.testing.expect(selector.isSome());
    const either = selector.unwrap();
    try std.testing.expectEqual(@as(i32, 42), either.left);
}

test "parsing example" {
    const result1 = parsing.parseNumber("42");
    try std.testing.expect(result1.isSome());
    try std.testing.expectEqual(@as(i32, 42), result1.unwrap());

    const result2 = parsing.parseNumber("24");
    try std.testing.expect(result2.isSome());
    try std.testing.expectEqual(@as(i32, 24), result2.unwrap());

    const result3 = parsing.parseNumber("invalid");
    try std.testing.expect(result3.isNone());
}
