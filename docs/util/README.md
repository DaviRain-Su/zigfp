# Util 模块

工具模块，提供常用的辅助功能。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| auth.md | `BasicAuth`, `BearerToken`, `ApiKey` | HTTP 认证 |
| i18n.md | `Locale`, `MessageBundle` | 国际化支持 |
| schema.md | `Schema` | JSON Schema 验证 |

## 导入方式

```zig
const util = @import("zigfp").util;

const BasicAuth = util.BasicAuth;
const Locale = util.Locale;
const Schema = util.Schema;
```

## 快速示例

### Auth - HTTP 认证

```zig
// Basic Auth
const basic = BasicAuth.init("username", "password");
const header = try basic.toHeader(allocator);
defer allocator.free(header);

// Bearer Token
const bearer = BearerToken.init("my-access-token");
const auth_header = try bearer.toHeader(allocator);

// API Key
const apikey = ApiKey.init(.header, "X-API-Key", "secret-key");
```

### I18n - 国际化

```zig
var bundle = MessageBundle.init(allocator);
defer bundle.deinit();

try bundle.addMessage(.zh_CN, "error.not_found", "找不到资源: {0}");
try bundle.addMessage(.en_US, "error.not_found", "Resource not found: {0}");

const msg = try bundle.format(.zh_CN, "error.not_found", &.{"user"}, allocator);
defer allocator.free(msg);
// 输出: "找不到资源: user"
```

### Schema - JSON Schema 验证

```zig
const schema = Schema.object()
    .required("name", Schema.string().minLength(1))
    .required("age", Schema.number().min(0).max(150))
    .optional("email", Schema.string());

const result = schema.validate(json_value);
if (result.isValid()) {
    // 验证通过
} else {
    for (result.errors) |err| {
        std.debug.print("Error at {s}: {s}\n", .{err.path, err.message});
    }
}
```

## 支持的语言区域

| Locale | 说明 |
|--------|------|
| `zh_CN` | 简体中文（中国） |
| `zh_TW` | 繁体中文（台湾） |
| `en_US` | 英语（美国） |
| `en_GB` | 英语（英国） |
| `ja_JP` | 日语 |
| `ko_KR` | 韩语 |
| `fr_FR` | 法语 |
| `de_DE` | 德语 |
| `es_ES` | 西班牙语 |
| `ru_RU` | 俄语 |
