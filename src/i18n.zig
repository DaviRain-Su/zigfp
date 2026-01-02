const std = @import("std");
const Allocator = std.mem.Allocator;

/// 国际化（i18n）模块
///
/// 提供多语言错误消息和本地化支持：
/// - 语言区域设置（Locale）
/// - 消息包（MessageBundle）
/// - 参数化消息格式化
///
/// 示例:
/// ```zig
/// var bundle = MessageBundle.init(allocator);
/// defer bundle.deinit();
///
/// try bundle.addMessage(.zh_CN, "error.not_found", "找不到资源: {0}");
/// try bundle.addMessage(.en_US, "error.not_found", "Resource not found: {0}");
///
/// const msg = try bundle.format(.zh_CN, "error.not_found", &.{"user"}, allocator);
/// defer allocator.free(msg);
/// // 输出: "找不到资源: user"
/// ```
/// 语言区域设置
pub const Locale = enum {
    /// 简体中文（中国）
    zh_CN,
    /// 繁体中文（台湾）
    zh_TW,
    /// 英语（美国）
    en_US,
    /// 英语（英国）
    en_GB,
    /// 日语
    ja_JP,
    /// 韩语
    ko_KR,
    /// 法语
    fr_FR,
    /// 德语
    de_DE,
    /// 西班牙语
    es_ES,
    /// 俄语
    ru_RU,

    /// 获取语言代码
    pub fn getLanguageCode(self: Locale) []const u8 {
        return switch (self) {
            .zh_CN, .zh_TW => "zh",
            .en_US, .en_GB => "en",
            .ja_JP => "ja",
            .ko_KR => "ko",
            .fr_FR => "fr",
            .de_DE => "de",
            .es_ES => "es",
            .ru_RU => "ru",
        };
    }

    /// 获取完整区域代码
    pub fn getCode(self: Locale) []const u8 {
        return switch (self) {
            .zh_CN => "zh-CN",
            .zh_TW => "zh-TW",
            .en_US => "en-US",
            .en_GB => "en-GB",
            .ja_JP => "ja-JP",
            .ko_KR => "ko-KR",
            .fr_FR => "fr-FR",
            .de_DE => "de-DE",
            .es_ES => "es-ES",
            .ru_RU => "ru-RU",
        };
    }

    /// 获取显示名称
    pub fn getDisplayName(self: Locale) []const u8 {
        return switch (self) {
            .zh_CN => "简体中文",
            .zh_TW => "繁體中文",
            .en_US => "English (US)",
            .en_GB => "English (UK)",
            .ja_JP => "日本語",
            .ko_KR => "한국어",
            .fr_FR => "Français",
            .de_DE => "Deutsch",
            .es_ES => "Español",
            .ru_RU => "Русский",
        };
    }

    /// 从字符串解析
    pub fn fromString(code: []const u8) ?Locale {
        const locales = [_]struct { code: []const u8, locale: Locale }{
            .{ .code = "zh-CN", .locale = .zh_CN },
            .{ .code = "zh_CN", .locale = .zh_CN },
            .{ .code = "zh-TW", .locale = .zh_TW },
            .{ .code = "zh_TW", .locale = .zh_TW },
            .{ .code = "en-US", .locale = .en_US },
            .{ .code = "en_US", .locale = .en_US },
            .{ .code = "en-GB", .locale = .en_GB },
            .{ .code = "en_GB", .locale = .en_GB },
            .{ .code = "ja-JP", .locale = .ja_JP },
            .{ .code = "ja_JP", .locale = .ja_JP },
            .{ .code = "ko-KR", .locale = .ko_KR },
            .{ .code = "ko_KR", .locale = .ko_KR },
            .{ .code = "fr-FR", .locale = .fr_FR },
            .{ .code = "fr_FR", .locale = .fr_FR },
            .{ .code = "de-DE", .locale = .de_DE },
            .{ .code = "de_DE", .locale = .de_DE },
            .{ .code = "es-ES", .locale = .es_ES },
            .{ .code = "es_ES", .locale = .es_ES },
            .{ .code = "ru-RU", .locale = .ru_RU },
            .{ .code = "ru_RU", .locale = .ru_RU },
        };

        for (locales) |entry| {
            if (std.mem.eql(u8, code, entry.code)) {
                return entry.locale;
            }
        }
        return null;
    }
};

/// 消息键
pub const MessageKey = []const u8;

