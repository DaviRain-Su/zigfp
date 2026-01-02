const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("../parser/json.zig");
const JsonValue = json.JsonValue;

/// JSON Schema 验证模块
///
/// 提供 JSON 数据的 Schema 验证功能：
/// - 类型验证 (string, number, boolean, array, object, null)
/// - 必填字段验证
/// - 字符串模式匹配
/// - 数值范围验证
/// - 数组长度验证
/// - 嵌套对象验证
///
/// 示例:
/// ```zig
/// var schema = Schema.object()
///     .required("name", Schema.string().minLength(1))
///     .required("age", Schema.number().min(0).max(150))
///     .optional("email", Schema.string());
///
/// const result = schema.validate(json_value);
/// if (result.isValid()) {
///     // 验证通过
/// } else {
///     for (result.errors) |err| {
///         std.debug.print("Error at {s}: {s}\n", .{err.path, err.message});
///     }
/// }
/// ```
/// Schema 类型
pub const SchemaType = enum {
    string,
    number,
    integer,
    boolean,
    array,
    object,
    null_type,
    any,
};

/// 验证错误
pub const ValidationError = struct {
    path: []const u8,
    message: []const u8,
    error_type: ErrorType,

    pub const ErrorType = enum {
        type_mismatch,
        required_missing,
        min_length,
        max_length,
        minimum,
        maximum,
        pattern_mismatch,
        min_items,
        max_items,
        custom,
    };
};

/// 验证结果
pub const ValidationResult = struct {
    valid: bool,
    errors: []ValidationError,
    allocator: Allocator,

    const Self = @This();

    pub fn success(allocator: Allocator) Self {
        return .{
            .valid = true,
            .errors = &.{},
            .allocator = allocator,
        };
    }

    pub fn failure(allocator: Allocator, errors: []ValidationError) Self {
        return .{
            .valid = false,
            .errors = errors,
            .allocator = allocator,
        };
    }

    pub fn isValid(self: *const Self) bool {
        return self.valid;
    }

    pub fn deinit(self: *Self) void {
        for (self.errors) |err| {
            self.allocator.free(err.path);
            self.allocator.free(err.message);
        }
        if (self.errors.len > 0) {
            self.allocator.free(self.errors);
        }
    }
};

