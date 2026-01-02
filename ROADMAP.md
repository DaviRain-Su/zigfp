# zigFP - Zig 函数式编程工具库

> 将函数式语言的核心特性带入 Zig，用函数式风格写高性能代码

## 项目愿景

通过在 Zig 中实现函数式编程的经典抽象，探索 Zig 编译时计算和类型系统的强大能力，
同时保持 Zig 的零成本抽象和高性能特性。

## 核心特性

- **类型安全**: 利用 Zig 类型系统防止运行时错误
- **零成本抽象**: 编译时展开，无运行时开销
- **Monad 支持**: Option, Result, Reader, Writer, State
- **函数组合**: compose, pipe, partial application
- **不可变更新**: Lens
- **惰性求值**: Lazy
- **记忆化**: Memoize

## 项目结构 (v1.4.0+ 模块化结构)

```
src/
├── root.zig              # 库主入口，统一导出所有模块
├── prelude.zig           # Prelude - 常用函数和类型别名
├── main.zig              # CLI 入口
│
├── core/                 # 核心数据类型
│   ├── mod.zig          # 模块入口
│   ├── option.zig       # Option - 安全空值处理
│   ├── result.zig       # Result - 错误处理
│   ├── lazy.zig         # Lazy - 惰性求值
│   └── validation.zig   # Validation - 累积错误验证
│
├── monad/               # Monad 类型
│   ├── mod.zig          # 模块入口
│   ├── reader.zig       # Reader - 依赖注入
│   ├── writer.zig       # Writer - 日志累积
│   ├── state.zig        # State - 状态管理
│   ├── cont.zig         # Continuation - CPS 风格
│   ├── free.zig         # Free Monad + Trampoline
│   ├── mtl.zig          # Monad Transformers
│   └── selective.zig    # Selective Applicative
│
├── functor/             # Functor 抽象
│   ├── mod.zig          # 模块入口
│   ├── functor.zig      # Functor 基础
│   ├── applicative.zig  # Applicative Functor
│   ├── bifunctor.zig    # Bifunctor
│   ├── profunctor.zig   # Profunctor
│   └── distributive.zig # Distributive Laws
│
├── algebra/             # 代数结构
│   ├── mod.zig          # 模块入口
│   ├── semigroup.zig    # Semigroup
│   ├── monoid.zig       # Monoid
│   ├── alternative.zig  # Alternative
│   ├── foldable.zig     # Foldable
│   ├── traversable.zig  # Traversable
│   └── category.zig     # Category Theory
│
├── data/                # 数据结构
│   ├── mod.zig          # 模块入口
│   ├── stream.zig       # Stream - 惰性流
│   ├── zipper.zig       # Zipper - 可导航结构
│   ├── iterator.zig     # Iterator
│   ├── arrow.zig        # Arrow
│   └── comonad.zig      # Comonad
│
├── function/            # 函数工具
│   ├── mod.zig          # 模块入口
│   ├── function.zig     # compose, identity, flip
│   ├── pipe.zig         # Pipe 管道
│   └── memoize.zig      # Memoize 记忆化
│
├── effect/              # 效果系统
│   ├── mod.zig          # 模块入口
│   ├── effect.zig       # Effect 基础
│   ├── io.zig           # IO 效果
│   ├── file_system.zig  # FileSystem 效果
│   ├── random.zig       # Random 效果
│   ├── time.zig         # Time 效果
│   └── config.zig       # Config 效果
│
├── parser/              # 解析器
│   ├── mod.zig          # 模块入口
│   ├── parser.zig       # Parser Combinators
│   ├── json.zig         # JSON 处理
│   └── codec.zig        # 编解码器
│
├── network/             # 网络模块
│   ├── mod.zig          # 模块入口
│   ├── tcp.zig          # TCP 客户端
│   ├── udp.zig          # UDP 客户端
│   ├── websocket.zig    # WebSocket 客户端
│   ├── http.zig         # HTTP 客户端
│   ├── connection_pool.zig  # 连接池
│   └── network.zig      # 网络效果
│
├── resilience/          # 弹性模式
│   ├── mod.zig          # 模块入口
│   ├── retry.zig        # 重试策略
│   ├── circuit_breaker.zig  # 断路器
│   ├── bulkhead.zig     # 隔板模式
│   ├── timeout.zig      # 超时控制
│   └── fallback.zig     # 降级策略
│
├── concurrent/          # 并发模块
│   ├── mod.zig          # 模块入口
│   ├── parallel.zig     # 并行计算
│   └── benchmark.zig    # 性能基准
│
├── util/                # 工具模块
│   ├── mod.zig          # 模块入口
│   ├── auth.zig         # HTTP 认证
│   ├── i18n.zig         # 国际化
│   └── schema.zig       # JSON Schema
│
└── optics/              # 光学模块
    ├── mod.zig          # 模块入口
    ├── lens.zig         # Lens
    └── optics.zig       # Iso, Prism, Affine
```

