//! Prelude 模块
//!
//! Prelude 是函数式编程的标准模块，提供最常用的函数、类型别名和工具。
//! 它是使用 zigFP 时最主要的入口点。
//!
//! 类似于 Haskell 的 Prelude 模块。

const std = @import("std");

// ============ 子模块导入 ============

/// 核心类型
pub const core = @import("core/mod.zig");
pub const monad_mod = @import("monad/mod.zig");
pub const functor_mod = @import("functor/mod.zig");
pub const algebra_mod = @import("algebra/mod.zig");
pub const data_mod = @import("data/mod.zig");
pub const function_mod = @import("function/mod.zig");
pub const effect_mod = @import("effect/mod.zig");
pub const parser_mod = @import("parser/mod.zig");
pub const optics_mod = @import("optics/mod.zig");

// ============ 类型别名 ============

/// 常用类型别名 - 更符合函数式编程习惯的命名
/// Maybe - 可选值（同 Option）
pub const Maybe = core.Option;

/// Either - 结果类型（同 Result）
pub const Either = core.Result;

/// Id - 恒等类型构造器
pub const Id = functor_mod.functor.Identity;

/// Unit - 单元类型（空结构体）
pub const Unit = struct {
    pub fn init() Unit {
        return .{};
    }
};

// ============ 重新导出常用模块 ============

pub const option = core.option;
pub const result = core.result;
pub const lazy = core.lazy;
pub const validation = core.validation;
pub const function = function_mod.function;
pub const pipe_mod = function_mod.pipe;
pub const memoize = function_mod.memoize;
pub const reader = monad_mod.reader;
pub const writer = monad_mod.writer;
pub const state = monad_mod.state;
pub const cont = monad_mod.cont;
pub const free = monad_mod.free;
pub const lens = optics_mod.lens;
pub const optics = optics_mod.optics;
pub const monoid = algebra_mod.monoid;
pub const semigroup = algebra_mod.semigroup;
pub const foldable = algebra_mod.foldable;
pub const traversable = algebra_mod.traversable;
pub const alternative = algebra_mod.alternative;
pub const functor = functor_mod.functor;
pub const applicative = functor_mod.applicative;
pub const bifunctor = functor_mod.bifunctor;
pub const profunctor = functor_mod.profunctor;
pub const io = effect_mod.io;
pub const effect = effect_mod.effect;
pub const parser = parser_mod.parser;
pub const iterator = data_mod.iterator;
pub const stream = data_mod.stream;
pub const zipper = data_mod.zipper;
pub const arrow = data_mod.arrow;
pub const comonad = data_mod.comonad;

// ============ 核心函数 ============

/// identity - 恒等函数
pub fn id(comptime T: type) fn (T) T {
    return struct {
        fn identity(x: T) T {
            return x;
        }
    }.identity;
}

/// constant - 常量函数，返回固定值，忽略输入
pub fn constant(comptime A: type, comptime B: type, value: B) *const fn (A) B {
    const ConstFn = struct {
        var stored_value: B = undefined;

        fn const_fn(_: A) B {
            return stored_value;
        }

        fn create(val: B) *const fn (A) B {
            stored_value = val;
            return const_fn;
        }
    };

    return ConstFn.create(value);
}

/// flip - 翻转函数参数
/// 注意：由于Zig闭包限制，返回一个需要手动使用的翻转函数
pub fn flip(comptime A: type, comptime B: type, comptime C: type, f: *const fn (A, B) C) *const fn (B, A) C {
    _ = f;
    @compileError("Create flipped function manually: fn flipped(b: B, a: A) C { return f(a, b); }");
}

/// compose - 函数组合 (f . g)(x) = f(g(x))
/// 注意：Zig的限制，这个函数返回一个简单的组合函数
pub fn compose(comptime A: type, comptime B: type, comptime C: type, f: *const fn (B) C, g: *const fn (A) B) *const fn (A) C {
    // 由于Zig闭包限制，我们返回一个包装函数
    // 使用者需要手动创建组合函数
    _ = f;
    _ = g;
    @compileError("Use compose2 for actual composition, or create wrapper manually");
}