/// 消息包 - 管理多语言消息
pub const MessageBundle = struct {
    allocator: Allocator,
    messages: std.StringHashMap(LocaleMessages),
    default_locale: Locale,
    fallback_locale: ?Locale,

    /// 特定语言的消息集合
    const LocaleMessages = std.StringHashMap([]const u8);

    const Self = @This();

    /// 初始化消息包
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .messages = std.StringHashMap(LocaleMessages).init(allocator),
            .default_locale = .en_US,
            .fallback_locale = null,
        };
    }

    /// 使用默认语言初始化
    pub fn initWithLocale(allocator: Allocator, default_locale: Locale) Self {
        return .{
            .allocator = allocator,
            .messages = std.StringHashMap(LocaleMessages).init(allocator),
            .default_locale = default_locale,
            .fallback_locale = null,
        };
    }

    /// 释放资源
    pub fn deinit(self: *Self) void {
        var it = self.messages.valueIterator();
        while (it.next()) |locale_msgs| {
            // 释放所有消息值
            var msg_it = locale_msgs.valueIterator();
            while (msg_it.next()) |msg| {
                self.allocator.free(msg.*);
            }
            // 释放所有消息键
            var key_it = locale_msgs.keyIterator();
            while (key_it.next()) |key| {
                self.allocator.free(key.*);
            }
            locale_msgs.deinit();
        }
        // 释放语言键
        var lang_key_it = self.messages.keyIterator();
        while (lang_key_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.messages.deinit();
    }

    /// 设置默认语言
    pub fn setDefaultLocale(self: *Self, locale: Locale) void {
        self.default_locale = locale;
    }

    /// 设置回退语言
    pub fn setFallbackLocale(self: *Self, locale: ?Locale) void {
        self.fallback_locale = locale;
    }

    /// 添加消息
    pub fn addMessage(self: *Self, locale: Locale, key: MessageKey, message: []const u8) !void {
        const locale_code = locale.getCode();

        // 获取或创建语言消息集合
        const result = try self.messages.getOrPut(locale_code);
        if (!result.found_existing) {
            const owned_key = try self.allocator.dupe(u8, locale_code);
            result.key_ptr.* = owned_key;
            result.value_ptr.* = std.StringHashMap([]const u8).init(self.allocator);
        }

        // 复制键和值
        const owned_msg_key = try self.allocator.dupe(u8, key);
        const owned_message = try self.allocator.dupe(u8, message);

        // 如果已存在，释放旧值
        if (result.value_ptr.get(key)) |old_msg| {
            self.allocator.free(old_msg);
        }

        try result.value_ptr.put(owned_msg_key, owned_message);
    }

    /// 获取消息（不格式化）
    pub fn getMessage(self: *const Self, locale: Locale, key: MessageKey) ?[]const u8 {
        // 尝试指定语言
        if (self.messages.get(locale.getCode())) |locale_msgs| {
            if (locale_msgs.get(key)) |msg| {
                return msg;
            }
        }

        // 尝试回退语言
        if (self.fallback_locale) |fallback| {
            if (self.messages.get(fallback.getCode())) |fallback_msgs| {
                if (fallback_msgs.get(key)) |msg| {
                    return msg;
                }
            }
        }

        // 尝试默认语言
        if (locale != self.default_locale) {
            if (self.messages.get(self.default_locale.getCode())) |default_msgs| {
                if (default_msgs.get(key)) |msg| {
                    return msg;
                }
            }
        }

        return null;
    }

    /// 获取消息或返回键本身
    pub fn getMessageOrKey(self: *const Self, locale: Locale, key: MessageKey) []const u8 {
        return self.getMessage(locale, key) orelse key;
    }

    /// 格式化消息，替换占位符 {0}, {1}, {2}, ...
    pub fn format(self: *const Self, locale: Locale, key: MessageKey, args: []const []const u8, allocator: Allocator) ![]u8 {
        const template = self.getMessage(locale, key) orelse return allocator.dupe(u8, key);
        return formatMessage(template, args, allocator);
    }

    /// 检查消息是否存在
    pub fn hasMessage(self: *const Self, locale: Locale, key: MessageKey) bool {
        if (self.messages.get(locale.getCode())) |locale_msgs| {
            return locale_msgs.contains(key);
        }
        return false;
    }

    /// 获取所有支持的语言
    pub fn getSupportedLocales(self: *const Self, allocator: Allocator) ![]Locale {
        var locales = try std.ArrayList(Locale).initCapacity(allocator, self.messages.count());
        defer locales.deinit(allocator);

        var it = self.messages.keyIterator();
        while (it.next()) |key| {
            if (Locale.fromString(key.*)) |locale| {
                try locales.append(allocator, locale);
            }
        }

        return locales.toOwnedSlice(allocator);
    }
};