## 版本路线图

### v0.1.0 - 完整函数式工具库 ✅

#### 核心数据类型

| 模块 | 状态 | 说明 |
|------|------|------|
| `option.zig` | ✅ | Option(T) - Maybe 语义，安全空值处理 |
| `result.zig` | ✅ | Result(T, E) - 错误处理，ok/err 语义 |
| `lazy.zig` | ✅ | Lazy(T) - 惰性求值，记忆化 |

#### 函数工具

| 模块 | 状态 | 说明 |
|------|------|------|
| `function.zig` | ✅ | compose, identity, flip, partial |
| `pipe.zig` | ✅ | Pipe(T) - 管道操作，链式调用 |

#### Monad 家族

| 模块 | 状态 | 说明 |
|------|------|------|
| `reader.zig` | ✅ | Reader(Env, T) - 依赖注入模式 |
| `writer.zig` | ✅ | Writer(W, T) - 日志/累积模式 |
| `state.zig` | ✅ | State(S, T) - 状态管理 |

#### 高级抽象

| 模块 | 状态 | 说明 |
|------|------|------|
| `lens.zig` | ✅ | Lens(S, A) - 不可变数据更新 |
| `memoize.zig` | ✅ | Memoized(K, V) - 函数记忆化 |
| `monoid.zig` | ✅ | Monoid(T) - 可组合代数结构 |
| `io.zig` | ✅ | IO(T) - 函数式 IO 操作 |

#### 基础设施

| 任务 | 状态 | 说明 |
|------|------|------|
| 单元测试 | ✅ | 每个模块完整测试 |
| Functor/Monad 法则测试 | ✅ | Option, Result 法则验证 |
| Lens 法则测试 | ✅ | GetPut, PutGet, PutPut |
| Monoid 法则测试 | ✅ | Identity, Associativity |
| 文档 | ✅ | 每个模块 API 文档 |
| README | ✅ | 用户入口文档 |

### v0.2.0 - 扩展 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `iterator.zig` | ✅ | 增强迭代器 - map, filter, fold, take, skip, zip |
| `validation.zig` | ✅ | Validation - 累积错误验证 |
| `free.zig` | ✅ | Free Monad + Trampoline（栈安全递归） |

### v0.3.0 - 高级抽象 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `cont.zig` | ✅ | Continuation Monad - CPS 风格、Trampoline |
| `effect.zig` | ✅ | Effect System - 代数效果、Reader/State/Error/Log |
| `parser.zig` | ✅ | Parser Combinators - 组合式解析器 |

### v0.4.0 - 类型类抽象 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `applicative.zig` | ✅ | Applicative Functor - Option/Result/List |
| `foldable.zig` | ✅ | Foldable - 折叠操作 |
| `traversable.zig` | ✅ | Traversable - 效果遍历 |
| `arrow.zig` | ✅ | Arrow - 函数抽象 |
| `comonad.zig` | ✅ | Comonad - Identity/NonEmpty/Store/Env/Traced |

