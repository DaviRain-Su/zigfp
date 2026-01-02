# zigFP - 函数式编程工具库更新日志

## [v2.0.0] - 2026-01-02 - 高级类型与工具 ✅

### 🎯 新增功能

#### Ior - `src/data/ior.zig`

Ior (Inclusive Or) 类型，支持"警告但继续"的场景：

- **构造函数**: `Left`, `Right`, `Both`, `iorLeft`, `iorRight`, `iorBoth`
- **类型检查**: `isLeft`, `isRight`, `isBoth`, `hasLeft`, `hasRight`
- **访问器**: `getLeft`, `getRight`, `getBoth`, `leftOr`, `rightOr`
- **映射**: `map`, `mapLeft`, `bimap`
- **折叠**: `fold`
- **转换**: `toOption`, `toResult`, `toResultStrict`, `toThese`, `swap`
- **静态构造**: `fromResult`, `fromThese`, `fromOptions`

```zig
// Ior - 警告但继续
const ior = Ior([]const u8, i32).Both("warning", 42);
const result = ior.toResult();  // Ok(42), 忽略警告
const strict = ior.toResultStrict();  // Err("warning")

// 映射操作
const doubled = ior.map(i32, double);  // Both("warning", 84)
```

#### Tuple - `src/data/tuple.zig`

函数式编程中的元组工具：

- **Pair(A, B)**: 二元组类型
- **Triple(A, B, C)**: 三元组类型
- **访问器**: `first`, `second`, `third`
- **映射**: `mapFst`, `mapSnd`, `mapThd`, `bimap`, `trimap`
- **转换**: `swap`, `toArray`, `fold`, `toPairFst`, `toPairSnd`
- **工具函数**: `dup`, `fanout`, `fanout3`, `assocL`, `assocR`

```zig
// Pair 操作
const p = Pair(i32, []const u8).init(42, "hello");
const swapped = p.swap();  // Pair("hello", 42)

// fanout - 对同一值应用多个函数
const result = fanout(i32, i32, i32, double, negate, 5);
// Pair(10, -5)
```

#### Natural Transformation - `src/functor/natural.zig`

自然变换 - Functor 间的转换：

- **Option/Result 互转**: `optionToResult`, `resultToOption`, `resultErrToOption`
- **Option/切片 互转**: `optionToSlice`, `sliceHeadOption`, `sliceLastOption`, `sliceAtOption`
- **嵌套展平**: `flattenOption`, `flattenResult`
- **类型转换**: `safeCast`, `fromNullable`, `toNullable`
- **组合**: `composeNat`

```zig
// Option -> Result
const opt = Option(i32).Some(42);
const res = optionToResult(i32, []const u8, opt, "not found");

// 安全类型转换
const narrow = safeCast(i32, u8, 100);  // Some(100)
const overflow = safeCast(i32, u8, 300);  // None
```

### 📦 导出更新

- `root.zig` 新增导出：
  - Ior: `Ior`, `iorLeft`, `iorRight`, `iorBoth`
  - Tuple: `TuplePair`, `TupleTriple`, `tuplePair`, `tupleDup`, `fanout`, `fanout3`, `assocL`, `assocR`
  - Natural: `optionToResult`, `resultToOption`, `sliceHeadOption`, `flattenOption`, `safeCast`, etc.
- `data/mod.zig` 导出 Ior 和 Tuple 类型
- `functor/mod.zig` 导出 Natural Transformation 函数

### 📊 测试统计

- 新增 43 个测试（Ior 15 + Tuple 18 + Natural 11 - 1 重复）
- 总测试数：915 tests
- 所有测试通过，无内存泄漏

---

## [v1.9.0] - 2026-01-02 - 数据结构增强 ✅

### 🎯 新增功能

#### NonEmptyList - `src/data/non_empty.zig`

非空列表类型，保证列表至少有一个元素：

- **构造函数**: `singleton`, `init`, `fromSlice`, `fromSliceAlloc`
- **访问器**: `head`, `tail`, `last`, `get`, `len`, `toSlice`
- **添加操作**: `cons` (头部), `snoc` (尾部), `append`, `reverse`
- **函数式操作**: `map`, `foldl`, `foldl1`, `foldr`, `foldr1`
- **查询操作**: `filter`, `forEach`, `all`, `any`, `find`

```zig
// 创建非空列表
const nel = NonEmptyList(i32).singleton(allocator, 1);
const nel2 = try nel.snoc(allocator, 2);  // [1, 2]

// 函数式操作
const doubled = try nel.map(allocator, i32, double);
const sum = nel.foldl1(add);  // 不需要初始值
```

#### These - `src/data/these.zig`

表示"这个"、"那个"或"两者都有"的联合类型：

