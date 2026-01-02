//! Validation 模块 - 累积错误的验证
//!
//! 与 Result 不同，Validation 可以累积多个错误，
//! 适用于表单验证、配置验证等需要收集所有错误的场景。
//!
//! 类似于 Scala Cats 的 Validated 或 Haskell 的 Validation。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Validation 类型 - 累积错误的验证结果
///
/// 与 Result 的关键区别：
/// - Result: 遇到第一个错误就停止（fail-fast）
/// - Validation: 收集所有错误（accumulating）
pub fn Validation(comptime T: type, comptime E: type) type {
    return union(enum) {
        valid: T,
        invalid: []const E,

        const Self = @This();

        // ============ 构造器 ============

        /// 创建成功的 Validation
        pub fn Valid(value: T) Self {
            return .{ .valid = value };
        }

        /// 创建包含单个错误的 Validation
        pub fn Invalid(err: E) Self {
            return .{ .invalid = &[_]E{err} };
        }

        /// 创建包含多个错误的 Validation
        pub fn InvalidMany(errors: []const E) Self {
            return .{ .invalid = errors };
        }

        // ============ 查询方法 ============

        /// 是否有效
        pub fn isValid(self: Self) bool {
            return self == .valid;
        }

        /// 是否无效
        pub fn isInvalid(self: Self) bool {
            return self == .invalid;
        }

        /// 获取值（如果有效）
        pub fn getValue(self: Self) ?T {
            return switch (self) {
                .valid => |v| v,
                .invalid => null,
            };
        }

        /// 获取错误列表（如果无效）
        pub fn getErrors(self: Self) ?[]const E {
            return switch (self) {
                .valid => null,
                .invalid => |e| e,
            };
        }

        /// 获取值或默认值
        pub fn getOrElse(self: Self, default: T) T {
            return switch (self) {
                .valid => |v| v,
                .invalid => default,
            };
        }

        // ============ Functor ============

        /// 对有效值应用函数
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Validation(U, E) {
            return switch (self) {
                .valid => |v| Validation(U, E).Valid(f(v)),
                .invalid => |e| Validation(U, E).InvalidMany(e),
            };
        }

        /// 对错误列表应用函数
        pub fn mapErrors(self: Self, comptime F: type, f: *const fn (E) F) Validation(T, F) {
            return switch (self) {
                .valid => |v| Validation(T, F).Valid(v),
                .invalid => |errors| blk: {
                    // 注意：这里需要 allocator 来创建新数组
                    // 简化版本：返回单个错误的转换
                    if (errors.len > 0) {
                        break :blk Validation(T, F).Invalid(f(errors[0]));
                    }
                    break :blk Validation(T, F).Valid(undefined);
                },
            };
        }

        // ============ Applicative ============

        /// 应用包装在 Validation 中的函数
        /// 如果两边都有错误，则合并错误
        pub fn ap(
            self: Self,
            comptime U: type,
            vf: Validation(*const fn (T) U, E),
            allocator: Allocator,
        ) !Validation(U, E) {
            return switch (self) {
                .valid => |v| switch (vf) {
                    .valid => |f| Validation(U, E).Valid(f(v)),
                    .invalid => |e| Validation(U, E).InvalidMany(e),
                },
                .invalid => |e1| switch (vf) {
                    .valid => Validation(U, E).InvalidMany(e1),
                    .invalid => |e2| blk: {
                        // 合并错误
                        var combined = try std.ArrayList(E).initCapacity(allocator, e1.len + e2.len);
                        errdefer combined.deinit(allocator);
                        try combined.appendSlice(allocator, e1);
                        try combined.appendSlice(allocator, e2);
                        break :blk Validation(U, E).InvalidMany(try combined.toOwnedSlice(allocator));
                    },
                },
            };
        }

        // ============ 组合操作 ============

        /// 与另一个 Validation 组合
        /// 如果都有效，使用函数组合两个值
        /// 如果有错误，累积所有错误
        pub fn combine(
            self: Self,
            other: Validation(T, E),
            combiner: *const fn (T, T) T,
            allocator: Allocator,
        ) !Self {
            return switch (self) {
                .valid => |v1| switch (other) {
                    .valid => |v2| Self.Valid(combiner(v1, v2)),
                    .invalid => |e| Self.InvalidMany(e),
                },
                .invalid => |e1| switch (other) {
                    .valid => Self.InvalidMany(e1),
                    .invalid => |e2| blk: {
                        var combined = try std.ArrayList(E).initCapacity(allocator, e1.len + e2.len);
                        errdefer combined.deinit(allocator);
                        try combined.appendSlice(allocator, e1);
                        try combined.appendSlice(allocator, e2);
                        break :blk Self.InvalidMany(try combined.toOwnedSlice(allocator));
                    },
                },
            };
        }

        /// 转换为 Result 类型（只保留第一个错误）
        pub fn toResult(self: Self) Result(T, E) {
            return switch (self) {
                .valid => |v| Result(T, E).Ok(v),
                .invalid => |errors| if (errors.len > 0)
                    Result(T, E).Err(errors[0])
                else
                    Result(T, E).Err(undefined),
            };
        }

        /// 从 Result 转换
        pub fn fromResult(res: Result(T, E)) Self {
            return switch (res) {
                .ok => |v| Self.Valid(v),
                .err => |e| Self.Invalid(e),
            };
        }

        /// 折叠 - 处理两种情况
        pub fn fold(
            self: Self,
            comptime U: type,
            onValid: *const fn (T) U,
            onInvalid: *const fn ([]const E) U,
        ) U {
            return switch (self) {
                .valid => |v| onValid(v),
                .invalid => |e| onInvalid(e),
            };
        }
    };
}