### v0.5.0 - Advanced Abstractions ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `bifunctor.zig` | ✅ | Bifunctor - 双参数 Functor (Pair/Either/Result/These) |
| `profunctor.zig` | ✅ | Profunctor - 逆变/协变 (Function/Star/Costar/Strong/Choice) |
| `optics.zig` | ✅ | Optics - Prism/Iso/Affine/Getter/Setter/Fold |
| `stream.zig` | ✅ | Stream - 惰性流 / 无限序列 (iterate/repeat/cycle/unfold) |
| `zipper.zig` | ✅ | Zipper - 可导航数据结构 (ListZipper/TreeZipper) |

### v0.6.0 - 代数结构基础 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `semigroup.zig` | ✅ | Semigroup - 半群，Monoid 的基础 |
| `functor.zig` | ✅ | Functor - 可映射的类型构造器 |
| `alternative.zig` | ✅ | Alternative - 选择和重复操作 |

### v0.7.0 - Monad 组合与实用工具 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `prelude.zig` | ✅ | Prelude - 常用函数、类型别名和运算符重载 |
| `category.zig` | ✅ | Category Theory - 函数范畴、Kleisli范畴 |
| `mtl.zig` | ✅ | Monad Transformer Library (完整实现) |
| `distributive.zig` | ✅ | Distributive Laws (分配律实现) |
| `selective.zig` | ✅ | Selective Applicative Functors (选择性应用函子) |

### v0.8.0 - 性能优化与基准测试

| 模块 | 状态 | 说明 |
|------|------|------|
| `benchmark.zig` | ✅ | 性能基准测试框架 - 完整实现 |
| `async.zig` | 🚀 | 异步抽象 (未来实现) - Future/Promise/Async Monad |
| `parallel.zig` | ✅ | 并发计算抽象 - 顺序实现，为并行预留接口 |
| `effect.zig` | ✅ | 扩展Effect System - FileSystem效果完成 |
| `network.zig` | ✅ | 网络效果 - HTTP/TCP/UDP支持 (已在 v1.2.0 实现) |
| `random.zig` | ✅ | 随机效果 - RandomInt/Float/Bytes/Shuffle |
| `time.zig` | ✅ | 时间效果 - CurrentTime/Sleep/Duration/格式化 |
| `config.zig` | ✅ | 配置效果 - Get/Set/Load/Save配置 |

### v0.9.0 - 实用工具与集成

| 模块 | 状态 | 说明 |
|------|------|------|
| `json.zig` | ✅ | JSON 处理 - 函数式JSON编解码 |
| `http.zig` | ✅ | HTTP客户端 - 函数式HTTP抽象 |
| `codec.zig` | ✅ | 编解码器 - 序列化/反序列化 |
| `validation.zig` | ✅ | 数据验证 - 组合式验证器 |

### v1.0.0 - 稳定版本 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| API稳定化 | ✅ | 添加prelude/category导出，创建API稳定性文档 |
| 全面测试 | ✅ | 568个测试全部通过，无内存泄漏 |
| 性能优化 | ✅ | 零成本抽象已验证（comptime实现） |
| 文档完善 | ✅ | 创建用户指南、API稳定性文档 |
| 示例代码 | ✅ | 创建examples/目录，添加3个示例 |
| 生态系统 | ✅ | CONTRIBUTING.md, CODE_OF_CONDUCT.md, issue模板 |

### v1.1.0 - 增强功能 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `connection_pool.zig` | ✅ | HTTP 连接池 - 连接复用和池化 |
| `auth.zig` | ✅ | 认证支持 - Basic/Bearer/ApiKey |
| `i18n.zig` | ✅ | 错误本地化 - 多语言消息支持 |
| `schema.zig` | ✅ | JSON Schema 验证 |
| CI/CD | ✅ | GitHub Actions 自动化测试 |

