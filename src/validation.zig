//! 函数式数据验证框架
//!
//! 提供类型安全、组合式的验证能力。
//! 支持错误累积和函数式验证组合子。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 验证错误类型
pub const ValidationError = error{
    ValidationFailed,
    OutOfMemory,
};

/// 验证结果 - Either类型，成功时包含值，失败时包含错误列表
pub fn Validation(T: type, E: type) type {
    return union(enum) {
        const Self = @This();

        /// 验证成功，包含验证后的值
        valid: T,
        /// 验证失败，包含错误列表
        invalid: []E,

        /// 检查是否成功
        pub fn isValid(self: Self) bool {
            return self == .valid;
        }

        /// 检查是否失败
        pub fn isInvalid(self: Self) bool {
            return self == .invalid;
        }

        /// 获取成功值（未检查）
        pub fn unwrap(self: Self) T {
            return self.valid;
        }

        /// 获取错误列表（未检查）
        pub fn unwrapErr(self: Self) []E {
            return self.invalid;
        }

        /// 销毁验证结果
        pub fn deinit(self: *Self, allocator: Allocator) void {
            if (self.* == .invalid) {
                allocator.free(self.invalid);
            }
            self.* = undefined;
        }
    };
}

/// 创建成功验证结果
pub fn valid(T: type, E: type, value: T) Validation(T, E) {
    return Validation(T, E){ .valid = value };
}

/// 创建失败验证结果
pub fn invalid(T: type, E: type, errors: []E) Validation(T, E) {
    return Validation(T, E){ .invalid = errors };
}

/// 验证器函数类型
pub fn Validator(T: type, E: type) type {
    return *const fn (value: T, allocator: Allocator) ValidationError!Validation(T, E);
}

/// 验证器结构体包装器
pub fn ValidatorFn(T: type, E: type) type {
    return struct {
        validateFn: Validator(T, E),

        pub fn validate(self: @This(), value: T, allocator: Allocator) ValidationError!Validation(T, E) {
            return self.validateFn(value, allocator);
        }
    };
}

/// 验证器组合子
pub const Combinators = struct {
    /// 恒等验证器 - 总是成功
    pub fn identity(T: type, E: type) Validator(T, E) {
        return struct {
            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                _ = allocator;
                return valid(T, E, value);
            }
        }.validate;
    }
};

// ============ 预定义验证器 ============

/// 字符串验证器
pub const StringValidators = struct {
    /// 检查字符串不为空
    pub fn notEmpty(err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (value.len > 0) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.err_msg = err;
        return S.validate;
    }
};

/// 数值验证器
pub const NumberValidators = struct {
    /// 检查最小值
    pub fn min(comptime T: type, min_val: T, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var min_val_copy: T = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (value >= min_val_copy) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.min_val_copy = min_val;
        S.err_msg = err;
        return S.validate;
    }

    /// 检查最大值
    pub fn max(comptime T: type, max_val: T, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var max_val_copy: T = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (value <= max_val_copy) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.max_val_copy = max_val;
        S.err_msg = err;
        return S.validate;
    }
};

// ============ 便捷函数 ============

/// 执行验证
pub fn validate(T: type, E: type, validator: Validator(T, E), value: T, allocator: Allocator) !Validation(T, E) {
    return try validator(value, allocator);
}

// ============ 测试 ============

test "Validation basic functionality" {
    const result_valid = valid(i32, []const u8, 42);
    try std.testing.expect(result_valid.isValid());
    try std.testing.expect(result_valid.unwrap() == 42);

    const errors = try std.testing.allocator.dupe([]const u8, &[_][]const u8{"error message"});
    var result_invalid = invalid(i32, []const u8, errors);
    defer result_invalid.deinit(std.testing.allocator);
    try std.testing.expect(result_invalid.isInvalid());
    try std.testing.expect(result_invalid.unwrapErr().len == 1);
}

test "String validators" {
    // 测试非空
    const not_empty_validator = StringValidators.notEmpty("cannot be empty");
    var result1 = try validate([]const u8, []const u8, not_empty_validator, "hello", std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate([]const u8, []const u8, not_empty_validator, "", std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "Number validators" {
    // 测试最小值
    const min_validator = NumberValidators.min(i32, 10, "too small");
    var result1 = try validate(i32, []const u8, min_validator, 15, std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate(i32, []const u8, min_validator, 5, std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}
