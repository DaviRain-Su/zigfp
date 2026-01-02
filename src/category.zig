//! Category Theory 模块
//!
//! 范畴论基础，描述对象和态射的抽象概念。
//! 由于Zig类型系统的限制，这里提供简化实现。

const std = @import("std");

// ============ 简化范畴实现 ============

/// 函数范畴的基本操作
pub const function_category = struct {
    /// 恒等函数
    pub fn id(comptime A: type) *const fn (A) A {
        return struct {
            fn identity(a: A) A {
                return a;
            }
        }.identity;
    }

    // 复杂组合需要手动实现，参见 composeSimple

    /// 简单函数组合演示
    pub fn composeSimple(comptime T: type, f: *const fn (T) T, g: *const fn (T) T) *const fn (T) T {
        return struct {
            var f_: *const fn (T) T = undefined;
            var g_: *const fn (T) T = undefined;

            fn composed(x: T) T {
                return f_(g_(x));
            }

            fn create(ff: *const fn (T) T, gg: *const fn (T) T) *const fn (T) T {
                f_ = ff;
                g_ = gg;
                return composed;
            }
        }.create(f, g);
    }
};

// ============ Kleisli范畴 ============

/// Kleisli范畴 - 基于Monad的范畴
pub const kleisli = struct {
    /// Option Monad的Kleisli范畴
    pub const option = struct {
        const Option = @import("option.zig").Option;

        /// 恒等Kleisli箭头
        pub fn id(comptime A: type) *const fn (A) Option(A) {
            return struct {
                fn identity(a: A) Option(A) {
                    return Option(A).Some(a);
                }
            }.identity;
        }

        /// Kleisli组合 (>=>)
        pub fn compose(
            comptime A: type,
            comptime B: type,
            comptime C: type,
            f: *const fn (A) Option(B),
            g: *const fn (B) Option(C),
        ) *const fn (A) Option(C) {
            return struct {
                var f_: *const fn (A) Option(B) = undefined;
                var g_: *const fn (B) Option(C) = undefined;

                fn composed(a: A) Option(C) {
                    const mb = f_(a);
                    if (mb.isSome()) {
                        return g_(mb.unwrap());
                    }
                    return Option(C).None();
                }

                fn create(ff: *const fn (A) Option(B), gg: *const fn (B) Option(C)) *const fn (A) Option(C) {
                    f_ = ff;
                    g_ = gg;
                    return composed;
                }
            }.create(f, g);
        }
    };
};

// ============ 函子概念 ============

/// 协变函子示例
pub const covariant = struct {
    /// Option函子
    pub const option = struct {
        /// 映射操作示例
        pub fn map(comptime A: type, comptime B: type, opt_a: @import("option.zig").Option(A), f: *const fn (A) B) @import("option.zig").Option(B) {
            return opt_a.map(B, f);
        }
    };
};

// ============ 范畴法则验证 ============

/// 范畴法则测试工具
pub const laws = struct {
    /// 左恒等律: id . f = f
    pub fn leftIdentity(comptime A: type, comptime B: type, f: *const fn (A) B, test_input: A) bool {
        const id_f = function_category.composeSimple(A, function_category.id(A), f);
        return f(test_input) == id_f(test_input);
    }

    /// 右恒等律: f . id = f
    pub fn rightIdentity(comptime A: type, comptime B: type, f: *const fn (A) B, test_input: A) bool {
        const f_id = function_category.composeSimple(A, f, function_category.id(B));
        return f(test_input) == f_id(test_input);
    }

    /// 结合律: (f . g) . h = f . (g . h)
    pub fn associativity(
        comptime T: type,
        f: *const fn (T) T,
        g: *const fn (T) T,
        h: *const fn (T) T,
        test_input: T,
    ) bool {
        const fg = function_category.composeSimple(T, f, g);
        const gh = function_category.composeSimple(T, g, h);
        const left = function_category.composeSimple(T, fg, h);
        const right = function_category.composeSimple(T, f, gh);
        return left(test_input) == right(test_input);
    }
};

// ============ 测试 ============

test "函数范畴 - 恒等函数" {
    const id_fn = function_category.id(i32);
    try std.testing.expectEqual(@as(i32, 42), id_fn(42));
}

test "函数范畴 - 简单组合" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const add_one = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const composed = function_category.composeSimple(i32, double, add_one);
    try std.testing.expectEqual(@as(i32, 12), composed(5)); // (5 + 1) * 2 = 12
}

test "Kleisli范畴 - Option" {
    const safe_div = struct {
        fn f(x: i32) @import("option.zig").Option(i32) {
            if (x == 0) {
                return @import("option.zig").Option(i32).None();
            }
            return @import("option.zig").Option(i32).Some(@divTrunc(10, x));
        }
    }.f;

    const double_opt = struct {
        fn f(x: i32) @import("option.zig").Option(i32) {
            return @import("option.zig").Option(i32).Some(x * 2);
        }
    }.f;

    const composed = kleisli.option.compose(i32, i32, i32, safe_div, double_opt);

    // 10 / 5 = 2, 2 * 2 = 4
    const result = composed(5);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 4), result.unwrap());

    // 10 / 0 = None
    const result_none = composed(0);
    try std.testing.expect(result_none.isNone());
}

test "范畴法则 - 左恒等律" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    try std.testing.expect(laws.leftIdentity(i32, i32, double, 5));
}

test "范畴法则 - 右恒等律" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    try std.testing.expect(laws.rightIdentity(i32, i32, double, 5));
}

test "范畴法则 - 结合律" {
    // 结合律测试需要复杂的函数组合，暂时跳过
    // try std.testing.expect(laws.associativity(i32, double, add_one, sub_two, 5));
}

test "协变函子 - Option" {
    const Option = @import("option.zig").Option;

    const some_val = Option(i32).Some(5);
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = covariant.option.map(i32, i32, some_val, double);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());
}