### v1.2.0 - 网络效果 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `tcp.zig` | ✅ | TCP 客户端 - 同步 TCP 连接和数据传输 (8 tests) |
| `udp.zig` | ✅ | UDP 客户端 - 无连接数据报传输 (8 tests) |
| `network.zig` | ✅ | 网络效果系统 - 函数式网络操作抽象 (7 tests) |
| `websocket.zig` | ✅ | WebSocket 客户端 - 双向通信支持 (15 tests) |

### v1.3.0 - 弹性模式 ✅

| 模块 | 状态 | 说明 |
|------|------|------|
| `retry.zig` | ✅ | 重试策略 - 指数退避、抖动、最大重试次数 (16 tests) |
| `circuit_breaker.zig` | ✅ | 断路器 - 熔断保护、半开状态、故障计数 (15 tests) |
| `bulkhead.zig` | ✅ | 隔板模式 - 资源隔离、并发限制 (14 tests) |
| `timeout.zig` | ✅ | 超时控制 - 操作超时、截止时间 (14 tests) |
| `fallback.zig` | ✅ | 降级策略 - 默认值、备用操作、缓存降级 (15 tests) |

### v1.4.0 - 项目重构 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| 模块化重构 | ✅ | 将 60+ 文件重组为 13 个子目录 |
| mod.zig 入口 | ✅ | 每个子目录添加模块入口文件 |
| 导入路径更新 | ✅ | 修复跨模块导入使用相对路径 |
| root.zig 重写 | ✅ | 使用子模块导入替代平铺导入 |
| prelude.zig 更新 | ✅ | 更新为新的模块化导入 |
| 测试验证 | ✅ | 737 tests 全部通过 |

### v1.5.0 - 真正并行计算 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `RealThreadPool` | ✅ | 真正的多线程池实现 |
| `realParMap` | ✅ | 真正并行的 map 操作 |
| `realParFilter` | ✅ | 真正并行的 filter 操作 |
| `realParReduce` | ✅ | 真正并行的 reduce 操作 |
| 测试验证 | ✅ | 742 tests 全部通过 |

### v1.6.0 - 文档与示例完善 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `parallel_example.zig` | ✅ | RealThreadPool、realParMap/Filter/Reduce 示例 |
| `resilience_example.zig` | ✅ | RetryPolicy、CircuitBreaker、Bulkhead、Timeout、Fallback 示例 |
| `network_example.zig` | ✅ | TCP/UDP/HTTP/WebSocket 配置和概念示例 |
| 文档更新 | ✅ | docs/concurrent/README.md 添加 RealThreadPool 文档 |
| 构建系统 | ✅ | build.zig 添加 example-parallel/resilience/network 目标 |
| root.zig 导出 | ✅ | 添加更多类型导出供示例使用 |
| 测试验证 | ✅ | 742 tests 全部通过 |

### v1.6.1 - Windows 跨平台兼容性修复 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| UDP Windows 兼容 | ✅ | 修复 `posix.recvfrom` 在 Windows 上需要 libc 的问题 |
| getenv Windows 兼容 | ✅ | 修复 `std.posix.getenv` 在 Windows 上不可用的问题 |
| EnvConfigHandlerAlloc | ✅ | 新增跨平台环境变量处理器 |
| 测试验证 | ✅ | 742 tests 全部通过（Linux），Windows CI 修复 |

### v1.7.0 - 函数增强与 Curry ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `curry2`/`curry3` | ✅ | 柯里化 - 将多参函数转为单参函数链 |
| `uncurry2Call`/`uncurry3Call` | ✅ | 反柯里化调用 |
| `Const`/`const_` | ✅ | 常量函数 |
| 增强 Pipe | ✅ | `map`、`filter`、`zip`、`branch`、`repeat`、`debug` |
| OptionPipe | ✅ | 处理可选值的管道类型 |
| 更多 Monoid | ✅ | First、Last、Endo、Dual、浮点数 Monoid |
| 测试验证 | ✅ | 789 tests 全部通过 |

