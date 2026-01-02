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

/// 从单个错误创建失败结果
pub fn invalidOne(T: type, E: type, allocator: std.mem.Allocator, err: E) !Validation(T, E) {
    const errors = try allocator.alloc(E, 1);
    errors[0] = err;
    return Validation(T, E){ .invalid = errors };
}

// ============ Validation 扩展方法 ============

/// Validation 的 map 操作
pub fn mapValidation(
    comptime T: type,
    comptime U: type,
    comptime E: type,
    v: Validation(T, E),
    f: *const fn (T) U,
) Validation(U, E) {
    return switch (v) {
        .valid => |val| Validation(U, E){ .valid = f(val) },
        .invalid => |errs| Validation(U, E){ .invalid = errs },
    };
}

/// Validation 的 flatMap/andThen 操作
pub fn flatMapValidation(
    comptime T: type,
    comptime U: type,
    comptime E: type,
    v: Validation(T, E),
    allocator: std.mem.Allocator,
    f: *const fn (T, std.mem.Allocator) anyerror!Validation(U, E),
) !Validation(U, E) {
    return switch (v) {
        .valid => |val| try f(val, allocator),
        .invalid => |errs| Validation(U, E){ .invalid = errs },
    };
}

/// 从 Option 创建 Validation
pub fn fromOption(
    comptime T: type,
    comptime E: type,
    opt: @import("option.zig").Option(T),
    allocator: std.mem.Allocator,
    err: E,
) !Validation(T, E) {
    return switch (opt) {
        .some => |val| valid(T, E, val),
        .none => try invalidOne(T, E, allocator, err),
    };
}

/// 从 Result 创建 Validation
pub fn fromResult(
    comptime T: type,
    comptime E: type,
    comptime RE: type,
    res: @import("result.zig").Result(T, RE),
    allocator: std.mem.Allocator,
    errMap: *const fn (RE) E,
) !Validation(T, E) {
    return switch (res) {
        .ok => |val| valid(T, E, val),
        .err => |e| try invalidOne(T, E, allocator, errMap(e)),
    };
}

/// 将 Validation 转换为 Result
pub fn toResult(
    comptime T: type,
    comptime E: type,
    v: Validation(T, E),
) @import("result.zig").Result(T, []E) {
    const Result = @import("result.zig").Result;
    return switch (v) {
        .valid => |val| Result(T, []E).Ok(val),
        .invalid => |errs| Result(T, []E).Err(errs),
    };
}