- **构造函数**: `This`, `That`, `Both`
- **类型检查**: `isThis`, `isThat`, `isBoth`
- **访问器**: `getThis`, `getThat`, `getBoth`
- **映射**: `mapThis`, `mapThat`, `bimap`, `fold`
- **转换**: `mergeWith`, `swap`, `thisOr`, `thatOr`
- **互转**: `fromResult`, `toOptionPair`, `fromOptions`

```zig
// 创建 These 值
const this = These(i32, []const u8).This(42);
const that = These(i32, []const u8).That("hello");
const both = These(i32, []const u8).Both(42, "hello");

// 函数式操作
const mapped = both.bimap(double, toUpper);
const result = both.fold(showInt, showStr, showBoth);
```

#### Validation 增强 - `src/core/validation.zig`

新增便捷函数：

- **`invalidOne`** - 从单个错误创建无效验证
- **`mapValidation`** - 映射有效值
- **`flatMapValidation`** - 扁平映射验证
- **`fromOption`** - 从 Option 转换为 Validation
- **`fromResult`** - 从 Result 转换为 Validation
- **`toResult`** - 从 Validation 转换为 Result
- **`ensure`** - 确保条件成立，否则返回错误

```zig
// 从 Option 创建 Validation
const v = try validationFromOption(i32, []const u8, opt, allocator, "missing value");

// 确保条件
const v2 = try ensureValidation(i32, []const u8, v, allocator, isPositive, "must be positive");

// 转换为 Result
const result = validationToResult(i32, []const u8, v);
```

### 📦 导出更新

- `root.zig` 新增导出：
  - Data: NonEmptyList, nonEmptyFromArray, These, fromOptions
  - Validation: invalidOne, mapValidation, flatMapValidation, validationFromOption, validationFromResult, validationToResult, ensureValidation
- `data/mod.zig` 导出 NonEmptyList, These 及相关函数
- `core/mod.zig` 导出所有 Validation 增强函数

### 📊 测试统计

- 新增 35+ 个测试
- 总测试数：872 tests
- 所有测试通过，无内存泄漏

---

## [v1.8.0] - 2026-01-02 - 序列工具与 Do-Notation ✅

### 🎯 新增功能

#### 序列工具 - `src/data/sequence.zig`

提供函数式风格的序列操作：

- **`zipWith`** - 使用函数合并两个序列
- **`ZipWithIterator`/`zipWithIter`** - 惰性 zipWith 迭代器
- **`zip3`** - 合并三个序列为三元组
- **`zipWith3`** - 使用函数合并三个序列
- **`unzip`/`unzip3`** - 分解 Pair/Triple 序列
- **`intersperse`** - 在元素间插入分隔符
- **`intercalate`** - 使用分隔序列连接多个序列
- **`chunksOf`** - 将序列分成固定大小的块
- **`sliding`** - 滑动窗口视图
- **`transpose`** - 转置二维序列
- **`replicate`** - 重复元素 n 次
- **`range`** - 生成整数范围
- **`reverse`** - 反转序列
- **`takeLast`/`dropLast`** - 获取/删除最后 n 个元素

```zig
// zipWith
const result = try zipWith(i32, i32, i32, allocator, &as, &bs, add);
// intersperse
const result = try intersperse(i32, allocator, &[_]i32{1, 2, 3}, 0);
// chunksOf
const chunks = try chunksOf(i32, allocator, &xs, 2);
```

#### Do-Notation 构建器 - `src/monad/do_notation.zig`

模拟 Haskell 的 do-notation，提供流畅的 monadic 组合：

- **`DoOption(T)`** - Option Monad 的 Do 构建器
  - `start`/`pure` - 开始 Do 块
  - `andThen` - bind (>>=)
  - `map` - 映射值
  - `then` - 执行但忽略前一个值
  - `guard`/`filter` - 条件检查
  - `unwrapOr` - 获取值或默认值

- **`DoResult(T, E)`** - Result Monad 的 Do 构建器
  - `start`/`pure`/`fail` - 开始 Do 块
  - `andThen` - bind (>>=)
  - `map`/`mapErr` - 映射值/错误
  - `guard`/`ensure` - 条件检查
  - `unwrapOr` - 获取值或默认值

- **`DoList(T)`** - 列表推导风格的 Do 构建器
  - `from`/`range` - 从切片或范围开始
  - `flatMap`/`map`/`filter` - 列表操作

```zig
// Do-notation 风格
const result = DoOption(i32)
    .pure(10)
    .andThen(i32, validate)
    .map(i32, double)
    .guard(isPositive)
    .run();
```

#### Reader Monad 增强 - `src/monad/reader.zig`

- **`LocalReader`** - 在修改后的环境中运行 Reader
- **`local`** - 创建 LocalReader
- **`ReaderWithEnv`** - 带环境变换的 Reader
- **`withReader`** - 使用环境提取器包装 Reader

