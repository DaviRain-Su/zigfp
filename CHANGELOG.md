# zigFP - 函数式编程工具库更新日志

## [v1.5.0] - 2026-01-02 - 真正并行计算 ✅

### 🎯 新增功能

#### 真正的线程池 (`parallel.zig`)
实现了基于 Zig 原生线程的真正并行计算：

- `RealThreadPool` - 真正的多线程池
  - 支持固定大小线程池
  - 工作提交和等待机制
  - 线程安全的任务队列
  - 优雅关闭支持
- `realParMap` - 真正并行的 map 操作
  - 自动分割工作到多个线程
  - 线程安全的结果收集
- `realParFilter` - 真正并行的 filter 操作
  - 并行执行过滤逻辑
  - 合并结果
- `realParReduce` - 真正并行的 reduce 操作
  - 分块并行计算
  - 合并部分结果

#### 使用示例

```zig
const pool = try RealThreadPool.init(allocator, .{ .num_threads = 4 });
defer pool.deinit();

// 并行 map
const doubled = try realParMap(i32, i32, allocator, &nums, double, pool);

// 并行 filter
const evens = try realParFilter(i32, allocator, &nums, isEven, pool);

// 并行 reduce
const sum = try realParReduce(i32, allocator, &nums, 0, add, pool);
```

### 📊 统计数据
- **总测试数**: 742个（从 737 增加，全部通过）
- **新增测试**: 5个并行计算测试
- **无内存泄漏**

### 🔧 其他改进
- 更新过时的 Story 文件（标记已实现的功能）
- 更新 ROADMAP.md 添加 v1.5.0 规划

---

## [v1.4.1] - 2026-01-02 - 遗留任务修复 ✅

### 🎯 修复内容

#### Monad Transformer hoist 实现 (mtl.zig)
完成了 v0.7.0 遗留的 `hoist` 函数实现：

- `hoist.optionT` - 转换 OptionT 的底层 Monad
- `hoist.eitherT` - 转换 EitherT 的底层 Monad
- `hoist.writerT` - 转换 WriterT 的底层 Monad
- `hoist.readerT` - 转换 ReaderT 的底层 Monad
- `hoist.stateT` - 转换 StateT 的底层 Monad

`hoist` 允许在相同 Transformer 类型间转换基础 Monad，通过自然变换实现。
这对于在不同效果层之间转换非常有用。

#### Story 文件同步
- 更新 `v0.7.0-monad-composition.md` - 标记 hoist 为已完成
- 更新 `v0.8.0-effect-system-extension.md` - 标记网络效果为已完成（v1.2.0 实现）

### 📊 统计数据
- **总测试数**: 737个（从 734 增加，全部通过）
- **新增测试**: 3个 hoist 测试
- **无内存泄漏**

---

## [v1.4.0] - 2026-01-02 - 项目结构重组 ✅

### 🎯 主要变更

#### 源代码模块化重组
将 60+ 扁平源文件重组为 13 个模块化子目录，提升代码组织性和可维护性：

| 模块 | 路径 | 内容 |
|------|------|------|
| `core` | `src/core/` | option, result, lazy, validation |
| `monad` | `src/monad/` | reader, writer, state, cont, free, mtl, selective |
| `functor` | `src/functor/` | functor, applicative, bifunctor, profunctor, distributive |
| `algebra` | `src/algebra/` | semigroup, monoid, alternative, foldable, traversable, category |
| `data` | `src/data/` | stream, zipper, iterator, arrow, comonad |
| `function` | `src/function/` | function, pipe, memoize |
| `effect` | `src/effect/` | effect, io, file_system, random, time, config |
| `parser` | `src/parser/` | parser, json, codec |
| `network` | `src/network/` | tcp, udp, websocket, http, connection_pool, network |
| `resilience` | `src/resilience/` | retry, circuit_breaker, bulkhead, timeout, fallback |
| `concurrent` | `src/concurrent/` | parallel, benchmark |
| `util` | `src/util/` | auth, i18n, schema |
| `optics` | `src/optics/` | lens, optics |