/// Schema 定义
pub const Schema = struct {
    schema_type: SchemaType,
    // 字符串约束
    min_length: ?usize,
    max_length: ?usize,
    pattern: ?[]const u8,
    // 数值约束
    minimum: ?f64,
    maximum: ?f64,
    exclusive_minimum: bool,
    exclusive_maximum: bool,
    // 数组约束
    min_items: ?usize,
    max_items: ?usize,
    items_schema: ?*const Schema,
    // 对象约束
    properties: ?std.StringHashMap(PropertySchema),
    required_fields: ?[]const []const u8,
    // 其他
    nullable: bool,
    enum_values: ?[]const []const u8,
    allocator: ?Allocator,

    /// 属性 Schema
    pub const PropertySchema = struct {
        schema: Schema,
        required: bool,
    };

    const Self = @This();

    /// 创建任意类型 Schema
    pub fn any() Self {
        return init(.any);
    }

    /// 创建字符串 Schema
    pub fn string() Self {
        return init(.string);
    }

    /// 创建数字 Schema
    pub fn number() Self {
        return init(.number);
    }

    /// 创建整数 Schema
    pub fn integer() Self {
        return init(.integer);
    }

    /// 创建布尔 Schema
    pub fn boolean() Self {
        return init(.boolean);
    }

    /// 创建数组 Schema
    pub fn array() Self {
        return init(.array);
    }

    /// 创建对象 Schema
    pub fn object() Self {
        return init(.object);
    }

    /// 创建 null Schema
    pub fn nullType() Self {
        return init(.null_type);
    }

    fn init(schema_type: SchemaType) Self {
        return .{
            .schema_type = schema_type,
            .min_length = null,
            .max_length = null,
            .pattern = null,
            .minimum = null,
            .maximum = null,
            .exclusive_minimum = false,
            .exclusive_maximum = false,
            .min_items = null,
            .max_items = null,
            .items_schema = null,
            .properties = null,
            .required_fields = null,
            .nullable = false,
            .enum_values = null,
            .allocator = null,
        };
    }

    // ========== 字符串约束 ==========

    /// 设置最小长度
    pub fn minLength(self: Self, len: usize) Self {
        var s = self;
        s.min_length = len;
        return s;
    }

    /// 设置最大长度
    pub fn maxLength(self: Self, len: usize) Self {
        var s = self;
        s.max_length = len;
        return s;
    }

    /// 设置正则模式（简化版，仅支持前缀/后缀匹配）
    pub fn matchPattern(self: Self, pat: []const u8) Self {
        var s = self;
        s.pattern = pat;
        return s;
    }

    // ========== 数值约束 ==========

    /// 设置最小值
    pub fn min(self: Self, value: f64) Self {
        var s = self;
        s.minimum = value;
        return s;
    }

    /// 设置最大值
    pub fn max(self: Self, value: f64) Self {
        var s = self;
        s.maximum = value;
        return s;
    }

    /// 设置最小值（排他）
    pub fn exclusiveMin(self: Self, value: f64) Self {
        var s = self;
        s.minimum = value;
        s.exclusive_minimum = true;
        return s;
    }

    /// 设置最大值（排他）
    pub fn exclusiveMax(self: Self, value: f64) Self {
        var s = self;
        s.maximum = value;
        s.exclusive_maximum = true;
        return s;
    }

    // ========== 数组约束 ==========

    /// 设置数组项 Schema
    pub fn items(self: Self, item_schema: *const Schema) Self {
        var s = self;
        s.items_schema = item_schema;
        return s;
    }

    /// 设置最小项数
    pub fn minItems(self: Self, count: usize) Self {
        var s = self;
        s.min_items = count;
        return s;
    }

    /// 设置最大项数
    pub fn maxItems(self: Self, count: usize) Self {
        var s = self;
        s.max_items = count;
        return s;
    }

    // ========== 通用约束 ==========

    /// 允许 null 值
    pub fn allowNull(self: Self) Self {
        var s = self;
        s.nullable = true;
        return s;
    }

    /// 设置枚举值
    pub fn enumOf(self: Self, values: []const []const u8) Self {
        var s = self;
        s.enum_values = values;
        return s;
    }

    // ========== 验证 ==========

    /// 验证 JSON 值
    pub fn validate(self: *const Self, value: *const JsonValue, allocator: Allocator) ValidationResult {
        var errors = std.ArrayList(ValidationError).initCapacity(allocator, 4) catch {
            return ValidationResult.success(allocator);
        };

        self.validateInternal(value, "", &errors, allocator) catch {
            errors.deinit(allocator);
            return ValidationResult.success(allocator);
        };

        if (errors.items.len == 0) {
            errors.deinit(allocator);
            return ValidationResult.success(allocator);
        }

        const owned_errors = errors.toOwnedSlice(allocator) catch {
            errors.deinit(allocator);
            return ValidationResult.success(allocator);
        };
        return ValidationResult.failure(allocator, owned_errors);
    }

    fn validateInternal(
        self: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) Allocator.Error!void {
        // 检查 null
        if (value.* == .null) {
            if (self.nullable or self.schema_type == .null_type) {
                return;
            }
            try addError(errors, path, "Expected non-null value", .type_mismatch, allocator);
            return;
        }

        // 类型检查
        switch (self.schema_type) {
            .any => {},
            .string => try self.validateString(value, path, errors, allocator),
            .number, .integer => try self.validateNumber(value, path, errors, allocator),
            .boolean => try self.validateBoolean(value, path, errors, allocator),
            .array => try self.validateArray(value, path, errors, allocator),
            .object => try self.validateObject(value, path, errors, allocator),
            .null_type => {
                if (value.* != .null) {
                    try addError(errors, path, "Expected null", .type_mismatch, allocator);
                }
            },
        }
    }

    fn validateString(
        self: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) !void {
        const str = switch (value.*) {
            .string => |s| s,
            else => {
                try addError(errors, path, "Expected string", .type_mismatch, allocator);
                return;
            },
        };

        if (self.min_length) |min_len| {
            if (str.len < min_len) {
                try addError(errors, path, "String too short", .min_length, allocator);
            }
        }

        if (self.max_length) |max_len| {
            if (str.len > max_len) {
                try addError(errors, path, "String too long", .max_length, allocator);
            }
        }

        if (self.pattern) |pat| {
            // 简化的模式匹配：支持 startsWith 和 endsWith
            if (std.mem.startsWith(u8, pat, "^") and std.mem.endsWith(u8, pat, "$")) {
                const exact = pat[1 .. pat.len - 1];
                if (!std.mem.eql(u8, str, exact)) {
                    try addError(errors, path, "Pattern mismatch", .pattern_mismatch, allocator);
                }
            } else if (std.mem.startsWith(u8, pat, "^")) {
                if (!std.mem.startsWith(u8, str, pat[1..])) {
                    try addError(errors, path, "Pattern mismatch", .pattern_mismatch, allocator);
                }
            } else if (std.mem.endsWith(u8, pat, "$")) {
                if (!std.mem.endsWith(u8, str, pat[0 .. pat.len - 1])) {
                    try addError(errors, path, "Pattern mismatch", .pattern_mismatch, allocator);
                }
            } else if (!std.mem.containsAtLeast(u8, str, 1, pat)) {
                try addError(errors, path, "Pattern mismatch", .pattern_mismatch, allocator);
            }
        }

        if (self.enum_values) |enum_vals| {
            var found = false;
            for (enum_vals) |v| {
                if (std.mem.eql(u8, str, v)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try addError(errors, path, "Value not in enum", .custom, allocator);
            }
        }
    }

    fn validateNumber(
        self: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) !void {
        const num: f64 = switch (value.*) {
            .int => |i| @floatFromInt(i),
            .float => |f| f,
            else => {
                try addError(errors, path, "Expected number", .type_mismatch, allocator);
                return;
            },
        };

        // 整数检查
        if (self.schema_type == .integer) {
            if (value.* != .int) {
                const frac = @abs(num - @round(num));
                if (frac > 0.0001) {
                    try addError(errors, path, "Expected integer", .type_mismatch, allocator);
                    return;
                }
            }
        }

        if (self.minimum) |min_val| {
            if (self.exclusive_minimum) {
                if (num <= min_val) {
                    try addError(errors, path, "Value below minimum", .minimum, allocator);
                }
            } else {
                if (num < min_val) {
                    try addError(errors, path, "Value below minimum", .minimum, allocator);
                }
            }
        }

        if (self.maximum) |max_val| {
            if (self.exclusive_maximum) {
                if (num >= max_val) {
                    try addError(errors, path, "Value above maximum", .maximum, allocator);
                }
            } else {
                if (num > max_val) {
                    try addError(errors, path, "Value above maximum", .maximum, allocator);
                }
            }
        }
    }

    fn validateBoolean(
        _: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) !void {
        if (value.* != .bool) {
            try addError(errors, path, "Expected boolean", .type_mismatch, allocator);
        }
    }

    fn validateArray(
        self: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) !void {
        const arr = switch (value.*) {
            .array => |a| a,
            else => {
                try addError(errors, path, "Expected array", .type_mismatch, allocator);
                return;
            },
        };

        if (self.min_items) |min_count| {
            if (arr.len < min_count) {
                try addError(errors, path, "Array too short", .min_items, allocator);
            }
        }

        if (self.max_items) |max_count| {
            if (arr.len > max_count) {
                try addError(errors, path, "Array too long", .max_items, allocator);
            }
        }

        // 验证数组项
        if (self.items_schema) |item_schema| {
            for (arr, 0..) |*item, i| {
                const item_path = std.fmt.allocPrint(allocator, "{s}[{d}]", .{ path, i }) catch continue;
                defer allocator.free(item_path);
                item_schema.validateInternal(item, item_path, errors, allocator) catch continue;
            }
        }
    }

    fn validateObject(
        self: *const Self,
        value: *const JsonValue,
        path: []const u8,
        errors: *std.ArrayList(ValidationError),
        allocator: Allocator,
    ) !void {
        const obj = switch (value.*) {
            .object => |o| o,
            else => {
                try addError(errors, path, "Expected object", .type_mismatch, allocator);
                return;
            },
        };

        // 检查必填字段
        if (self.required_fields) |required| {
            for (required) |field| {
                if (!obj.contains(field)) {
                    const field_path = if (path.len > 0)
                        std.fmt.allocPrint(allocator, "{s}.{s}", .{ path, field }) catch continue
                    else
                        std.fmt.allocPrint(allocator, "{s}", .{field}) catch continue;
                    defer allocator.free(field_path);
                    try addError(errors, field_path, "Required field missing", .required_missing, allocator);
                }
            }
        }

        // 验证属性
        if (self.properties) |props| {
            var it = obj.iterator();
            while (it.next()) |entry| {
                if (props.get(entry.key_ptr.*)) |prop_schema| {
                    const field_path = if (path.len > 0)
                        std.fmt.allocPrint(allocator, "{s}.{s}", .{ path, entry.key_ptr.* }) catch continue
                    else
                        std.fmt.allocPrint(allocator, "{s}", .{entry.key_ptr.*}) catch continue;
                    defer allocator.free(field_path);
                    try prop_schema.schema.validateInternal(entry.value_ptr, field_path, errors, allocator);
                }
            }
        }
    }

    fn addError(
        errors: *std.ArrayList(ValidationError),
        path: []const u8,
        message: []const u8,
        error_type: ValidationError.ErrorType,
        allocator: Allocator,
    ) !void {
        const owned_path = try allocator.dupe(u8, path);
        const owned_message = try allocator.dupe(u8, message);
        try errors.append(allocator, .{
            .path = owned_path,
            .message = owned_message,
            .error_type = error_type,
        });
    }
};

/// Schema 构建器 - 用于构建复杂对象 Schema
pub const SchemaBuilder = struct {
    allocator: Allocator,
    properties: std.StringHashMap(Schema.PropertySchema),
    required: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .properties = std.StringHashMap(Schema.PropertySchema).init(allocator),
            .required = std.ArrayList([]const u8).initCapacity(allocator, 4) catch unreachable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.properties.deinit();
        self.required.deinit(self.allocator);
    }

    /// 添加必填属性
    pub fn requiredProp(self: *Self, name: []const u8, schema: Schema) !*Self {
        try self.properties.put(name, .{ .schema = schema, .required = true });
        try self.required.append(self.allocator, name);
        return self;
    }

    /// 添加可选属性
    pub fn optionalProp(self: *Self, name: []const u8, schema: Schema) !*Self {
        try self.properties.put(name, .{ .schema = schema, .required = false });
        return self;
    }

    /// 构建 Schema
    pub fn build(self: *Self) Schema {
        var schema = Schema.object();
        schema.properties = self.properties;
        schema.required_fields = self.required.toOwnedSlice(self.allocator) catch null;
        schema.allocator = self.allocator;
        return schema;
    }
};

