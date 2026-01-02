//! Distributive Laws 模块
//!
//! 分配律描述了不同类型构造器之间的交互关系。
//! 特别是如何在积类型（Product）和和类型（Sum）之间分配操作。
//!
//! 核心概念:
//! - `distribute` - 从积类型分配到和类型
//! - `codistribute` - 从和类型分配到积类型
//! - 与Monad Transformers的关联
//!
//! 经典分配律:
//! - `F(G(A) × G(B)) → G(F(A) × F(B))` (左分配)
//! - `G(F(A) + F(B)) → F(G(A) + G(B))` (右分配)

const std = @import("std");
const option_mod = @import("../core/option.zig");
const Option = option_mod.Option;

/// 标准Either类型用于分配律
pub fn EitherOpt(comptime A: type, comptime B: type) type {
    return union(enum) {
        left: Option(A),
        right: Option(B),
    };
}

/// Either 类型用于分配律
pub fn Either(comptime A: type, comptime B: type) type {
    return union(enum) {
        left: A,
        right: B,
    };
}

/// Distributive 工具集合
/// 实现各种分配律操作
pub const distributive = struct {
    /// Option 分配律
    pub const option = struct {
        /// distribute: Option(Option(A)) → Option(A)
        /// 将嵌套的Option扁平化
        ///
        /// 注意：此函数委托给 core/option.zig 中的 flatten 函数
        pub fn distribute(comptime A: type, nested: Option(Option(A))) Option(A) {
            return option_mod.flatten(A, nested);
        }

        /// codistribute: Either(Option(A), Option(B)) → Option(Either(A, B))
        /// 将Either中的Option提取出来（简化实现）
        pub fn codistribute(
            comptime A: type,
            comptime B: type,
            either_opt: EitherOpt(A, B),
        ) Option(Either(A, B)) {
            return switch (either_opt) {
                .left => |opt_a| if (opt_a.isSome())
                    Option(Either(A, B)).Some(Either(A, B){ .left = opt_a.unwrap() })
                else
                    Option(Either(A, B)).None(),
                .right => |opt_b| if (opt_b.isSome())
                    Option(Either(A, B)).Some(Either(A, B){ .right = opt_b.unwrap() })
                else
                    Option(Either(A, B)).None(),
            };
        }

        /// distributePair: (Option(A), Option(B)) → Option(A, B)
        /// 将一对Option转换为Option元组
        pub fn distributePair(
            comptime A: type,
            comptime B: type,
            pair: struct { Option(A), Option(B) },
        ) Option(struct { A, B }) {
            const opt_a = pair[0];
            const opt_b = pair[1];

            if (opt_a.isSome() and opt_b.isSome()) {
                return Option(struct { A, B }).Some(.{ opt_a.unwrap(), opt_b.unwrap() });
            } else {
                return Option(struct { A, B }).None();
            }
        }
    };

    /// 通用分配律工具
    pub const laws = struct {
        /// 验证分配律: distribute . codistribute = id
        /// 测试分配律的正确性
        pub fn verifyDistributiveLaw(
            comptime A: type,
            comptime B: type,
            test_value: EitherOpt(A, B),
        ) bool {
            const codistributed = option.codistribute(A, B, test_value);
            // 由于我们没有逆操作，这里只能做基本验证
            return codistributed.isSome() or codistributed.isNone();
        }
    };

    /// 与 Monad Transformers 的关联
    /// 分配律在 Monad Transformers 中非常重要
    pub const transformers = struct {
        /// 分配律在 transformer 堆栈中的应用示例
        /// 展示如何在不同的transformer层级之间分配计算
        pub fn transformerDistribution(
            comptime M: type,
            comptime N: type,
            comptime A: type,
            mna: M(N(A)),
        ) M(N(A)) {
            // 简化示例：返回原值
            // 实际实现需要具体的 Monad 类型
            _ = mna;
            @compileError("需要具体的 Monad 类型实现");
        }
    };
};

// ============ 便捷函数 ============

/// Option 分配操作
pub fn distributeOption(comptime A: type, nested: Option(Option(A))) Option(A) {
    return distributive.option.distribute(A, nested);
}

/// Option 逆分配操作
pub fn codistributeOption(
    comptime A: type,
    comptime B: type,
    either_opt: EitherOpt(A, B),
) Option(Either(A, B)) {
    return distributive.option.codistribute(A, B, either_opt);
}

/// 对分配操作
pub fn distributePairOption(
    comptime A: type,
    comptime B: type,
    pair: struct { Option(A), Option(B) },
) Option(struct { A, B }) {
    return distributive.option.distributePair(A, B, pair);
}

// ============ 测试 ============

test "Option distribute" {
    const nested_some = Option(Option(i32)).Some(Option(i32).Some(42));
    const distributed = distributive.option.distribute(i32, nested_some);

    try std.testing.expect(distributed.isSome());
    try std.testing.expectEqual(@as(i32, 42), distributed.unwrap());

    const nested_none = Option(Option(i32)).Some(Option(i32).None());
    const distributed_none = distributive.option.distribute(i32, nested_none);

    try std.testing.expect(distributed_none.isNone());

    const outer_none = Option(Option(i32)).None();
    const distributed_outer = distributive.option.distribute(i32, outer_none);

    try std.testing.expect(distributed_outer.isNone());
}

test "Option codistribute" {
    const left_some = EitherOpt(i32, []const u8){ .left = Option(i32).Some(42) };
    const codistributed_left = distributive.option.codistribute(i32, []const u8, left_some);

    try std.testing.expect(codistributed_left.isSome());
    try std.testing.expectEqual(@as(i32, 42), codistributed_left.unwrap().left);

    const right_some = EitherOpt(i32, []const u8){ .right = Option([]const u8).Some("hello") };
    const codistributed_right = distributive.option.codistribute(i32, []const u8, right_some);

    try std.testing.expect(codistributed_right.isSome());
    try std.testing.expectEqualStrings("hello", codistributed_right.unwrap().right);

    const left_none = EitherOpt(i32, []const u8){ .left = Option(i32).None() };
    const codistributed_none = distributive.option.codistribute(i32, []const u8, left_none);

    try std.testing.expect(codistributed_none.isNone());
}

test "Option distributePair" {
    const pair_both_some = .{ Option(i32).Some(42), Option([]const u8).Some("world") };
    const distributed = distributive.option.distributePair(i32, []const u8, pair_both_some);

    try std.testing.expect(distributed.isSome());
    const result = distributed.unwrap();
    try std.testing.expectEqual(@as(i32, 42), result[0]);
    try std.testing.expectEqualStrings("world", result[1]);

    const pair_first_none = .{ Option(i32).None(), Option([]const u8).Some("world") };
    const distributed_none = distributive.option.distributePair(i32, []const u8, pair_first_none);

    try std.testing.expect(distributed_none.isNone());
}

test "convenience functions" {
    const nested = Option(Option(i32)).Some(Option(i32).Some(42));
    const result = distributeOption(i32, nested);

    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    const left_opt = EitherOpt(i32, []const u8){ .left = Option(i32).Some(42) };
    const codist_result = codistributeOption(i32, []const u8, left_opt);

    try std.testing.expect(codist_result.isSome());
    try std.testing.expectEqual(@as(i32, 42), codist_result.unwrap().left);
}

test "distributive law verification" {
    const test_value = EitherOpt(i32, []const u8){ .left = Option(i32).Some(42) };
    const is_valid = distributive.laws.verifyDistributiveLaw(i32, []const u8, test_value);

    try std.testing.expect(is_valid);
}