#### 模块入口文件
- 每个子目录创建 `mod.zig` 作为模块入口
- 统一的导入和导出模式
- 包含 `test { std.testing.refAllDecls(@This()); }` 确保测试覆盖

#### 跨模块导入修复
修复 16 个文件的跨模块导入路径：
- `algebra/` - alternative, traversable, category
- `functor/` - functor, profunctor, distributive
- `monad/` - writer, selective, mtl
- `data/` - stream, zipper, iterator
- `optics/optics.zig`
- `network/http.zig`
- `util/schema.zig`
- `concurrent/benchmark.zig`

#### 入口文件更新
- `src/root.zig` - 重写为模块化导入，聚合所有子模块
- `src/prelude.zig` - 更新导入路径
- 添加缺失的 API 导出：
  - `sumMonoid`, `productMonoid` (Monoid)
  - `ask`, `asks` (Reader Monad)
  - `tell` (Writer Monad)
  - `get`, `modify` (State Monad)

#### 文档结构重组
`docs/` 目录镜像 `src/` 结构：
- 创建 13 个模块子目录
- 每个目录包含 `README.md` 和对应的 API 文档
- 移动现有 `.md` 文件到对应子目录

#### CI/CD 更新
- `examples/prelude_example.zig` - 修复为使用 `@import("zigfp")`
- `build.zig` - 添加 `example-prelude` 构建目标
- `.github/workflows/ci.yml` - 添加 prelude example 构建步骤

### 📊 统计数据
- **总测试数**: 734个（全部通过）
- **模块数**: 13个子目录
- **mod.zig 文件**: 13个
- **修复的导入**: 16个文件
- **无内存泄漏**

### 🔧 技术说明
- **Zig 版本**: 0.15.2
- **导入模式**: 子目录使用 `../` 相对路径进行跨模块导入
- **模块模式**: 每个 `mod.zig` 导入子模块并重新导出公共类型
- **测试模式**: 每个 `mod.zig` 包含 `refAllDecls` 测试

---

## [v1.3.0] - 2026-01-02 - 弹性模式 ✅

### 🎯 新增功能

#### 重试策略 (`retry.zig`)
- `RetryPolicy` - 重试策略配置
  - 固定间隔重试 (fixedDelay)
  - 指数退避重试 (exponentialBackoff)
  - 带抖动的指数退避 (exponentialBackoffWithJitter)
  - 线性退避 (linearBackoff)
  - 立即重试 (immediate)
- `Retrier` - 重试执行器
- `RetryStats` - 重试统计信息
- `RetryPolicyBuilder` - 流畅 API 构建器

#### 断路器 (`circuit_breaker.zig`)
- `CircuitBreaker` - 断路器状态机
  - 三种状态：Closed（正常）、Open（熔断）、HalfOpen（恢复测试）
  - 故障计数和阈值配置
  - 自动恢复机制（超时后进入半开状态）
  - 状态变更回调
- `CircuitStats` - 统计信息（成功率、失败率）
- `CircuitBreakerBuilder` - 流畅 API 构建器

#### 隔板模式 (`bulkhead.zig`)
- `Bulkhead` - 并发隔离
  - 最大并发数限制
  - 等待队列支持
  - 拒绝策略（快速失败/等待）
- `Semaphore` - 信号量（简化并发控制）
- `BulkheadStats` - 资源使用统计
- `BulkheadBuilder` - 流畅 API 构建器

#### 超时控制 (`timeout.zig`)
- `Timeout` - 超时配置和执行
  - 毫秒/秒级超时设置
  - 执行时间统计
- `Deadline` - 截止时间抽象
  - 绝对时间计算
  - 剩余时间查询
- `TimeoutStats` - 统计信息
- `TimeoutBuilder` - 流畅 API 构建器