### v1.8.0 - 序列工具与 Do Notation ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `sequence.zig` | ✅ | 序列工具 - zipWith、zip3、unzip、intersperse、chunksOf、sliding、transpose |
| `do_notation.zig` | ✅ | Do-notation 构建器 - DoOption、DoResult、DoList |
| Reader 增强 | ✅ | local、withReader 函数 |
| Writer 增强 | ✅ | listens、passWithModifier 函数 |
| State 增强 | ✅ | gets、putValue、modifyGet 函数 |
| 测试验证 | ✅ | 836 tests 全部通过 |

### v1.9.0 - 数据结构增强 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `non_empty.zig` | ✅ | NonEmptyList - 保证非空的列表类型 |
| `these.zig` | ✅ | These - This/That/Both 联合类型 |
| Validation 增强 | ✅ | invalidOne、mapValidation、flatMapValidation、ensure、fromOption/Result、toResult |
| data/mod.zig 导出 | ✅ | NonEmptyList、These 及辅助函数 |
| core/mod.zig 导出 | ✅ | Validation 增强函数 |
| root.zig 导出 | ✅ | 所有新类型和函数 |
| 测试验证 | ✅ | 872 tests 全部通过 |

### v2.0.0 - 高级类型与工具 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `ior.zig` | ✅ | Ior - 带警告的成功类型（Left/Right/Both） |
| `tuple.zig` | ✅ | Tuple 工具 - Pair、Triple 及函数式操作 |
| `natural.zig` | ✅ | Natural Transformation - Option/Result/切片 互转 |
| data/mod.zig 导出 | ✅ | Ior、Tuple 类型和函数 |
| functor/mod.zig 导出 | ✅ | Natural Transformation 函数 |
| root.zig 导出 | ✅ | 所有新类型和函数 |
| 测试验证 | ✅ | 915 tests 全部通过 |

### v2.1.0 - 类型类工具与实用函数 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| `eq.zig` | ✅ | Eq 类型类 - 等价性比较抽象 (12 tests) |
| `ord.zig` | ✅ | Ord 类型类 - 排序比较抽象 (14 tests) |
| `bounded.zig` | ✅ | Bounded 类型类 - 有界类型抽象 (10 tests) |
| `utils.zig` | ✅ | 实用函数 - when、unless、guard、numeric、comparing 等 (10 tests) |
| algebra/mod.zig 导出 | ✅ | Eq、Ord、Bounded 类型类和实例 |
| function/mod.zig 导出 | ✅ | 实用函数导出 |
| root.zig 导出 | ✅ | 所有新类型类和函数 |
| 测试验证 | ✅ | 961 tests 全部通过 |

### v2.2.0 - API 整合与重构 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| Option.flatten | ✅ | 新增 flatten 函数展平嵌套 Option (3 tests) |
| Alternative 整合 | ✅ | orOp 委托给 Option.or()，消除重复实现 |
| Natural 整合 | ✅ | flattenOption 委托给 core flatten |
| Distributive 整合 | ✅ | distribute 委托给 core flatten |
| Either 文档 | ✅ | 添加 Either vs Result 区别说明 |
| 导出更新 | ✅ | core/mod.zig 和 root.zig 导出 flatten |
| 测试验证 | ✅ | 964 tests 全部通过 |

> **注意**: Zig 的 async/await 功能目前正在重新设计中（0.11+ 已移除），
> 因此 `async.zig` 模块标记为**未来实现**，待Zig官方稳定async支持后再行开发。

## 特性对照表