/// 确保条件成立，否则返回错误
pub fn ensure(
    comptime T: type,
    comptime E: type,
    v: Validation(T, E),
    allocator: std.mem.Allocator,
    predicate: *const fn (T) bool,
    err: E,
) !Validation(T, E) {
    return switch (v) {
        .valid => |val| {
            if (predicate(val)) {
                return v;
            } else {
                return try invalidOne(T, E, allocator, err);
            }
        },
        .invalid => v,
    };
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
    pub fn identity(comptime T: type, comptime E: type) Validator(T, E) {
        return struct {
            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                _ = allocator;
                return valid(T, E, value);
            }
        }.validate;
    }

    /// 失败验证器 - 总是失败
    pub fn fail(comptime T: type, comptime E: type, err_val: E) Validator(T, E) {
        const S = struct {
            var stored_err: E = undefined;

            fn validate(_: T, allocator: Allocator) ValidationError!Validation(T, E) {
                const errors = try allocator.alloc(E, 1);
                errors[0] = stored_err;
                return invalid(T, E, errors);
            }
        };
        S.stored_err = err_val;
        return S.validate;
    }

    /// 逻辑与组合 - 两个验证器都必须通过
    pub fn andThen(
        comptime T: type,
        comptime E: type,
        v1: Validator(T, E),
        v2: Validator(T, E),
    ) Validator(T, E) {
        const S = struct {
            var validator1: Validator(T, E) = undefined;
            var validator2: Validator(T, E) = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                const result1 = try validator1(value, allocator);
                if (result1.isInvalid()) {
                    return result1;
                }

                const result2 = try validator2(value, allocator);
                return result2;
            }
        };
        S.validator1 = v1;
        S.validator2 = v2;
        return S.validate;
    }

    /// 逻辑或组合 - 任意一个验证器通过即可
    pub fn orElse(
        comptime T: type,
        comptime E: type,
        v1: Validator(T, E),
        v2: Validator(T, E),
    ) Validator(T, E) {
        const S = struct {
            var validator1: Validator(T, E) = undefined;
            var validator2: Validator(T, E) = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                var result1 = try validator1(value, allocator);
                if (result1.isValid()) {
                    return result1;
                }

                var result2 = try validator2(value, allocator);
                if (result2.isValid()) {
                    // 释放第一个结果的错误
                    allocator.free(result1.invalid);
                    return result2;
                }

                // 两个都失败，合并错误
                const total_len = result1.invalid.len + result2.invalid.len;
                const combined = try allocator.alloc(E, total_len);
                @memcpy(combined[0..result1.invalid.len], result1.invalid);
                @memcpy(combined[result1.invalid.len..], result2.invalid);

                // 释放原始错误数组
                allocator.free(result1.invalid);
                allocator.free(result2.invalid);

                return invalid(T, E, combined);
            }
        };
        S.validator1 = v1;
        S.validator2 = v2;
        return S.validate;
    }

    /// 逻辑非 - 反转验证结果
    pub fn not(
        comptime T: type,
        comptime E: type,
        v: Validator(T, E),
        err_val: E,
    ) Validator(T, E) {
        const S = struct {
            var validator: Validator(T, E) = undefined;
            var err_msg: E = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                var result = try validator(value, allocator);
                defer result.deinit(allocator);

                if (result.isValid()) {
                    // 原本成功，现在失败
                    const errors = try allocator.alloc(E, 1);
                    errors[0] = err_msg;
                    return invalid(T, E, errors);
                } else {
                    // 原本失败，现在成功
                    return valid(T, E, value);
                }
            }
        };
        S.validator = v;
        S.err_msg = err_val;
        return S.validate;
    }

    /// 所有验证器都必须通过（累积错误）
    pub fn all(
        comptime T: type,
        comptime E: type,
        validators: []const Validator(T, E),
    ) Validator(T, E) {
        const S = struct {
            var stored_validators: []const Validator(T, E) = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                var all_errors = std.ArrayList(E).initCapacity(allocator, 8) catch return ValidationError.OutOfMemory;
                defer all_errors.deinit(allocator);

                for (stored_validators) |v| {
                    var result = try v(value, allocator);
                    if (result.isInvalid()) {
                        for (result.invalid) |err| {
                            all_errors.append(allocator, err) catch return ValidationError.OutOfMemory;
                        }
                        allocator.free(result.invalid);
                    }
                }

                if (all_errors.items.len > 0) {
                    const errors = try allocator.dupe(E, all_errors.items);
                    return invalid(T, E, errors);
                }

                return valid(T, E, value);
            }
        };
        S.stored_validators = validators;
        return S.validate;
    }

    /// 任意验证器通过即可
    pub fn any(
        comptime T: type,
        comptime E: type,
        validators: []const Validator(T, E),
    ) Validator(T, E) {
        const S = struct {
            var stored_validators: []const Validator(T, E) = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, E) {
                var all_errors = std.ArrayList(E).initCapacity(allocator, 8) catch return ValidationError.OutOfMemory;
                defer all_errors.deinit(allocator);

                for (stored_validators) |v| {
                    var result = try v(value, allocator);
                    if (result.isValid()) {
                        return result;
                    }
                    // 收集错误
                    for (result.invalid) |err| {
                        all_errors.append(allocator, err) catch return ValidationError.OutOfMemory;
                    }
                    allocator.free(result.invalid);
                }

                // 所有验证器都失败
                const errors = try allocator.dupe(E, all_errors.items);
                return invalid(T, E, errors);
            }
        };
        S.stored_validators = validators;
        return S.validate;
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

    /// 最小长度验证器
    pub fn minLength(min_len: usize, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var min: usize = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (value.len >= min) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.min = min_len;
        S.err_msg = err;
        return S.validate;
    }

    /// 最大长度验证器
    pub fn maxLength(max_len: usize, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var max: usize = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (value.len <= max) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.max = max_len;
        S.err_msg = err;
        return S.validate;
    }

    /// 长度范围验证器
    pub fn lengthBetween(min_len: usize, max_len: usize, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var min: usize = undefined;
            var max: usize = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (value.len >= min and value.len <= max) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.min = min_len;
        S.max = max_len;
        S.err_msg = err;
        return S.validate;
    }

    /// 包含子串验证器
    pub fn contains(substring: []const u8, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var substr: []const u8 = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (std.mem.indexOf(u8, value, substr) != null) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.substr = substring;
        S.err_msg = err;
        return S.validate;
    }

    /// 前缀验证器
    pub fn startsWith(prefix: []const u8, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var pref: []const u8 = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (std.mem.startsWith(u8, value, pref)) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.pref = prefix;
        S.err_msg = err;
        return S.validate;
    }

    /// 后缀验证器
    pub fn endsWith(suffix: []const u8, err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var suf: []const u8 = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (std.mem.endsWith(u8, value, suf)) {
                    return valid([]const u8, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
            }
        };
        S.suf = suffix;
        S.err_msg = err;
        return S.validate;
    }

    /// 简单模式匹配（检查是否全部是数字/字母等）
    pub fn isAlphanumeric(err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                for (value) |c| {
                    if (!std.ascii.isAlphanumeric(c)) {
                        const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                        return invalid([]const u8, []const u8, errors);
                    }
                }
                return valid([]const u8, []const u8, value);
            }
        };
        S.err_msg = err;
        return S.validate;
    }

    /// 检查是否全部是数字
    pub fn isNumeric(err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                if (value.len == 0) {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid([]const u8, []const u8, errors);
                }
                for (value) |c| {
                    if (!std.ascii.isDigit(c)) {
                        const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                        return invalid([]const u8, []const u8, errors);
                    }
                }
                return valid([]const u8, []const u8, value);
            }
        };
        S.err_msg = err;
        return S.validate;
    }

    /// 简单邮箱格式验证（检查是否包含@和.）
    pub fn isEmail(err: []const u8) Validator([]const u8, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: []const u8, allocator: Allocator) ValidationError!Validation([]const u8, []const u8) {
                // 简单检查：包含@，@后有.，@不在开头或结尾
                if (std.mem.indexOf(u8, value, "@")) |at_pos| {
                    if (at_pos > 0 and at_pos < value.len - 1) {
                        const after_at = value[at_pos + 1 ..];
                        if (std.mem.indexOf(u8, after_at, ".")) |dot_pos| {
                            if (dot_pos > 0 and dot_pos < after_at.len - 1) {
                                return valid([]const u8, []const u8, value);
                            }
                        }
                    }
                }
                const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                return invalid([]const u8, []const u8, errors);
            }
        };
        S.err_msg = err;
        return S.validate;
    }
};