/// 简化的 Result 类型（用于与 Validation 互转）
fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        pub fn Ok(value: T) Self {
            return .{ .ok = value };
        }

        pub fn Err(e: E) Self {
            return .{ .err = e };
        }
    };
}

// ============ 便捷函数 ============

/// 创建有效的 Validation
pub fn valid(comptime T: type, comptime E: type, value: T) Validation(T, E) {
    return Validation(T, E).Valid(value);
}

/// 创建无效的 Validation（单个错误）
pub fn invalid(comptime T: type, comptime E: type, err: E) Validation(T, E) {
    return Validation(T, E).Invalid(err);
}

/// 创建无效的 Validation（多个错误）
pub fn invalidMany(comptime T: type, comptime E: type, errors: []const E) Validation(T, E) {
    return Validation(T, E).InvalidMany(errors);
}

// ============ 验证器组合器 ============

/// 验证规则类型
pub fn Validator(comptime T: type, comptime E: type) type {
    return struct {
        validateFn: *const fn (T) Validation(T, E),

        const Self = @This();

        /// 运行验证
        pub fn validate(self: Self, value: T) Validation(T, E) {
            return self.validateFn(value);
        }

        /// 组合两个验证器（所有规则都必须通过）
        /// 注意：由于 Zig 不支持闭包，组合验证器需要在编译时完成
        pub fn andThen(comptime self: Self, comptime other: Self) Self {
            return .{
                .validateFn = struct {
                    fn validate(value: T) Validation(T, E) {
                        const result1 = self.validateFn(value);
                        if (result1.isInvalid()) return result1;
                        return other.validateFn(value);
                    }
                }.validate,
            };
        }
    };
}

/// 创建验证器
pub fn validator(
    comptime T: type,
    comptime E: type,
    f: *const fn (T) Validation(T, E),
) Validator(T, E) {
    return .{ .validateFn = f };
}

// ============ 常用验证器 ============

/// 字符串验证错误
pub const StringError = enum {
    TooShort,
    TooLong,
    Empty,
    InvalidFormat,
};