/// 格式化消息模板
///
/// 替换 {0}, {1}, {2}, ... 占位符
pub fn formatMessage(template: []const u8, args: []const []const u8, allocator: Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, template.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < template.len) {
        if (template[i] == '{' and i + 2 < template.len) {
            // 查找 }
            var end = i + 1;
            while (end < template.len and template[end] != '}') : (end += 1) {}

            if (end < template.len and template[end] == '}') {
                // 解析索引
                const index_str = template[i + 1 .. end];
                if (std.fmt.parseInt(usize, index_str, 10)) |index| {
                    if (index < args.len) {
                        try result.appendSlice(allocator, args[index]);
                        i = end + 1;
                        continue;
                    }
                } else |_| {}
            }
        }

        try result.append(allocator, template[i]);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

/// 预定义的错误消息
pub const BuiltinMessages = struct {
    /// 加载内置中英文消息
    pub fn load(bundle: *MessageBundle) !void {
        // 英文消息
        try bundle.addMessage(.en_US, "error.not_found", "Resource not found: {0}");
        try bundle.addMessage(.en_US, "error.invalid_input", "Invalid input: {0}");
        try bundle.addMessage(.en_US, "error.unauthorized", "Unauthorized access");
        try bundle.addMessage(.en_US, "error.forbidden", "Access forbidden");
        try bundle.addMessage(.en_US, "error.timeout", "Operation timed out after {0}ms");
        try bundle.addMessage(.en_US, "error.connection_failed", "Failed to connect to {0}");
        try bundle.addMessage(.en_US, "error.validation_failed", "Validation failed: {0}");
        try bundle.addMessage(.en_US, "error.internal", "Internal error occurred");
        try bundle.addMessage(.en_US, "error.rate_limited", "Rate limit exceeded, retry after {0}s");
        try bundle.addMessage(.en_US, "error.bad_request", "Bad request: {0}");

        // 中文消息
        try bundle.addMessage(.zh_CN, "error.not_found", "找不到资源: {0}");
        try bundle.addMessage(.zh_CN, "error.invalid_input", "无效输入: {0}");
        try bundle.addMessage(.zh_CN, "error.unauthorized", "未授权访问");
        try bundle.addMessage(.zh_CN, "error.forbidden", "禁止访问");
        try bundle.addMessage(.zh_CN, "error.timeout", "操作超时，已等待 {0}ms");
        try bundle.addMessage(.zh_CN, "error.connection_failed", "无法连接到 {0}");
        try bundle.addMessage(.zh_CN, "error.validation_failed", "验证失败: {0}");
        try bundle.addMessage(.zh_CN, "error.internal", "发生内部错误");
        try bundle.addMessage(.zh_CN, "error.rate_limited", "请求过于频繁，请 {0}s 后重试");
        try bundle.addMessage(.zh_CN, "error.bad_request", "错误的请求: {0}");

        // 日文消息
        try bundle.addMessage(.ja_JP, "error.not_found", "リソースが見つかりません: {0}");
        try bundle.addMessage(.ja_JP, "error.invalid_input", "無効な入力: {0}");
        try bundle.addMessage(.ja_JP, "error.unauthorized", "認証されていません");
        try bundle.addMessage(.ja_JP, "error.forbidden", "アクセスが禁止されています");
        try bundle.addMessage(.ja_JP, "error.timeout", "操作がタイムアウトしました: {0}ms");
    }
};

/// 本地化上下文 - 线程本地的语言设置
pub const LocaleContext = struct {
    current_locale: Locale,
    bundle: ?*const MessageBundle,

    const Self = @This();

    pub fn init(locale: Locale) Self {
        return .{
            .current_locale = locale,
            .bundle = null,
        };
    }

    pub fn withBundle(locale: Locale, bundle: *const MessageBundle) Self {
        return .{
            .current_locale = locale,
            .bundle = bundle,
        };
    }

    pub fn setLocale(self: *Self, locale: Locale) void {
        self.current_locale = locale;
    }

    pub fn getLocale(self: *const Self) Locale {
        return self.current_locale;
    }

    pub fn getMessage(self: *const Self, key: MessageKey) ?[]const u8 {
        if (self.bundle) |bundle| {
            return bundle.getMessage(self.current_locale, key);
        }
        return null;
    }

    pub fn format(self: *const Self, key: MessageKey, args: []const []const u8, allocator: Allocator) ![]u8 {
        if (self.bundle) |bundle| {
            return bundle.format(self.current_locale, key, args, allocator);
        }
        return allocator.dupe(u8, key);
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Locale basic properties" {
    try std.testing.expectEqualStrings("zh", Locale.zh_CN.getLanguageCode());
    try std.testing.expectEqualStrings("en", Locale.en_US.getLanguageCode());
    try std.testing.expectEqualStrings("zh-CN", Locale.zh_CN.getCode());
    try std.testing.expectEqualStrings("en-US", Locale.en_US.getCode());
    try std.testing.expectEqualStrings("简体中文", Locale.zh_CN.getDisplayName());
}

test "Locale fromString" {
    try std.testing.expectEqual(Locale.zh_CN, Locale.fromString("zh-CN").?);
    try std.testing.expectEqual(Locale.zh_CN, Locale.fromString("zh_CN").?);
    try std.testing.expectEqual(Locale.en_US, Locale.fromString("en-US").?);
    try std.testing.expect(Locale.fromString("invalid") == null);
}

test "MessageBundle add and get" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try bundle.addMessage(.en_US, "greeting", "Hello");
    try bundle.addMessage(.zh_CN, "greeting", "你好");

    try std.testing.expectEqualStrings("Hello", bundle.getMessage(.en_US, "greeting").?);
    try std.testing.expectEqualStrings("你好", bundle.getMessage(.zh_CN, "greeting").?);
}

test "MessageBundle fallback" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.initWithLocale(allocator, .en_US);
    defer bundle.deinit();

    try bundle.addMessage(.en_US, "greeting", "Hello");
    // zh_CN 没有 greeting，应该回退到默认语言

    const msg = bundle.getMessage(.zh_CN, "greeting");
    try std.testing.expectEqualStrings("Hello", msg.?);
}