/// 简单的二元函数组合
pub fn compose2(comptime T: type, f: *const fn (T) T, g: *const fn (T) T) *const fn (T) T {
    const Compose2Fn = struct {
        var f_: *const fn (T) T = undefined;
        var g_: *const fn (T) T = undefined;

        fn composed(x: T) T {
            return f_(g_(x));
        }

        fn create(f__: *const fn (T) T, g__: *const fn (T) T) *const fn (T) T {
            f_ = f__;
            g_ = g__;
            return composed;
        }
    };

    return Compose2Fn.create(f, g);
}

/// pipe - 管道操作 (x |> f |> g) = g(f(x))
/// 反向组合，更符合数据流向
pub fn pipe(comptime A: type, comptime B: type, f: fn (A) B) fn (A) B {
    return f;
}

/// curry - 柯里化说明
/// 注意：Zig不支持闭包，柯里化需要手动实现
/// 示例: fn curried(a: A) fn (B) C { return struct { fn call(b: B) C { return f(a, b); } }.call; }
/// uncurry - 展开说明
/// 注意：展开柯里化函数需要手动实现
/// 示例: fn uncurried(a: A, b: B) C { return f(a)(b); }

// ============ 运算符模拟 ============

/// Functor map 运算符 (<$>)
pub const fmap = "<$>";

/// Applicative apply 运算符 (<*>)
pub const ap = "<*>";

/// Monad bind 运算符 (>>=)
pub const bind = ">>=";

/// Reverse bind 运算符 (=<<)
pub const bind_rev = "=<<";

/// Semigroup combine 运算符 (<>)
pub const combine_op = "<>";

/// Forward composition (>>>)
pub const compose_fwd = ">>>";

/// Backward composition (<<<)
pub const compose_bwd = "<<<";

/// Kleisli composition (>=>)
pub const kleisli = ">=>";

/// Reverse Kleisli composition (<=<)
pub const kleisli_rev = "<=<";

// ============ 便捷构造函数 ============

/// 创建 Some 值
pub fn some(comptime T: type, value: T) Maybe(T) {
    return Maybe(T).Some(value);
}

/// 创建 None 值
pub fn none(comptime T: type) Maybe(T) {
    return Maybe(T).None();
}

/// 创建 Ok 值
pub fn ok(comptime T: type, comptime E: type, value: T) Either(T, E) {
    return Either(T, E).Ok(value);
}

/// 创建 Err 值
pub fn err(comptime T: type, comptime E: type, error_val: E) Either(T, E) {
    return Either(T, E).Err(error_val);
}

/// 创建 Id 值
pub fn pure(comptime T: type, value: T) Id(T) {
    return Id(T).init(value);
}

/// 创建 Unit 值
pub fn unit() Unit {
    return Unit.init();
}

// ============ 常用组合函数 ============

/// 双重组合 (f . g . h)
pub fn compose3(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    f: *const fn (C) D,
    g: *const fn (B) C,
    h: *const fn (A) B,
) *const fn (A) D {
    return compose2(A, compose2(A, f, g), h);
}

/// 三重组合 (f . g . h . i)
pub fn compose4(
    comptime A: type,
    comptime B: type,
    comptime C: type,
    comptime D: type,
    comptime E: type,
    f: *const fn (D) E,
    g: *const fn (C) D,
    h: *const fn (B) C,
    i: *const fn (A) B,
) *const fn (A) E {
    return compose2(A, compose3(A, A, A, A, f, g, h), i);
}

/// 条件函数
pub fn when(comptime T: type, condition: bool, value: T, default: T) T {
    return if (condition) value else default;
}

/// unless - when 的反函数
pub fn unless(comptime T: type, condition: bool, value: T, default: T) T {
    return when(T, !condition, value, default);
}

/// 条件执行
pub fn whenM(comptime T: type, condition: bool, action: fn () T, default: fn () T) T {
    return if (condition) action() else default();
}

/// 布尔转换
pub fn boolToOption(comptime T: type, condition: bool, value: T) Maybe(T) {
    return if (condition) some(T, value) else none(T);
}

/// Option 到布尔
pub fn optionToBool(comptime T: type, opt: Maybe(T)) bool {
    return opt.isSome();
}

// ============ 测试 ============

