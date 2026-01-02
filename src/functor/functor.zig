//! Functor 模块
//!
//! Functor 是可以被映射的类型构造器。
//! 提供 map 操作，将函数应用到包装的值上。
//!
//! 法则：
//! - Identity: map(id) = id
//! - Composition: map(f . g) = map(f) . map(g)
//!
//! 类似于 Haskell 的 Functor 类型类。

const std = @import("std");
const option_mod = @import("../core/option.zig");
const Option = option_mod.Option;

/// Identity Functor
/// Identity 类型构造器
pub fn Identity(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Identity(U) {
            return Identity(U).init(f(self.value));
        }
    };
}

/// Option Functor 工具
pub const optionFunctor = struct {
    /// 映射函数到 Option 的内容
    pub fn map(comptime A: type, comptime B: type, fa: Option(A), f: *const fn (A) B) Option(B) {
        return fa.map(B, f);
    }

    /// 替换为常量值（忽略原值）
    pub fn as(comptime A: type, comptime B: type, fa: Option(A), value: B) Option(B) {
        const constFn = struct {
            var stored_value: B = undefined;
            fn f(_: A) B {
                return stored_value;
            }
        };
        constFn.stored_value = value;
        return map(A, B, fa, &constFn.f);
    }

    /// 替换为新值（忽略原值）
    pub fn replace(comptime A: type, comptime B: type, fa: Option(A), value: B) Option(B) {
        return as(A, B, fa, value);
    }
};

/// Identity Functor 工具
pub const identityFunctor = struct {
    /// 映射函数到 Identity 的内容
    pub fn map(comptime A: type, comptime B: type, fa: Identity(A), f: *const fn (A) B) Identity(B) {
        return fa.map(B, f);
    }

    /// 替换为常量值（忽略原值）
    pub fn as(comptime A: type, comptime B: type, fa: Identity(A), value: B) Identity(B) {
        const constFn = struct {
            var stored_value: B = undefined;
            fn f(_: A) B {
                return stored_value;
            }
        };
        constFn.stored_value = value;
        return map(A, B, fa, &constFn.f);
    }
};

// ============ 测试 ============

test "Option Functor identity law" {
    // map(id) = id
    const opt = Option(i32).Some(42);

    const idFn = struct {
        fn f(x: i32) i32 {
            return x;
        }
    }.f;

    const mapped = optionFunctor.map(i32, i32, opt, &idFn);
    try std.testing.expect(mapped.isSome());
    try std.testing.expectEqual(@as(i32, 42), mapped.unwrap());
}

test "Option Functor composition law" {
    // map(f . g) = map(f) . map(g)
    const opt = Option(i32).Some(5);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    // 组合方式1: map(f . g)
    const composeFn = struct {
        fn f(x: i32) i32 {
            return double(addOne(x));
        }
    }.f;

    const result1 = optionFunctor.map(i32, i32, opt, &composeFn);

    // 组合方式2: map(f) . map(g)
    const step1 = optionFunctor.map(i32, i32, opt, &addOne);
    const result2 = optionFunctor.map(i32, i32, step1, &double);

    try std.testing.expectEqual(result1.unwrap(), result2.unwrap());
    try std.testing.expectEqual(@as(i32, 12), result1.unwrap()); // (5 + 1) * 2 = 12
}

test "Option Functor map" {
    const opt = Option(i32).Some(42);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = optionFunctor.map(i32, i32, opt, &double);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 84), result.unwrap());

    // None 值保持 None
    const noneOpt = Option(i32).None();
    const noneResult = optionFunctor.map(i32, i32, noneOpt, &double);
    try std.testing.expect(noneResult.isNone());
}

test "Option Functor as/replace" {
    const opt = Option(i32).Some(42);

    const result = optionFunctor.as(i32, []const u8, opt, "hello");
    try std.testing.expect(result.isSome());
    try std.testing.expectEqualStrings("hello", result.unwrap());
}

test "Identity Functor" {
    const id_val = Identity(i32).init(42);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = identityFunctor.map(i32, i32, id_val, &double);
    try std.testing.expectEqual(@as(i32, 84), result.value);
}