/// 数字验证错误
pub const NumberError = enum {
    TooSmall,
    TooLarge,
    NotPositive,
    NotNegative,
    Zero,
};

/// 非空验证
pub fn notEmpty(s: []const u8) Validation([]const u8, StringError) {
    if (s.len == 0) {
        return Validation([]const u8, StringError).Invalid(.Empty);
    }
    return Validation([]const u8, StringError).Valid(s);
}

/// 最小长度验证（返回验证函数）
/// 注意：由于 Zig 不支持闭包，这里使用编译时参数
pub fn minLengthValidator(comptime min: usize) *const fn ([]const u8) Validation([]const u8, StringError) {
    return struct {
        fn validate(s: []const u8) Validation([]const u8, StringError) {
            if (s.len < min) {
                return Validation([]const u8, StringError).Invalid(.TooShort);
            }
            return Validation([]const u8, StringError).Valid(s);
        }
    }.validate;
}

/// 正数验证
pub fn positive(comptime T: type) *const fn (T) Validation(T, NumberError) {
    return struct {
        fn validate(n: T) Validation(T, NumberError) {
            if (n <= 0) {
                return Validation(T, NumberError).Invalid(.NotPositive);
            }
            return Validation(T, NumberError).Valid(n);
        }
    }.validate;
}

/// 非零验证
pub fn nonZero(comptime T: type) *const fn (T) Validation(T, NumberError) {
    return struct {
        fn validate(n: T) Validation(T, NumberError) {
            if (n == 0) {
                return Validation(T, NumberError).Invalid(.Zero);
            }
            return Validation(T, NumberError).Valid(n);
        }
    }.validate;
}

// ============ 批量验证 ============

/// 验证所有值，累积所有错误
pub fn validateAll(
    comptime T: type,
    comptime E: type,
    validations: []const Validation(T, E),
    allocator: Allocator,
) !Validation([]const T, E) {
    var values = try std.ArrayList(T).initCapacity(allocator, validations.len);
    errdefer values.deinit(allocator);

    var errors = try std.ArrayList(E).initCapacity(allocator, validations.len);
    errdefer errors.deinit(allocator);

    for (validations) |v| {
        switch (v) {
            .valid => |val| try values.append(allocator, val),
            .invalid => |errs| try errors.appendSlice(allocator, errs),
        }
    }

    if (errors.items.len > 0) {
        values.deinit(allocator);
        return Validation([]const T, E).InvalidMany(try errors.toOwnedSlice(allocator));
    }

    errors.deinit(allocator);
    return Validation([]const T, E).Valid(try values.toOwnedSlice(allocator));
}

// ============ 测试 ============

test "Validation.Valid" {
    const v = valid(i32, []const u8, 42);
    try std.testing.expect(v.isValid());
    try std.testing.expectEqual(@as(?i32, 42), v.getValue());
}

test "Validation.Invalid" {
    const v = invalid(i32, []const u8, "error");
    try std.testing.expect(v.isInvalid());
    try std.testing.expectEqual(@as(?i32, null), v.getValue());
}

test "Validation.map valid" {
    const v = valid(i32, []const u8, 21);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const mapped = v.map(i32, double);
    try std.testing.expect(mapped.isValid());
    try std.testing.expectEqual(@as(?i32, 42), mapped.getValue());
}

test "Validation.map invalid" {
    const v = invalid(i32, []const u8, "error");

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const mapped = v.map(i32, double);
    try std.testing.expect(mapped.isInvalid());
}

test "Validation.getOrElse" {
    const v1 = valid(i32, []const u8, 42);
    const v2 = invalid(i32, []const u8, "error");

    try std.testing.expectEqual(@as(i32, 42), v1.getOrElse(0));
    try std.testing.expectEqual(@as(i32, 0), v2.getOrElse(0));
}