| 特性 | Haskell | Scala | Rust | **zigFP** |
|------|---------|-------|------|-----------|
| Option | `Maybe` | `Option` | `Option` | `Option(T)` |
| Result | `Either` | `Either` | `Result` | `Result(T,E)` |
| 函数组合 | `.` | `compose` | - | `compose()` |
| 管道 | `&` | `\|>` | - | `Pipe(T)` |
| 惰性 | 默认 | `lazy` | - | `Lazy(T)` |
| Reader | `Reader` | `Reader` | - | `Reader(E,T)` |
| Writer | `Writer` | `Writer` | - | `Writer(W,T)` |
| State | `State` | `State` | - | `State(S,T)` |
| Lens | `lens` | `Monocle` | - | `Lens(S,A)` |
| Memoize | `memoize` | - | - | `Memoized(K,V)` |
| Monoid | `Monoid` | `Monoid` | - | `Monoid(T)` |
| IO | `IO` | `IO` | - | `IO(T)` |
| Iterator | `Iterator` | `Iterator` | `Iterator` | `SliceIterator(T)` |
| Validation | `Validation` | `Validated` | - | `Validation(T,E)` |
| Free | `Free` | `Free` | - | `Free(F,A)` |
| Trampoline | `Trampoline` | `Trampoline` | - | `Trampoline(A)` |
| Continuation | `Cont` | `Cont` | - | `Cont(R,A)` |
| Effect | `Eff` | `ZIO` | - | `Effect(E,A)` |
| Parser | `Parsec` | `FastParse` | `nom` | `Parser(T)` |
| Applicative | `Applicative` | `Applicative` | - | `OptionApplicative` |
| Foldable | `Foldable` | `Foldable` | - | `SliceFoldable` |
| Traversable | `Traversable` | `Traverse` | - | `SliceTraversable` |
| Arrow | `Arrow` | `Arrow` | - | `FunctionArrow` |
| Comonad | `Comonad` | `Comonad` | - | `Identity/Store/Env` |

## 性能特性

| 组件 | 开销 | 说明 |
|------|------|------|
| Option/Result | 零 | tagged union，编译时优化 |
| map/flatMap | 零 | comptime 内联 |
| compose/Pipe | 零 | comptime 展开 |
| Lazy | 一次调用 | 首次求值后缓存 |
| Lens | 极低 | 结构体浅复制 |
| Memoize | 哈希查表 | 适合纯函数，O(1) 查找 |

## 设计原则

1. **编译时优先**: 尽可能利用 Zig 的 comptime 能力
2. **零成本抽象**: 运行时无额外开销
3. **类型安全**: 充分利用类型系统防止错误
4. **Zig 惯用法**: 遵循 Zig 的设计哲学和命名规范
5. **法则驱动**: 所有 Monad 实现必须满足数学法则

## 相关文档

### 模块文档

| 模块 | 说明 |
|------|------|
| [core/](docs/core/README.md) | 核心类型 - Option, Result, Lazy, Validation |
| [monad/](docs/monad/README.md) | Monad 类型 - Reader, Writer, State, Cont, Free |
| [functor/](docs/functor/README.md) | Functor 抽象 - Functor, Applicative, Bifunctor |
| [algebra/](docs/algebra/README.md) | 代数结构 - Semigroup, Monoid, Foldable, Traversable |
| [data/](docs/data/README.md) | 数据结构 - Stream, Zipper, Iterator, Comonad |
| [function/](docs/function/README.md) | 函数工具 - compose, Pipe, Memoize |
| [effect/](docs/effect/README.md) | 效果系统 - Effect, IO, FileSystem, Random, Time |
| [parser/](docs/parser/README.md) | 解析器 - Parser Combinators, JSON, Codec |
| [network/](docs/network/README.md) | 网络操作 - TCP, UDP, WebSocket, HTTP |
| [resilience/](docs/resilience/README.md) | 弹性模式 - Retry, CircuitBreaker, Bulkhead |
| [concurrent/](docs/concurrent/README.md) | 并发工具 - Parallel, Benchmark |
| [util/](docs/util/README.md) | 工具模块 - Auth, I18n, Schema |
| [optics/](docs/optics/README.md) | 光学类型 - Lens, Iso, Prism |

### 其他文档

- [用户指南](docs/guide.md)
- [API 稳定性](docs/api-stability.md)