#### 降级策略 (`fallback.zig`)
- `Fallback` - 降级执行器
  - 默认值降级
  - 备用操作降级
- `CacheFallback` - 缓存降级（使用缓存值作为后备）
- `FallbackChain` - 链式降级支持
- 便捷函数：`withFallbackValue`、`withFallbackFn`、`tryOrNull`

### 📊 统计数据
- **总测试数**: 721个（从 647 增加，全部通过）
- **新增模块**: 5个
- **新增测试**: 74个
- **无内存泄漏**

---

## [v1.2.0] - 2026-01-02 - 网络效果 ✅

### 🎯 新增功能

#### TCP 客户端 (`tcp.zig`)
- `TcpClient` - TCP 连接管理
  - 连接/断开控制
  - 数据发送/接收
  - 统计信息（字节发送/接收）
- `TcpConfig` - 配置选项
  - 连接/读取/写入超时
  - TCP_NODELAY 和 Keep-Alive 选项
  - 接收缓冲区大小
- `TcpClientBuilder` - 流畅 API 构建器

#### UDP 客户端 (`udp.zig`)
- `UdpSocket` - UDP 套接字管理
  - 绑定本地地址
  - 发送/接收数据报
  - 广播支持
- `UdpConfig` - 配置选项
  - 读取/写入超时
  - 广播和地址重用选项
  - 接收缓冲区大小
- `UdpSocketBuilder` - 流畅 API 构建器

#### 网络效果系统 (`network.zig`)
- `NetworkOp` - 网络操作类型
  - TCP: connect, send, receive, disconnect
  - UDP: bind, send, receive
  - DNS: resolve
- `NetworkEffect` - 网络效果包装
- `NetworkResult` - 操作结果类型
- `NetworkHandler` - 效果处理器
  - 管理 TCP 连接和 UDP 套接字
  - 自动资源清理
- `NetworkSequence` - 可组合效果序列

#### WebSocket 客户端 (`websocket.zig`)
- `WebSocketClient` - WebSocket 连接管理
  - 连接/关闭控制
  - 文本/二进制消息发送
  - 消息接收
  - Ping/Pong 心跳
- `WebSocketConfig` - 配置选项
  - 超时设置
  - 最大帧/消息大小
  - 自动 Pong 响应
- `Frame` - WebSocket 帧编解码
- `Message` - 消息抽象
- `CloseCode` - 标准关闭状态码
- `WebSocketClientBuilder` - 流畅 API 构建器

### 📊 统计数据
- **总测试数**: 647个（从 609 增加，全部通过）
- **新增模块**: 4个
- **新增测试**: 38个
- **无内存泄漏**

---

## [v1.1.0] - 2026-01-02 - 增强功能 ✅

### 🎯 新增功能

#### HTTP 连接池 (`connection_pool.zig`)
- `ConnectionPool` - 连接池管理
  - 连接复用，避免重复建立 TCP 连接
  - 按主机分组管理连接
  - 自动清理过期连接
- `ConnectionPoolBuilder` - 流畅 API 构建器
- 支持配置最大连接数、空闲超时时间等

#### 认证支持 (`auth.zig`)
- `BasicAuth` - HTTP 基本认证（Base64 编码）
- `BearerToken` - Bearer Token 认证（OAuth2/JWT）
- `ApiKey` - API Key 认证（Header 或 Query 参数）
- `CustomAuth` - 自定义认证头
- `AuthMiddleware` - 认证中间件
- `AuthBuilder` - 流畅 API 构建器

#### 国际化支持 (`i18n.zig`)
- `Locale` - 语言区域设置（支持中/英/日/韩/法/德/西/俄）
- `MessageBundle` - 多语言消息包
- `LocaleContext` - 本地化上下文
- `BuiltinMessages` - 内置中英文错误消息
- `formatMessage` - 参数化消息格式化（{0}, {1}, ...）