/// 快捷函数：创建对象 Schema 构建器
pub fn objectSchema(allocator: Allocator) SchemaBuilder {
    return SchemaBuilder.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "Schema string validation" {
    const allocator = std.testing.allocator;

    const schema = Schema.string().minLength(2).maxLength(10);

    // 有效字符串
    const valid_str = JsonValue{ .string = "hello" };
    var result1 = schema.validate(&valid_str, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    // 太短
    const short_str = JsonValue{ .string = "a" };
    var result2 = schema.validate(&short_str, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());
    try std.testing.expectEqual(@as(usize, 1), result2.errors.len);

    // 太长
    const long_str = JsonValue{ .string = "this is a very long string" };
    var result3 = schema.validate(&long_str, allocator);
    defer result3.deinit();
    try std.testing.expect(!result3.isValid());
}

test "Schema number validation" {
    const allocator = std.testing.allocator;

    const schema = Schema.number().min(0).max(100);

    // 有效数字
    const valid_num = JsonValue{ .int = 50 };
    var result1 = schema.validate(&valid_num, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    // 太小
    const small_num = JsonValue{ .int = -1 };
    var result2 = schema.validate(&small_num, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());

    // 太大
    const big_num = JsonValue{ .int = 101 };
    var result3 = schema.validate(&big_num, allocator);
    defer result3.deinit();
    try std.testing.expect(!result3.isValid());
}

test "Schema integer validation" {
    const allocator = std.testing.allocator;

    const schema = Schema.integer();

    // 有效整数
    const valid_int = JsonValue{ .int = 42 };
    var result1 = schema.validate(&valid_int, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    // 浮点数（应该失败）
    const float_val = JsonValue{ .float = 3.14 };
    var result2 = schema.validate(&float_val, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());
}

test "Schema boolean validation" {
    const allocator = std.testing.allocator;

    const schema = Schema.boolean();

    const valid_bool = JsonValue{ .bool = true };
    var result1 = schema.validate(&valid_bool, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    const invalid = JsonValue{ .string = "true" };
    var result2 = schema.validate(&invalid, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());
}

test "Schema array validation" {
    const allocator = std.testing.allocator;

    const item_schema = Schema.string();
    const schema = Schema.array().items(&item_schema).minItems(1).maxItems(3);

    // 有效数组
    var items1 = [_]JsonValue{
        .{ .string = "a" },
        .{ .string = "b" },
    };
    const valid_arr = JsonValue{ .array = &items1 };
    var result1 = schema.validate(&valid_arr, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    // 空数组
    var items2 = [_]JsonValue{};
    const empty_arr = JsonValue{ .array = &items2 };
    var result2 = schema.validate(&empty_arr, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());
}

test "Schema nullable" {
    const allocator = std.testing.allocator;

    const schema = Schema.string().allowNull();

    // null 值
    const null_val = JsonValue{ .null = {} };
    var result = schema.validate(&null_val, allocator);
    defer result.deinit();
    try std.testing.expect(result.isValid());
}

test "Schema enum validation" {
    const allocator = std.testing.allocator;

    const schema = Schema.string().enumOf(&.{ "red", "green", "blue" });

    const valid = JsonValue{ .string = "red" };
    var result1 = schema.validate(&valid, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    const invalid = JsonValue{ .string = "yellow" };
    var result2 = schema.validate(&invalid, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());
}

test "Schema type mismatch" {
    const allocator = std.testing.allocator;

    const schema = Schema.string();

    const num = JsonValue{ .int = 42 };
    var result = schema.validate(&num, allocator);
    defer result.deinit();

    try std.testing.expect(!result.isValid());
    try std.testing.expectEqual(@as(usize, 1), result.errors.len);
    try std.testing.expectEqual(ValidationError.ErrorType.type_mismatch, result.errors[0].error_type);
}

test "SchemaBuilder object" {
    const allocator = std.testing.allocator;

    var builder = objectSchema(allocator);
    _ = try builder.requiredProp("name", Schema.string().minLength(1));
    _ = try builder.optionalProp("age", Schema.integer().min(0));
    var schema = builder.build();

    // 有效对象
    var obj1 = std.StringHashMap(JsonValue).init(allocator);
    defer obj1.deinit();
    try obj1.put("name", .{ .string = "Alice" });
    try obj1.put("age", .{ .int = 25 });

    const valid_obj = JsonValue{ .object = obj1 };
    var result1 = schema.validate(&valid_obj, allocator);
    defer result1.deinit();
    try std.testing.expect(result1.isValid());

    // 缺少必填字段
    var obj2 = std.StringHashMap(JsonValue).init(allocator);
    defer obj2.deinit();
    try obj2.put("age", .{ .int = 25 });

    const missing_required = JsonValue{ .object = obj2 };
    var result2 = schema.validate(&missing_required, allocator);
    defer result2.deinit();
    try std.testing.expect(!result2.isValid());

    // 清理
    if (schema.required_fields) |rf| {
        allocator.free(rf);
    }
    builder.deinit();
}