test "Validation.combine both valid" {
    const allocator = std.testing.allocator;

    const v1 = valid(i32, []const u8, 10);
    const v2 = valid(i32, []const u8, 20);

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const result = try v1.combine(v2, add, allocator);
    try std.testing.expect(result.isValid());
    try std.testing.expectEqual(@as(?i32, 30), result.getValue());
}

test "Validation.combine one invalid" {
    const allocator = std.testing.allocator;

    const v1 = valid(i32, []const u8, 10);
    const v2 = invalid(i32, []const u8, "error");

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const result = try v1.combine(v2, add, allocator);
    try std.testing.expect(result.isInvalid());
}

test "Validation.combine both invalid accumulates errors" {
    const allocator = std.testing.allocator;

    const errors1 = [_][]const u8{"error1"};
    const errors2 = [_][]const u8{"error2"};
    const v1 = invalidMany(i32, []const u8, &errors1);
    const v2 = invalidMany(i32, []const u8, &errors2);

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const result = try v1.combine(v2, add, allocator);
    defer allocator.free(result.getErrors().?);

    try std.testing.expect(result.isInvalid());
    try std.testing.expectEqual(@as(usize, 2), result.getErrors().?.len);
}

test "Validation.fold" {
    const v1 = valid(i32, []const u8, 42);
    const v2 = invalid(i32, []const u8, "error");

    const onValid = struct {
        fn f(x: i32) []const u8 {
            _ = x;
            return "valid";
        }
    }.f;

    const onInvalid = struct {
        fn f(_: []const []const u8) []const u8 {
            return "invalid";
        }
    }.f;

    try std.testing.expectEqualStrings("valid", v1.fold([]const u8, onValid, onInvalid));
    try std.testing.expectEqualStrings("invalid", v2.fold([]const u8, onValid, onInvalid));
}

test "notEmpty validation" {
    const valid_result = notEmpty("hello");
    const invalid_result = notEmpty("");

    try std.testing.expect(valid_result.isValid());
    try std.testing.expect(invalid_result.isInvalid());
}

test "positive validation" {
    const positiveI32 = positive(i32);

    const valid_result = positiveI32(5);
    const invalid_result = positiveI32(-5);
    const zero_result = positiveI32(0);

    try std.testing.expect(valid_result.isValid());
    try std.testing.expect(invalid_result.isInvalid());
    try std.testing.expect(zero_result.isInvalid());
}

test "nonZero validation" {
    const nonZeroI32 = nonZero(i32);

    const valid_result1 = nonZeroI32(5);
    const valid_result2 = nonZeroI32(-5);
    const invalid_result = nonZeroI32(0);

    try std.testing.expect(valid_result1.isValid());
    try std.testing.expect(valid_result2.isValid());
    try std.testing.expect(invalid_result.isInvalid());
}

test "validateAll all valid" {
    const allocator = std.testing.allocator;

    const validations = [_]Validation(i32, []const u8){
        valid(i32, []const u8, 1),
        valid(i32, []const u8, 2),
        valid(i32, []const u8, 3),
    };

    const result = try validateAll(i32, []const u8, &validations, allocator);

    try std.testing.expect(result.isValid());
    const values = result.getValue().?;
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqual(@as(i32, 1), values[0]);
    try std.testing.expectEqual(@as(i32, 2), values[1]);
    try std.testing.expectEqual(@as(i32, 3), values[2]);
}

test "validateAll with invalid accumulates" {
    const allocator = std.testing.allocator;

    const validations = [_]Validation(i32, []const u8){
        valid(i32, []const u8, 1),
        invalid(i32, []const u8, "error1"),
        invalid(i32, []const u8, "error2"),
    };

    const result = try validateAll(i32, []const u8, &validations, allocator);

    try std.testing.expect(result.isInvalid());
    const errors = result.getErrors().?;
    defer allocator.free(errors);

    try std.testing.expectEqual(@as(usize, 2), errors.len);
}