test "id function" {
    const id_fn = id(i32);
    try std.testing.expectEqual(@as(i32, 42), id_fn(42));
    try std.testing.expectEqual(@as(i32, 0), id_fn(0));
}

test "constant function" {
    const const_fn = constant(i32, []const u8, "hello");
    try std.testing.expectEqualStrings("hello", const_fn(42));
    try std.testing.expectEqualStrings("hello", const_fn(0));
}

test "flip function documentation" {
    // flip函数由于Zig闭包限制，只提供说明
    // 手动实现翻转示例
    const sub = struct {
        fn subtract(a: i32, b: i32) i32 {
            return a - b;
        }
    }.subtract;

    const flipped = struct {
        fn call(b: i32, a: i32) i32 {
            return sub(a, b);
        }
    }.call;

    // 普通: 10 - 5 = 5
    try std.testing.expectEqual(@as(i32, 5), sub(10, 5));
    // 翻转: 10 - 5 = 5 (参数顺序翻转)
    try std.testing.expectEqual(@as(i32, 5), flipped(5, 10));
}

test "compose function documentation" {
    // compose函数由于Zig闭包限制，只提供说明
    // 使用compose2进行简单组合
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

    // 手动组合示例
    const composed = struct {
        fn call(x: i32) i32 {
            return double(addOne(x));
        }
    }.call;

    try std.testing.expectEqual(@as(i32, 12), composed(5));
}

test "curry and uncurry documentation" {
    // 由于Zig闭包限制，curry/uncurry函数只提供说明
    // 实际使用需要手动实现柯里化
    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    // 手动柯里化示例
    const CurriedAdd = struct {
        fn curried(a: i32) fn (i32) i32 {
            return struct {
                var a_: i32 = a;

                fn call(b: i32) i32 {
                    return add(a_, b);
                }

                fn get() fn (i32) i32 {
                    return call;
                }
            }.get();
        }
    };

    // 测试手动柯里化
    const add5 = CurriedAdd.curried(5);
    try std.testing.expectEqual(@as(i32, 8), add5(3));
}

test "convenience constructors" {
    // Maybe
    const maybe_val = some(i32, 42);
    try std.testing.expect(maybe_val.isSome());
    try std.testing.expectEqual(@as(i32, 42), maybe_val.unwrap());

    const none_val = none(i32);
    try std.testing.expect(none_val.isNone());

    // Either
    const ok_val = ok(i32, []const u8, 42);
    try std.testing.expect(ok_val.isOk());

    const err_val = err(i32, []const u8, "error");
    try std.testing.expect(err_val.isErr());

    // Id
    const id_val = pure(i32, 42);
    try std.testing.expectEqual(@as(i32, 42), id_val.value);

    // Unit
    const unit_val = unit();
    _ = unit_val; // Unit 是空结构体
}

test "compose2" {
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

    // 二重组合: double . addOne
    const composed = compose2(i32, double, addOne);
    // (5 + 1) * 2 = 12
    try std.testing.expectEqual(@as(i32, 12), composed(5));
}

test "when and unless" {
    try std.testing.expectEqual(@as(i32, 10), when(i32, true, 10, 20));
    try std.testing.expectEqual(@as(i32, 20), when(i32, false, 10, 20));

    try std.testing.expectEqual(@as(i32, 20), unless(i32, true, 10, 20));
    try std.testing.expectEqual(@as(i32, 10), unless(i32, false, 10, 20));
}

test "bool and option conversion" {
    const opt_true = boolToOption(i32, true, 42);
    try std.testing.expect(opt_true.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt_true.unwrap());

    const opt_false = boolToOption(i32, false, 42);
    try std.testing.expect(opt_false.isNone());

    try std.testing.expect(optionToBool(i32, some(i32, 42)));
    try std.testing.expect(!optionToBool(i32, none(i32)));
}

test "operator constants" {
    // 验证运算符常量存在
    try std.testing.expectEqualStrings("<$>", fmap);
    try std.testing.expectEqualStrings("<*>", ap);
    try std.testing.expectEqualStrings(">>=", bind);
    try std.testing.expectEqualStrings("=<<", bind_rev);
    try std.testing.expectEqualStrings("<>", combine_op);
}