test "MessageBundle format" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try bundle.addMessage(.en_US, "error.not_found", "Resource not found: {0}");

    const formatted = try bundle.format(.en_US, "error.not_found", &.{"user"}, allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("Resource not found: user", formatted);
}

test "MessageBundle format multiple args" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try bundle.addMessage(.en_US, "greeting", "Hello {0}, welcome to {1}!");

    const formatted = try bundle.format(.en_US, "greeting", &.{ "Alice", "Wonderland" }, allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("Hello Alice, welcome to Wonderland!", formatted);
}

test "formatMessage basic" {
    const allocator = std.testing.allocator;

    const result = try formatMessage("Hello {0}!", &.{"World"}, allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "formatMessage multiple placeholders" {
    const allocator = std.testing.allocator;

    const result = try formatMessage("{0} + {1} = {2}", &.{ "1", "2", "3" }, allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("1 + 2 = 3", result);
}

test "formatMessage missing arg" {
    const allocator = std.testing.allocator;

    const result = try formatMessage("Value: {5}", &.{"only_one"}, allocator);
    defer allocator.free(result);

    // 缺失的参数保持原样
    try std.testing.expectEqualStrings("Value: {5}", result);
}

test "BuiltinMessages load" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try BuiltinMessages.load(&bundle);

    try std.testing.expect(bundle.hasMessage(.en_US, "error.not_found"));
    try std.testing.expect(bundle.hasMessage(.zh_CN, "error.not_found"));
    try std.testing.expect(bundle.hasMessage(.ja_JP, "error.not_found"));
}

test "LocaleContext basic" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try bundle.addMessage(.zh_CN, "hello", "你好 {0}");

    var ctx = LocaleContext.withBundle(.zh_CN, &bundle);

    try std.testing.expectEqual(Locale.zh_CN, ctx.getLocale());

    const msg = try ctx.format("hello", &.{"世界"}, allocator);
    defer allocator.free(msg);

    try std.testing.expectEqualStrings("你好 世界", msg);
}

test "MessageBundle getMessageOrKey" {
    const allocator = std.testing.allocator;

    var bundle = MessageBundle.init(allocator);
    defer bundle.deinit();

    try bundle.addMessage(.en_US, "exists", "I exist");

    try std.testing.expectEqualStrings("I exist", bundle.getMessageOrKey(.en_US, "exists"));
    try std.testing.expectEqualStrings("not.exists", bundle.getMessageOrKey(.en_US, "not.exists"));
}