#### JSON Schema 验证 (`schema.zig`)
- `Schema` - Schema 定义类型
  - 类型验证（string, number, integer, boolean, array, object, null）
  - 字符串约束（minLength, maxLength, pattern）
  - 数值约束（min, max, exclusiveMin, exclusiveMax）
  - 数组约束（minItems, maxItems, items schema）
  - 对象约束（required fields, properties）
  - 枚举值验证
  - 可空类型支持
- `SchemaBuilder` - 对象 Schema 构建器
- `ValidationResult` - 验证结果（包含错误路径和消息）

#### CI/CD 配置
- GitHub Actions 工作流 (`.github/workflows/ci.yml`)
  - 多平台测试（Linux, macOS, Windows）
  - 代码格式检查
  - 示例构建验证
  - 文档检查

### 📊 统计数据
- **总测试数**: 609个（从 568 增加，全部通过）
- **新增模块**: 4个
- **无内存泄漏**

---

## [v1.0.0] - 2026-01-02 - 稳定版本 ✅

### 🎯 主要变更

#### API 稳定化
- 添加 `prelude.zig` 导出 - 函数式编程常用函数和类型别名
  - `Maybe` (Option别名), `Either` (Result别名), `Unit`
  - `preludeId`, `preludeCompose2`, `when`, `unless`
  - 便捷构造函数: `preludeSome`, `preludeNone`, `preludeOk`, `preludeErr`
- 添加 `category.zig` 导出 - 范畴论基础
  - `function_category` - 函数范畴操作
  - `kleisli` - Kleisli范畴（基于Option Monad）
  - `covariant` - 协变函子示例
  - `category_laws` - 范畴法则验证工具

#### 文档完善
- 创建 `docs/api-stability.md` - API稳定性指南
- 创建 `docs/guide.md` - 用户指南

#### 示例代码
- 创建 `examples/` 目录
- `examples/basic_usage.zig` - 基础用法示例
- `examples/monad_usage.zig` - Monad使用示例  
- `examples/validation_example.zig` - 验证模式示例
- 更新 `build.zig` 添加示例构建步骤

#### 社区与生态系统
- 创建 `CONTRIBUTING.md` - 贡献指南
- 创建 `CODE_OF_CONDUCT.md` - 行为准则
- 创建 `.github/ISSUE_TEMPLATE/` - Issue 模板
  - `bug_report.md` - Bug 报告模板
  - `feature_request.md` - 功能请求模板
  - `question.md` - 问题咨询模板
- 创建 `.github/PULL_REQUEST_TEMPLATE.md` - PR 模板

### 🔧 技术改进
- 修复 `category.zig` 中 Zig 0.15 闭包限制问题
- 修复 `category.zig` 测试以反映实际API行为
- 所有示例使用 `std.debug.print` (Zig 0.15 兼容)

### 📊 统计数据
- **总测试数**: 568个（全部通过）
- **无内存泄漏**

### 🚀 实验性 API
以下模块标记为实验性，可能在未来版本中变更：
- `parallel.zig` - 并行计算抽象
- `http.zig` - HTTP客户端
- `benchmark.zig` - 性能基准测试

---

## [v0.9.0] - 2026-01-02 - 实用工具与集成 ✅

### 🎯 新增功能

#### JSON 处理模块 (`src/json.zig`)
- 实现类型安全的 JSON 值类型 `JsonValue`
- 提供 `parseJson` 函数进行 JSON 字符串解析
- 提供 `stringifyJson` 函数进行 JSON 值序列化
- 实现 `JsonPath` 模块，支持点分隔路径的函数式 JSON 访问
- 提供构造函数：`createNull`、`createBool`、`createInt`、`createFloat`、`createString`、`createArray`、`createObject`
- 实现函数式操作：`mapJson`、`filterJson`、`foldJson`
- **新增**: `transformJson` - 递归JSON结构变换
- **新增**: `JsonPipeline` - 函数式组合管道
- **新增**: `mergeJson` - 合并两个JSON对象
- **新增**: `pluckJson` - 从对象数组中提取指定字段
- **新增**: `groupByJson` - 按字段值分组数组元素
- 完整的错误处理和内存管理