/// 验证管道 - 链式验证
pub fn ValidationPipeline(comptime T: type, comptime E: type) type {
    return struct {
        validators: std.ArrayList(Validator(T, E)),
        allocator: Allocator,

        const Self = @This();

        /// 创建验证管道
        pub fn init(allocator: Allocator) !Self {
            return Self{
                .validators = try std.ArrayList(Validator(T, E)).initCapacity(allocator, 8),
                .allocator = allocator,
            };
        }

        /// 销毁验证管道
        pub fn deinit(self: *Self) void {
            self.validators.deinit(self.allocator);
        }

        /// 添加验证器
        pub fn add(self: *Self, v: Validator(T, E)) !*Self {
            try self.validators.append(self.allocator, v);
            return self;
        }

        /// 执行所有验证器（累积错误）
        pub fn validate(self: *Self, value: T) !Validation(T, E) {
            var all_errors = try std.ArrayList(E).initCapacity(self.allocator, 8);
            defer all_errors.deinit(self.allocator);

            for (self.validators.items) |v| {
                var result = try v(value, self.allocator);
                if (result.isInvalid()) {
                    for (result.invalid) |err| {
                        try all_errors.append(self.allocator, err);
                    }
                    self.allocator.free(result.invalid);
                }
            }

            if (all_errors.items.len > 0) {
                const errors = try self.allocator.dupe(E, all_errors.items);
                return invalid(T, E, errors);
            }

            return valid(T, E, value);
        }

        /// 执行验证器（短路求值，遇到第一个错误即停止）
        pub fn validateShortCircuit(self: *Self, value: T) !Validation(T, E) {
            for (self.validators.items) |v| {
                const result = try v(value, self.allocator);
                if (result.isInvalid()) {
                    return result;
                }
            }
            return valid(T, E, value);
        }
    };
}

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

    /// 范围验证器（包含边界）
    pub fn inRange(comptime T: type, min_val: T, max_val: T, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var min_copy: T = undefined;
            var max_copy: T = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (value >= min_copy and value <= max_copy) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.min_copy = min_val;
        S.max_copy = max_val;
        S.err_msg = err;
        return S.validate;
    }

    /// 正数验证器
    pub fn positive(comptime T: type, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (value > 0) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.err_msg = err;
        return S.validate;
    }

    /// 非负数验证器
    pub fn nonNegative(comptime T: type, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (value >= 0) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.err_msg = err;
        return S.validate;
    }
};

