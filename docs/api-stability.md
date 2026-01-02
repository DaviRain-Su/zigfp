# zigFP API 稳定性指南

> 本文档描述 zigFP v1.0.0 的 API 稳定性保证和语义版本控制策略

## 版本控制

zigFP 遵循[语义版本控制 (SemVer)](https://semver.org/) 规范：

- **主版本号** (MAJOR): 不兼容的 API 变更
- **次版本号** (MINOR): 向后兼容的功能添加
- **修订号** (PATCH): 向后兼容的问题修复

## API 稳定性级别

### 稳定 API (Stable)

以下模块和类型在 v1.0.0 中被视为**稳定**，遵循 SemVer 保证：

#### 核心类型

| 模块 | 类型 | 稳定性 |
|------|------|--------|
| `option.zig` | `Option(T)` | 稳定 |
| `result.zig` | `Result(T, E)` | 稳定 |
| `lazy.zig` | `Lazy(T)` | 稳定 |

#### 函数工具

| 模块 | 函数/类型 | 稳定性 |
|------|----------|--------|
| `function.zig` | `compose`, `identity`, `flip`, `apply` | 稳定 |
| `pipe.zig` | `Pipe(T)`, `pipe` | 稳定 |

#### Monad 家族

| 模块 | 类型 | 稳定性 |
|------|------|--------|
| `reader.zig` | `Reader(Env, T)` | 稳定 |
| `writer.zig` | `Writer(W, T)` | 稳定 |
| `state.zig` | `State(S, T)` | 稳定 |

#### 高级抽象

| 模块 | 类型 | 稳定性 |
|------|------|--------|
| `lens.zig` | `Lens(S, A)` | 稳定 |
| `memoize.zig` | `Memoized(K, V)` | 稳定 |
| `monoid.zig` | `Monoid(T)` | 稳定 |
| `io.zig` | `IO(T)` | 稳定 |

#### 代数结构

| 模块 | 类型 | 稳定性 |
|------|------|--------|
| `semigroup.zig` | `Semigroup(T)` | 稳定 |
| `functor.zig` | Functor 工具 | 稳定 |
| `applicative.zig` | Applicative 工具 | 稳定 |
| `foldable.zig` | Foldable 工具 | 稳定 |
| `traversable.zig` | Traversable 工具 | 稳定 |

### 实验性 API (Experimental)

以下模块可能在未来版本中发生变化：

| 模块 | 说明 | 稳定性 |
|------|------|--------|
| `parallel.zig` | 并行计算（接口预留） | 实验性 |
| `http.zig` | HTTP 客户端 | 实验性 |
| `benchmark.zig` | 性能基准测试 | 实验性 |

### 内部 API (Internal)

以非 `pub` 标记的函数和类型被视为内部实现，不受稳定性保证。

## 废弃策略

当需要废弃 API 时，我们遵循以下流程：

1. **标记废弃**: 在文档和代码注释中标记为 `@deprecated`
2. **提供替代方案**: 文档化推荐的替代 API
3. **过渡期**: 至少保留一个次版本
4. **移除**: 在下一个主版本中移除

示例：
```zig
/// @deprecated 请使用 `newFunction` 替代
/// 将在 v2.0.0 中移除
pub fn oldFunction() void { ... }
```

## 兼容性矩阵

| zigFP 版本 | Zig 版本 | 状态 |
|------------|----------|------|
| v1.0.x | 0.15.x | 支持 |
| v1.0.x | 0.14.x | 不支持 |
| v1.0.x | 0.16.x | 待测试 |

## 破坏性变更指南

如果您遇到升级问题，请参考以下资源：

1. [CHANGELOG.md](../CHANGELOG.md) - 版本变更记录
2. [迁移指南](./migration.md) - 版本迁移说明（如有）
3. [GitHub Issues](https://github.com/your-repo/zigfp/issues) - 问题反馈

## API 设计原则

zigFP 的 API 设计遵循以下原则：

### 1. 类型安全

```zig
// 所有操作都是类型安全的
const opt = Option(i32).Some(42);
const doubled = opt.map(i32, double); // 编译时类型检查
```

### 2. 零成本抽象

```zig
// 所有抽象在编译时展开，无运行时开销
const composed = compose(i32, i32, i32, double, addOne);
// 等价于直接调用: double(addOne(x))
```

### 3. 明确的错误处理

```zig
// 错误永远不会被静默忽略
const result = try operation();
// 或显式处理
const result = operation() catch |err| handleError(err);
```

### 4. 一致的命名

- 类型名: `PascalCase` (如 `Option`, `Result`)
- 函数名: `camelCase` (如 `flatMap`, `unwrapOr`)
- 常量: `snake_case` 或 `SCREAMING_SNAKE_CASE`

## 报告问题

如果您发现 API 不一致或建议改进，请通过以下方式反馈：

1. 在 GitHub 上提交 Issue
2. 提交 Pull Request

感谢您使用 zigFP！