#### HTTP 客户端模块 (`src/http.zig`)
- 实现类型安全的 HTTP 请求/响应类型 `HttpRequest`、`HttpResponse`
- 提供 `HttpClient` 类用于发送 HTTP 请求
- 支持所有标准 HTTP 方法（GET、POST、PUT、DELETE等）
- 实现请求构建器模式，支持链式添加请求头
- 提供便捷函数：`get()`、`post()`、`postJson()`
- **新增**: `HttpEffect` - HTTP效果类型，集成到效果系统
- **新增**: `RetryConfig` - 可配置的重试策略（指数退避）
- **新增**: `RetryableHttpClient` - 带自动重试的HTTP客户端
- **新增**: `RequestBuilder` - 流畅API构建请求
- **新增**: `MiddlewareChain` - 请求/响应中间件链
- **新增**: `parseJsonResponse` - JSON响应解析工具
- 完整的错误处理和内存管理
- 基于 Zig 0.15 HTTP API 实现（修复iterateHeaders兼容性）

#### 编解码器框架模块 (`src/codec.zig`)
- 实现 `JsonEncoder`/`JsonDecoder` 用于 JSON 序列化/反序列化
- 实现 `BinaryEncoder`/`BinaryDecoder` 用于二进制序列化/反序列化
- 支持基本类型：布尔值、整数、浮点数、结构体
- 提供便捷函数：`encodeJson()`、`decodeJson()`、`encodeBinary()`、`decodeBinary()`
- **新增**: `Codec(T)` - 泛型编解码器接口，支持compose/contramap/bimap
- **新增**: `CustomCodec` - 自定义编解码器构建器
- **新增**: `Base64Codec` - Base64编解码
- **新增**: `HexCodec` - 十六进制编解码
- 类型安全的设计，支持编译时类型检查

#### 数据验证框架模块 (`src/validation.zig`)
- 实现 `Validation(T, E)` Either类型用于验证结果
- 实现泛型验证器类型 `Validator(T, E)`
- 提供 `valid()`/`invalid()` 构造函数
- **新增**: `StringValidators` - notEmpty, minLength, maxLength, lengthBetween, contains, startsWith, endsWith, isAlphanumeric, isNumeric, isEmail
- **新增**: `NumberValidators` - min, max, inRange, positive, nonNegative
- **新增**: `GenericValidators` - required, oneOf, equals, custom
- **新增**: `Combinators` - andThen, orElse, not, all, any
- **新增**: `ValidationPipeline` - 链式验证管道
- 错误累积和内存安全设计

### 📊 统计数据
- **新增测试**: 32个
- **总测试数**: 551个（全部通过）
- **内存安全**: 无泄漏检测

### 🔧 技术改进
- 修复 Zig 0.15.x HTTP API 兼容性问题 (`response.head.iterateHeaders()`)
- 确保无内存泄漏的测试验证
- 遵循文档驱动开发流程

## [v0.6.0] - 2026-01-02 - 代数结构基础

### 🎯 新增功能

#### Semigroup 模块 (`src/semigroup.zig`)
- 实现 Semigroup 类型类，提供结合操作
- 支持数值、字符串、数组、函数等类型的结合
- 提供 `combine`、`concat`、`repeat`、`intersperse`、`foldLeft`、`foldRight` 等操作
- 10个测试用例，验证结合律

#### Functor 模块 (`src/functor.zig`)
- 实现 Functor 工具集合，提供映射操作
- 支持 Option、Identity 类型的映射
- 提供 `map`、`as`、`replace`、`voidMap` 等操作
- 5个测试用例，验证恒等律和组合律

