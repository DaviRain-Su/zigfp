//! 函数工具模块
//!
//! 提供函数组合和转换工具：
//! - compose - 函数组合
//! - identity, flip - 基础函数
//! - Pipe - 管道操作
//! - Memoize - 记忆化

const std = @import("std");

pub const function = @import("function.zig");
pub const pipe_mod = @import("pipe.zig");
pub const memoize = @import("memoize.zig");

// ============ Function ============
pub const compose = function.compose;
pub const identity = function.identity;
pub const flip = function.flip;
pub const apply = function.apply;
pub const tupled = function.tupled;
pub const untupled = function.untupled;
pub const Partial = function.Partial;
pub const partial = function.partial;

// ============ Curry ============
pub const Curry2 = function.Curry2;
pub const Curry2Applied = function.Curry2Applied;
pub const curry2 = function.curry2;
pub const Curry3 = function.Curry3;
pub const Curry3Applied1 = function.Curry3Applied1;
pub const Curry3Applied2 = function.Curry3Applied2;
pub const curry3 = function.curry3;
pub const uncurry2Call = function.uncurry2Call;
pub const uncurry3Call = function.uncurry3Call;
pub const Const = function.Const;
pub const const_ = function.const_;

// ============ Pipe ============
pub const Pipe = pipe_mod.Pipe;
pub const pipe = pipe_mod.pipe;
pub const OptionPipe = pipe_mod.OptionPipe;
pub const optionPipe = pipe_mod.optionPipe;

// ============ Memoize ============
pub const Memoized = memoize.Memoized;
pub const Memoized2 = memoize.Memoized2;
pub const memoizeFn = memoize.memoize;
pub const memoize2 = memoize.memoize2;

test {
    std.testing.refAllDecls(@This());
}