/// 通用验证器
pub const GenericValidators = struct {
    /// 必需字段验证器（检查Option类型）
    pub fn required(comptime T: type, err: []const u8) Validator(?T, []const u8) {
        const S = struct {
            var err_msg: []const u8 = undefined;

            fn validate(value: ?T, allocator: Allocator) ValidationError!Validation(?T, []const u8) {
                if (value != null) {
                    return valid(?T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(?T, []const u8, errors);
                }
            }
        };
        S.err_msg = err;
        return S.validate;
    }

    /// 枚举值验证器 - 检查值是否在允许列表中
    pub fn oneOf(comptime T: type, allowed: []const T, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var allowed_values: []const T = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                for (allowed_values) |v| {
                    if (std.meta.eql(v, value)) {
                        return valid(T, []const u8, value);
                    }
                }
                const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                return invalid(T, []const u8, errors);
            }
        };
        S.allowed_values = allowed;
        S.err_msg = err;
        return S.validate;
    }

    /// 相等验证器
    pub fn equals(comptime T: type, expected: T, err: []const u8) Validator(T, []const u8) {
        const S = struct {
            var expected_val: T = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (std.meta.eql(value, expected_val)) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.expected_val = expected;
        S.err_msg = err;
        return S.validate;
    }

    /// 自定义验证器
    pub fn custom(
        comptime T: type,
        predicate: *const fn (T) bool,
        err: []const u8,
    ) Validator(T, []const u8) {
        const S = struct {
            var pred: *const fn (T) bool = undefined;
            var err_msg: []const u8 = undefined;

            fn validate(value: T, allocator: Allocator) ValidationError!Validation(T, []const u8) {
                if (pred(value)) {
                    return valid(T, []const u8, value);
                } else {
                    const errors = try allocator.dupe([]const u8, &[_][]const u8{err_msg});
                    return invalid(T, []const u8, errors);
                }
            }
        };
        S.pred = predicate;
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

test "Combinators andThen" {
    const min_validator = NumberValidators.min(i32, 10, "too small");
    const max_validator = NumberValidators.max(i32, 100, "too large");
    const range_validator = Combinators.andThen(i32, []const u8, min_validator, max_validator);

    var result1 = try validate(i32, []const u8, range_validator, 50, std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate(i32, []const u8, range_validator, 5, std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "Combinators orElse" {
    // 使用范围验证器替代 equals 来避免静态变量问题
    const min_10 = NumberValidators.min(i32, 10, "less than 10");
    const max_5 = NumberValidators.max(i32, 5, "greater than 5");
    const either_validator = Combinators.orElse(i32, []const u8, min_10, max_5);

    // 15 >= 10，第一个验证器通过
    var result1 = try validate(i32, []const u8, either_validator, 15, std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    // 3 <= 5，第二个验证器通过
    var result2 = try validate(i32, []const u8, either_validator, 3, std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isValid());

    // 7 既不 >= 10 也不 <= 5，都失败
    var result3 = try validate(i32, []const u8, either_validator, 7, std.testing.allocator);
    defer result3.deinit(std.testing.allocator);
    try std.testing.expect(result3.isInvalid());
}

test "String validators - email" {
    const email_validator = StringValidators.isEmail("invalid email");

    var result1 = try validate([]const u8, []const u8, email_validator, "test@example.com", std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate([]const u8, []const u8, email_validator, "invalid", std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "String validators - length" {
    const length_validator = StringValidators.lengthBetween(3, 10, "invalid length");

    var result1 = try validate([]const u8, []const u8, length_validator, "hello", std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate([]const u8, []const u8, length_validator, "hi", std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "GenericValidators oneOf" {
    const allowed = [_]i32{ 1, 2, 3, 5, 8 };
    const fib_validator = GenericValidators.oneOf(i32, &allowed, "not fibonacci");

    var result1 = try validate(i32, []const u8, fib_validator, 5, std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate(i32, []const u8, fib_validator, 4, std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "GenericValidators custom" {
    const is_even = struct {
        fn check(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.check;

    const even_validator = GenericValidators.custom(i32, is_even, "not even");

    var result1 = try validate(i32, []const u8, even_validator, 4, std.testing.allocator);
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try validate(i32, []const u8, even_validator, 3, std.testing.allocator);
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
}

test "ValidationPipeline" {
    var pipeline = try ValidationPipeline([]const u8, []const u8).init(std.testing.allocator);
    defer pipeline.deinit();

    _ = try pipeline.add(StringValidators.notEmpty("cannot be empty"));
    _ = try pipeline.add(StringValidators.minLength(3, "too short"));

    var result1 = try pipeline.validate("hello");
    defer result1.deinit(std.testing.allocator);
    try std.testing.expect(result1.isValid());

    var result2 = try pipeline.validate("");
    defer result2.deinit(std.testing.allocator);
    try std.testing.expect(result2.isInvalid());
    // 累积错误应该有2个
    try std.testing.expectEqual(@as(usize, 2), result2.unwrapErr().len);
}

test "mapValidation" {
    const v1 = valid(i32, []const u8, 21);
    const v2 = mapValidation(i32, i32, []const u8, v1, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    try std.testing.expect(v2.isValid());
    try std.testing.expectEqual(@as(i32, 42), v2.unwrap());

    const errs = try std.testing.allocator.dupe([]const u8, &[_][]const u8{"error"});
    const v3 = invalid(i32, []const u8, errs);
    var v4 = mapValidation(i32, i32, []const u8, v3, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    defer v4.deinit(std.testing.allocator);
    try std.testing.expect(v4.isInvalid());
}

test "invalidOne" {
    var v = try invalidOne(i32, []const u8, std.testing.allocator, "single error");
    defer v.deinit(std.testing.allocator);
    try std.testing.expect(v.isInvalid());
    try std.testing.expectEqual(@as(usize, 1), v.unwrapErr().len);
}

test "toResult" {
    const v1 = valid(i32, []const u8, 42);
    const r1 = toResult(i32, []const u8, v1);
    try std.testing.expect(r1.isOk());
    try std.testing.expectEqual(@as(i32, 42), r1.unwrap());

    const errs = try std.testing.allocator.dupe([]const u8, &[_][]const u8{"error"});
    const v2 = invalid(i32, []const u8, errs);
    const r2 = toResult(i32, []const u8, v2);
    try std.testing.expect(r2.isErr());
    std.testing.allocator.free(r2.unwrapErr());
}

test "fromOption" {
    const Option = @import("option.zig").Option;

    const some = Option(i32).Some(42);
    const v1 = try fromOption(i32, []const u8, some, std.testing.allocator, "missing value");
    try std.testing.expect(v1.isValid());
    try std.testing.expectEqual(@as(i32, 42), v1.unwrap());

    const none_ = Option(i32).None();
    var v2 = try fromOption(i32, []const u8, none_, std.testing.allocator, "missing value");
    defer v2.deinit(std.testing.allocator);
    try std.testing.expect(v2.isInvalid());
}

test "ensure" {
    const v1 = valid(i32, []const u8, 42);
    const v2 = try ensure(i32, []const u8, v1, std.testing.allocator, struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f, "must be positive");
    try std.testing.expect(v2.isValid());

    const v3 = valid(i32, []const u8, -5);
    var v4 = try ensure(i32, []const u8, v3, std.testing.allocator, struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f, "must be positive");
    defer v4.deinit(std.testing.allocator);
    try std.testing.expect(v4.isInvalid());
}