#### Alternative 模块 (`src/alternative.zig`)
- 实现 Alternative 工具集合，提供选择和重复操作
- 支持 Option 类型的选择操作
- 提供 `empty`、`orOp`、`many`、`some`、`optional` 等操作
- 6个测试用例

### 📊 统计数据
- **新增模块**: 3个
- **新增测试**: 21个
- **总测试数**: 457个（全部通过）
- **内存安全**: 无泄漏检测

### 🔧 技术改进
- 完善了代数结构层次：Semigroup → Monoid → Functor → Applicative → Monad
- 所有实现都经过数学法则验证
- 保持零成本抽象和高性能

### 📝 文档更新
- 更新 ROADMAP.md 标记 v0.6.0 完成状态
- 更新 v0.6.0 Story 文件记录实现详情
- 完善各模块的API文档

---

## [v0.5.0] - 2026-01-02 - Advanced Abstractions

### 🎯 新增功能

#### Bifunctor 模块 (`src/bifunctor.zig`)
- 实现 Bifunctor 类型，支持双参数映射
- `Pair(A, B)` - 积类型
- `Either(A, B)` - 和类型
- `ResultBifunctor(T, E)` - 错误处理
- `These(A, B)` - 包容性或类型
- 23个测试用例

#### Profunctor 模块 (`src/profunctor.zig`)
- 实现 Profunctor 类型类，输入逆变输出协变
- `FunctionProfunctor` - 函数作为 Profunctor
- `Star(F, A, B)` - Kleisli Profunctor
- `Costar(F, A, B)` - Co-Kleisli Profunctor
- `StrongProfunctor` - 积类型支持
- `ChoiceProfunctor` - 和类型支持
- 23个测试用例

#### Optics 模块 (`src/optics.zig`)
- 实现经典的 Optics 组合子
- `Iso(S, A)` - 双向无损转换
- `Lens(S, A)` - 单焦点访问
- `Prism(S, A)` - 部分同构
- `Affine(S, A)` - 可选焦点
- `Getter(S, A)` - 只读访问
- `Setter(S, A)` - 只写访问
- `Fold(S, A)` - 多焦点只读
- 22个测试用例

#### Stream 模块 (`src/stream.zig`)
- 实现惰性无限流
- `iterate` - 步进生成
- `repeat` / `cycle` - 重复模式
- `unfold` - 展开生成
- `take` / `drop` - 截取操作
- `map` / `filter` / `zipWith` - 转换操作
- `foldN` / `allN` / `anyN` / `findN` - 有限流操作
- 19个测试用例

#### Zipper 模块 (`src/zipper.zig`)
- 实现高效的局部更新数据结构
- `ListZipper(T)` - 列表导航和修改
- `BinaryTree(T)` - 二叉树
- `TreeZipper(T)` - 树导航（简化版）
- 移动、插入、删除、修改操作
- 15个测试用例

### 📊 统计数据
- **新增模块**: 5个
- **新增测试**: 102个
- **总测试数**: 436个（全部通过）

---

## [v0.4.0] - 2026-01-01 - 类型类抽象

- Applicative Functor (Option, Result, List)
- Foldable (Slice, Option)
- Traversable (Slice, Option)
- Arrow (Function, Composed, First, Second)
- Comonad (Identity, NonEmpty, Store, Env, Traced)

---

## [v0.3.0] - 2026-01-01 - 高级抽象

- Continuation Monad (CPS, Trampoline)
- Effect System (Reader, State, Error, Log)
- Parser Combinators

---

## [v0.2.0] - 2026-01-01 - 扩展

- Iterator (map, filter, fold, take, skip, zip)
- Validation (Applicative-style error accumulation)
- Free Monad + Trampoline

---

## [v0.1.0] - 2026-01-01 - 完整函数式工具库

- 核心类型: Option, Result, Lazy
- 函数工具: compose, pipe, partial
- Monad: Reader, Writer, State
- 高级抽象: Lens, Memoize, Monoid, IO