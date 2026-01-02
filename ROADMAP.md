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

## 项目结构

```
src/
├── root.zig         # 库入口
├── option.zig       # Option/Maybe - 安全空值处理
├── result.zig       # Result/Either - 错误处理
├── lazy.zig         # 惰性求值
├── function.zig     # compose, identity, flip
├── pipe.zig         # 管道操作
├── reader.zig       # Reader Monad - 依赖注入
├── writer.zig       # Writer Monad - 日志累积
├── state.zig        # State Monad - 状态管理
├── lens.zig         # Lens - 不可变更新
├── memoize.zig      # 记忆化
├── monoid.zig       # Monoid - 可组合代数结构
├── io.zig           # IO - 函数式 IO 操作
├── iterator.zig     # Iterator - 函数式迭代器
├── validation.zig   # Validation - 累积错误验证
├── free.zig         # Free Monad + Trampoline
├── cont.zig         # Continuation Monad - CPS 风格
├── effect.zig       # Effect System - 代数效果
├── parser.zig       # Parser Combinators - 组合式解析器
├── applicative.zig  # Applicative Functor
├── foldable.zig     # Foldable - 折叠操作
├── traversable.zig  # Traversable - 效果遍历
├── arrow.zig        # Arrow - 函数抽象
└── comonad.zig      # Comonad - Monad 的对偶
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
| `benchmark.zig` | 🔄 | 性能基准测试框架 - 各抽象性能对比 |
| `async.zig` | ⏳ | 异步抽象 (待Zig async稳定) - Future/Promise/Async Monad |
| `parallel.zig` | ⏳ | 并行计算抽象 - Par Monad/并行Traversable |
| `effect.zig` | ⏳ | 扩展Effect System - 更多内置效果类型 |

### v0.9.0 - 实用工具与集成

| 模块 | 状态 | 说明 |
|------|------|------|
| `json.zig` | ⏳ | JSON 处理 - 函数式JSON编解码 |
| `http.zig` | ⏳ | HTTP客户端 - 函数式HTTP抽象 |
| `codec.zig` | ⏳ | 编解码器 - 序列化/反序列化 |
| `validation.zig` | ⏳ | 数据验证 - 组合式验证器 |

### v1.0.0 - 稳定版本

| 任务 | 状态 | 说明 |
|------|------|------|
| API稳定化 | ⏳ | 冻结公共API，确保向后兼容 |
| 全面测试 | ⏳ | 100%测试覆盖率 |
| 性能优化 | ⏳ | 编译时优化和运行时性能调优 |
| 文档完善 | ⏳ | 用户指南、API文档、示例代码 |
| 生态系统 | ⏳ | 社区贡献和第三方集成 |

> **注意**: Zig 的 async/await 功能目前正在重新设计中（0.11+ 已移除），
> 待官方稳定后可考虑添加异步抽象模块。

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

### 类型文档
- [Option 类型](docs/option.md)
- [Result 类型](docs/result.md)
- [Lazy 类型](docs/lazy.md)

### 函数工具文档
- [函数组合](docs/function.md)
- [管道操作](docs/pipe.md)

### Monad 文档
- [Reader Monad](docs/reader.md)
- [Writer Monad](docs/writer.md)
- [State Monad](docs/state.md)

### 高级抽象文档
- [Lens](docs/lens.md)
- [Memoize](docs/memoize.md)
- [Monoid](docs/monoid.md)