```zig
// local - 在修改后的环境中运行
const localReader = local(i32, i32, getEnv, doubleEnv);
// withReader - 从外部环境提取内部环境
const appReader = withReader(AppConfig, DbConfig, T, dbReader, extractDb);
```

#### Writer Monad 增强 - `src/monad/writer.zig`

- **`listens`** - 监听并转换日志
- **`passWithModifier`** - 传递日志修改函数

#### State Monad 增强 - `src/monad/state.zig`

- **`gets`** - 使用函数获取状态的一部分
- **`putValue`** - 设置状态为给定值
- **`modifyGet`** - 修改状态并返回旧值
- **`StateWithValue`** - 设置状态并返回值的辅助类型
- **`ModifyGetState`** - modifyGet 的辅助类型

```zig
// gets - 获取状态的一部分
const getter = gets(Counter, i32, getCount);
// modifyGet - 修改并返回旧值
const modifier = modifyGet(i32, doubleState);
```

### 📦 导出更新

- `root.zig` 新增导出：
  - Do-Notation: DoOption, DoResult, DoList, doOption, doResult, pureOption, pureResult
  - Reader: LocalReader, local, ReaderWithEnv, withReader
  - State: gets, putValue, modifyGet, StateWithValue, ModifyGetState
  - Sequence: zipWith, zip3, unzip, intersperse, intercalate, chunksOf, sliding, transpose, etc.
- `monad/mod.zig` 导出所有 Do-Notation 和 Monad 增强
- `data/mod.zig` 导出所有序列工具函数

### 📊 测试统计

- 新增 47 个测试
- 总测试数：836 tests
- 所有测试通过，无内存泄漏

---

## [v1.7.0] - 2026-01-02 - 函数增强与 Curry ✅

### 🎯 新增功能

#### 柯里化 (Currying) - `src/function/function.zig`

实现了经典函数式编程的柯里化支持：

- **`Curry2`** - 二元函数柯里化类型
- **`Curry2Applied`** - 已应用第一个参数的柯里化函数
- **`curry2`** - 创建二元柯里化函数
- **`Curry3`** - 三元函数柯里化类型
- **`Curry3Applied1`/`Curry3Applied2`** - 逐步应用的三元柯里化
- **`curry3`** - 创建三元柯里化函数
- **`uncurry2Call`/`uncurry3Call`** - 反柯里化调用
- **`Const`/`const_`** - 常量函数

```zig
const add = struct { fn f(a: i32, b: i32) i32 { return a + b; } }.f;
const curriedAdd = curry2(i32, i32, i32, add);
const add5 = curriedAdd.apply(5);
const result = add5.apply(3); // 8
```

#### 增强管道 (Pipe) - `src/function/pipe.zig`

扩展了 `Pipe` 类型的操作符：

- **`map`** - 映射操作（then 的别名）
- **`filter`** - 条件过滤，返回 Option
- **`satisfies`** - 检查值是否满足谓词
- **`zip`** - 将值与另一个值配对
- **`toOption`** - 包装到 Option 类型
- **`branch`** - 条件分支选择不同转换
- **`repeat`** - 重复应用函数 n 次
- **`effect`** - tap 的别名
- **`debug`** - 调试输出辅助

新增 **`OptionPipe`** 类型 - 处理可选值的管道：

- `map`/`flatMap` - 映射和扁平映射
- `filter` - 条件过滤
- `unwrapOr`/`unwrapOrElse` - 获取值或默认值
- `isSome`/`isNone` - 检查是否有值
- `ifSome`/`ifNone` - 条件执行副作用
- `and_`/`or_` - 逻辑组合
- `toPipe` - 转换为普通 Pipe

```zig
const result = OptionPipe(i32).some(5)
    .map(i32, double)      // Some(10)
    .filter(isPositive)    // Some(10)
    .flatMap(i32, safeDivide)
    .unwrapOr(0);
```

#### 更多 Monoid 实例 - `src/algebra/monoid.zig`

新增多个 Monoid 实例：

**浮点数 Monoid**:
- `sumMonoidF64` / `productMonoidF64` - f64 加法/乘法
- `sumMonoidF32` / `productMonoidF32` - f32 加法/乘法

**First/Last Monoid**:
- `First(T)` - 保留第一个非空值的包装类型
- `firstMonoid(T)` - First Monoid
- `Last(T)` - 保留最后一个非空值的包装类型
- `lastMonoid(T)` - Last Monoid

**Endo/Dual Monoid**:
- `Endo(T)` - 自函数包装类型 (T -> T)
- `endoMonoid(T)` - 函数组合 Monoid
- `Dual(T)` - 反转组合顺序的包装类型
- `DualMonoid` - 创建 Dual Monoid 的工具
- `dualSumMonoidI32` / `dualSubMonoidI32` - 预定义 Dual 实例

