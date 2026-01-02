//! 核心数据类型模块
//!
//! 提供函数式编程的基础数据类型：
//! - Option - 安全空值处理
//! - Result - 错误处理
//! - Lazy - 惰性求值
//! - Validation - 累积错误验证

const std = @import("std");

pub const option = @import("option.zig");
pub const result = @import("result.zig");
pub const lazy = @import("lazy.zig");
pub const validation = @import("validation.zig");

// ============ Option ============
pub const Option = option.Option;
pub const some = option.some;
pub const none = option.none;
pub const flatten = option.flatten;

// ============ Result ============
pub const Result = result.Result;
pub const ok = result.ok;
pub const err = result.err;

// ============ Lazy ============
pub const Lazy = lazy.Lazy;

// ============ Validation ============
pub const Validation = validation.Validation;
pub const valid = validation.valid;
pub const invalid = validation.invalid;
pub const invalidOne = validation.invalidOne;
pub const mapValidation = validation.mapValidation;
pub const flatMapValidation = validation.flatMapValidation;
pub const validationFromOption = validation.fromOption;
pub const validationFromResult = validation.fromResult;
pub const validationToResult = validation.toResult;
pub const ensureValidation = validation.ensure;
pub const Validator = validation.Validator;
pub const ValidationPipeline = validation.ValidationPipeline;
pub const StringValidators = validation.StringValidators;
pub const NumberValidators = validation.NumberValidators;
pub const GenericValidators = validation.GenericValidators;
pub const ValidationCombinators = validation.Combinators;

test {
    std.testing.refAllDecls(@This());
}
