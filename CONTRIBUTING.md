# 贡献指南

感谢你对 zigFP 的兴趣！我们欢迎各种形式的贡献。

## 如何贡献

### 报告问题

如果你发现了 bug 或有功能建议：

1. 先搜索现有的 [Issues](https://github.com/DaviRain-Su/zigfp/issues) 确保没有重复
2. 创建新 Issue，使用对应的模板
3. 提供详细的描述和复现步骤

### 提交代码

1. **Fork 仓库**

```bash
git clone https://github.com/your-username/zigfp.git
cd zigfp
```

2. **创建分支**

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

3. **开发**

- 遵循项目的代码风格（见下文）
- 添加对应的测试
- 确保所有测试通过

```bash
zig build test
```

4. **提交**

```bash
git add .
git commit -m "feat: add new feature"
# 或
git commit -m "fix: fix bug description"
```

5. **推送并创建 PR**

```bash
git push origin feature/your-feature-name
```

然后在 GitHub 上创建 Pull Request。

## 代码风格

### 命名约定

```zig
// 类型名: PascalCase
const MyStruct = struct {};

// 函数和变量: camelCase
fn processData() void {}
var itemCount: u32 = 0;

// 常量: snake_case 或 SCREAMING_SNAKE_CASE
const max_size = 1024;
const DEFAULT_TIMEOUT: u64 = 30000;
```

### 文档注释

所有公共 API 必须有文档注释：

```zig
/// 将两个值相加
///
/// 示例:
/// ```zig
/// const result = add(1, 2);  // 3
/// ```
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

### 导入顺序

```zig
const std = @import("std");

// 先标准库，再项目模块
const option = @import("option.zig");
const result = @import("result.zig");
```

## 测试要求

- **所有新功能必须有测试**
- **测试必须通过**: `zig build test`
- **无内存泄漏**: 使用 `std.testing.allocator`
- **覆盖正常路径和错误路径**

测试示例：

```zig
test "Option.map transforms value" {
    const opt = Option(i32).some(5);
    const mapped = opt.map(i32, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    try std.testing.expectEqual(@as(i32, 10), mapped.unwrap());
}
```

## 提交信息格式

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**类型**:

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构（不添加功能或修复 bug） |
| `test` | 测试相关 |
| `chore` | 构建/工具相关 |

**示例**:

```
feat(option): add Option.filter method

Add a filter method that returns None if the predicate fails.

Closes #42
```

## PR 要求

- 标题清晰描述更改
- 描述中说明更改的原因和内容
- 关联相关 Issue
- 所有测试通过
- 代码风格符合规范

## 开发环境

### 要求

- Zig 0.15.x 或更高版本

### 常用命令

```bash
# 构建
zig build

# 运行测试
zig build test

# 运行单个文件测试
zig test src/option.zig

# 运行示例
zig build example-basic
zig build example-monad
zig build example-validation
```

## 项目结构

```
zigfp/
├── src/
│   ├── root.zig      # 库入口点
│   ├── option.zig    # Option 类型
│   ├── result.zig    # Result 类型
│   └── ...           # 其他模块
├── docs/             # 文档
├── examples/         # 示例代码
├── stories/          # 版本 Story 文件
├── build.zig         # 构建配置
├── ROADMAP.md        # 项目路线图
└── CHANGELOG.md      # 变更日志
```

## 获取帮助

- 查看 [文档](docs/)
- 查看 [示例](examples/)
- 创建 Issue 提问

## 行为准则

参与本项目即表示你同意遵守我们的 [行为准则](CODE_OF_CONDUCT.md)。

---

再次感谢你的贡献！