### 🐛 Bug 修复

- 修复 Windows 上 `receiveFromWindows` 未检查 socket 是否绑定的问题
  - 现在正确返回 `NotBound` 错误当 socket 为 null 时

### 📦 导出更新

- `root.zig` 新增导出：Curry2, curry2, Curry3, curry3, OptionPipe, First, Last, Endo, Dual 等
- `function/mod.zig` 导出所有柯里化和增强管道类型
- `algebra/mod.zig` 导出所有新 Monoid 实例

### 📊 测试统计

- 新增 47 个测试
- 总测试数：789 tests
- 所有测试通过，无内存泄漏

---

## [v1.6.1] - 2026-01-02 - Windows 跨平台兼容性修复 ✅

### 🐛 Bug 修复

#### UDP 模块 Windows 兼容性 (`src/network/udp.zig`)
- 修复 `posix.recvfrom` 在 Windows 上需要显式链接 libc 的问题
- 使用编译时条件选择函数实现：
  - Windows: `receiveFrom` 返回 `UdpError.ReceiveFailed`
  - POSIX: 正常使用 `posix.recvfrom`
- 添加 `receiveFromWindows` 和 `receiveFromPosix` 内部实现

#### 环境变量处理 Windows 兼容性 (`src/effect/config.zig`)
- 修复 `std.posix.getenv` 在 Windows 上不可用的问题
  - Windows 环境变量使用 WTF-16 编码，需要使用 `std.process.getEnvVarOwned`
- `EnvConfigHandler.get` 和 `EnvConfigHandler.handle` 使用编译时函数选择
- 新增 `EnvConfigHandlerAlloc` 跨平台环境变量处理器：
  - 支持所有平台（包括 Windows）
  - 使用 `std.process.getEnvVarOwned` 获取环境变量
  - 需要 allocator，调用者负责释放返回值

### 📋 技术说明

Windows 平台限制：
- `std.posix.recvfrom` 需要显式链接 libc，在不链接 libc 的情况下无法使用
- `std.posix.getenv` 在 Windows 上无法使用，因为环境变量是 WTF-16 编码

解决方案采用编译时条件选择模式：
```zig
pub const receiveFrom = if (builtin.os.tag == .windows)
    receiveFromWindows
else
    receiveFromPosix;
```

---

## [v1.6.0] - 2026-01-02 - 文档与示例完善 ✅

### 🎯 新增示例

创建了 3 个新示例文件，展示 zigFP 的高级功能：

#### `examples/parallel_example.zig`
演示真正的并行计算功能：
- `RealThreadPool` 线程池创建和管理
- `realParMap` 并行映射操作
- `realParFilter` 并行过滤操作
- `realParReduce` 并行归约操作
- `Par` Monad 和 `parZip` 组合
- 批处理操作 `batchMap`

#### `examples/resilience_example.zig`
演示弹性模式功能：
- `RetryPolicy` 重试策略（固定间隔、指数退避、线性退避）
- `CircuitBreaker` 断路器（状态转换、故障阈值）
- `Bulkhead` 隔板模式（并发限制、资源隔离）
- `Timeout` 超时控制
- `Fallback` 降级策略

#### `examples/network_example.zig`
演示网络模块配置：
- `TcpConfig` TCP 客户端配置
- `UdpConfig` UDP 配置
- `HttpConfig` 和 `HttpStatus` HTTP 配置和状态码
- `WebSocketConfig` WebSocket 配置
- 网络与弹性模式的组合使用建议

### 📝 文档更新

- **docs/concurrent/README.md** - 完整的 RealThreadPool API 文档
  - 线程池创建和配置
  - 并行操作函数说明
  - 顺序操作对比
  - 性能建议

### 🔧 构建系统

- **build.zig** 添加新的构建目标：
  - `example-parallel` - 运行并行计算示例
  - `example-resilience` - 运行弹性模式示例
  - `example-network` - 运行网络模块示例
  - `examples` 目标现在包含所有 7 个示例

### 📦 root.zig 导出扩展

添加了更多类型的便捷导出：
- 并发模块: `seqMap/Filter/Reduce/Fold/Zip`, `BatchConfig`, `batchMap/Reduce`, `Par`, `parZip/Sequence`, `RealThreadPool`, `realParMap/Filter/Reduce`
- 弹性模块: `retryPolicy`, `circuitBreaker`, `Timeout`, `Fallback` 及相关配置类型
- 网络模块: `TcpConfig`, `UdpConfig`, `WebSocketConfig`, `HttpMethod`, `HttpStatus`, `HttpConfig`

### 📊 统计数据
- **总测试数**: 742个（全部通过）
- **新增示例**: 3 个
- **示例总数**: 7 个
- **无内存泄漏**

---

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