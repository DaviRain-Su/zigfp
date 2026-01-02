# Core 模块

核心数据类型，提供函数式编程的基础抽象。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [option.md](option.md) | `Option(T)` | 安全空值处理，Maybe 语义 |
| [result.md](result.md) | `Result(T, E)` | 错误处理，Either 语义 |
| [lazy.md](lazy.md) | `Lazy(T)` | 惰性求值，按需计算 |
| [validation.md](validation.md) | `Validation(T, E)` | 累积错误验证 |

## 导入方式

```zig
const core = @import("zigfp").core;

// 或直接使用便捷导出
const Option = @import("zigfp").Option;
const Result = @import("zigfp").Result;
```

## 快速示例

### Option - 安全空值

```zig
const opt = Option(i32).Some(42);
const doubled = opt.map(i32, struct {
    fn f(x: i32) i32 { return x * 2; }
}.f);
// doubled = Some(84)
```

### Result - 错误处理

```zig
const result = Result(i32, []const u8).Ok(42);
const mapped = result.map(i64, struct {
    fn f(x: i32) i64 { return @as(i64, x) * 2; }
}.f);
// mapped = Ok(84)
```

### Validation - 累积错误

```zig
const v1 = Validation(i32, []const u8).valid(10);
const v2 = Validation(i32, []const u8).invalid(&.{"error1"});
// 可以累积多个错误
```
