//! zigFP - Zig 函数式编程工具库
//!
//! 将函数式语言的核心特性带入 Zig，用函数式风格写高性能代码。
//!
//! ## 核心类型
//! - `Option(T)` - 安全空值处理
//! - `Result(T, E)` - 错误处理
//! - `Lazy(T)` - 惰性求值
//!
//! ## 函数工具
//! - `compose` - 函数组合
//! - `Pipe(T)` - 管道操作
//!
//! ## Monad
//! - `Reader(Env, T)` - 依赖注入
//! - `Writer(W, T)` - 日志累积
//! - `State(S, T)` - 状态管理
//!
//! ## 高级抽象
//! - `Lens(S, A)` - 不可变更新
//! - `Memoized(K, V)` - 记忆化
//! - `Monoid(T)` - 可组合代数结构

const std = @import("std");

// ============ 核心类型 ============

/// Option 类型 - 安全空值处理
pub const option = @import("option.zig");
pub const Option = option.Option;
pub const some = option.some;
pub const none = option.none;

/// Result 类型 - 错误处理
pub const result = @import("result.zig");
pub const Result = result.Result;
pub const ok = result.ok;
pub const err = result.err;

/// Lazy 类型 - 惰性求值
pub const lazy = @import("lazy.zig");
pub const Lazy = lazy.Lazy;

// ============ 函数工具 ============

/// 函数组合工具
pub const function = @import("function.zig");
pub const compose = function.compose;
pub const identity = function.identity;
pub const flip = function.flip;
pub const apply = function.apply;
pub const tupled = function.tupled;
pub const untupled = function.untupled;
pub const Partial = function.Partial;
pub const partial = function.partial;

/// 管道操作
pub const pipe_mod = @import("pipe.zig");
pub const Pipe = pipe_mod.Pipe;
pub const pipe = pipe_mod.pipe;

// ============ Monad ============

/// Reader Monad - 依赖注入
pub const reader = @import("reader.zig");
pub const Reader = reader.Reader;
pub const ReaderValue = reader.ReaderValue;
pub const ask = reader.ask;
pub const asks = reader.asks;

/// Writer Monad - 日志累积
pub const writer = @import("writer.zig");
pub const Writer = writer.Writer;
pub const tell = writer.tell;

/// State Monad - 状态管理
pub const state = @import("state.zig");
pub const State = state.State;
pub const StateValue = state.StateValue;
pub const get = state.get;
pub const modify = state.modify;
pub const StatefulOps = state.StatefulOps;

// ============ 高级抽象 ============

/// Lens - 不可变更新
pub const lens = @import("lens.zig");
pub const Lens = lens.Lens;
pub const makeLens = lens.makeLens;

/// Memoize - 记忆化
pub const memoize_mod = @import("memoize.zig");
pub const Memoized = memoize_mod.Memoized;
pub const Memoized2 = memoize_mod.Memoized2;
pub const memoize = memoize_mod.memoize;
pub const memoize2 = memoize_mod.memoize2;

/// Monoid - 可组合代数结构
pub const monoid = @import("monoid.zig");
pub const Monoid = monoid.Monoid;
pub const sumMonoid = monoid.sumMonoid;
pub const productMonoid = monoid.productMonoid;
pub const allMonoid = monoid.allMonoid;
pub const anyMonoid = monoid.anyMonoid;
pub const sumMonoidI32 = monoid.sumMonoidI32;
pub const productMonoidI32 = monoid.productMonoidI32;
pub const maxMonoidI32 = monoid.maxMonoidI32;
pub const minMonoidI32 = monoid.minMonoidI32;

// ============ IO 模块 ============

/// IO - 函数式 IO 操作
pub const io = @import("io.zig");
pub const IO = io.IO;
pub const IOVoid = io.IOVoid;
pub const Console = io.Console;
pub const console = io.console;
pub const putStrLn = io.putStrLn;
pub const putStr = io.putStr;
pub const getLine = io.getLine;
pub const getContents = io.getContents;

// ============ v0.2.0 扩展模块 ============

/// Iterator - 函数式迭代器
pub const iterator = @import("iterator.zig");
pub const SliceIterator = iterator.SliceIterator;
pub const MapIterator = iterator.MapIterator;
pub const FilterIterator = iterator.FilterIterator;
pub const TakeIterator = iterator.TakeIterator;
pub const SkipIterator = iterator.SkipIterator;
pub const RangeIterator = iterator.RangeIterator;
pub const RepeatIterator = iterator.RepeatIterator;
pub const ZipIterator = iterator.ZipIterator;
pub const EnumerateIterator = iterator.EnumerateIterator;
pub const fromSlice = iterator.fromSlice;
pub const range = iterator.range;
pub const rangeStep = iterator.rangeStep;
pub const repeat = iterator.repeat;

/// Validation - 累积错误验证
pub const validation = @import("validation.zig");
pub const Validation = validation.Validation;
pub const valid = validation.valid;
pub const invalid = validation.invalid;
pub const Validator = validation.Validator;

/// Free Monad - 可解释的 DSL
pub const free = @import("free.zig");
pub const Free = free.Free;
pub const Trampoline = free.Trampoline;
pub const Program = free.Program;
pub const ProgramOp = free.ProgramOp;
pub const ConsoleF = free.ConsoleF;
pub const ConsoleIO = free.ConsoleIO;
pub const printLine = free.printLine;
pub const readLine = free.readLine;

// ============ v0.3.0 高级抽象 ============

/// Continuation Monad - 控制流抽象
pub const cont = @import("cont.zig");
pub const Cont = cont.Cont;
pub const CPS = cont.CPS;
pub const TrampolineCPS = cont.TrampolineCPS;

/// Effect System - 代数效果系统
pub const effect = @import("effect.zig");
pub const Effect = effect.Effect;
pub const EffectTag = effect.EffectTag;
pub const Handler = effect.Handler;
pub const ReaderEffect = effect.ReaderEffect;
pub const StateEffect = effect.StateEffect;
pub const ErrorEffect = effect.ErrorEffect;
pub const LogEffect = effect.LogEffect;
pub const runPure = effect.runPure;

/// Parser Combinators - 组合式解析器
pub const parser = @import("parser.zig");
pub const Parser = parser.Parser;
pub const ParseResult = parser.ParseResult;
pub const ParseError = parser.ParseError;
// 基础解析器
pub const anyChar = parser.anyChar;
pub const digit = parser.digit;
pub const letter = parser.letter;
pub const alphaNum = parser.alphaNum;
pub const whitespace = parser.whitespace;
pub const eof = parser.eof;
pub const integer = parser.integer;
pub const skipWhitespace = parser.skipWhitespace;
// 组合子
pub const many = parser.many;
pub const many1 = parser.many1;
pub const ManyParser = parser.ManyParser;
pub const Many1Parser = parser.Many1Parser;

// ============ v0.4.0 类型类抽象 ============

/// Applicative Functor - 介于 Functor 和 Monad 之间的抽象
pub const applicative = @import("applicative.zig");
pub const OptionApplicative = applicative.OptionApplicative;
pub const ResultApplicative = applicative.ResultApplicative;
pub const ListApplicative = applicative.ListApplicative;
pub const liftA2Option = applicative.liftA2Option;
pub const liftA3Option = applicative.liftA3Option;
pub const liftA2Result = applicative.liftA2Result;

/// Foldable - 可折叠结构
pub const foldable = @import("foldable.zig");
pub const SliceFoldable = foldable.SliceFoldable;
pub const NumericFoldable = foldable.NumericFoldable;
pub const OptionFoldable = foldable.OptionFoldable;
pub const foldWithMonoid = foldable.foldWithMonoid;
pub const foldLeft = foldable.foldLeft;
pub const foldRight = foldable.foldRight;

/// Traversable - 可遍历结构
pub const traversable = @import("traversable.zig");
pub const SliceTraversable = traversable.SliceTraversable;
pub const OptionTraversable = traversable.OptionTraversable;
pub const traverseSliceOption = traversable.traverseSliceOption;
pub const sequenceSliceOption = traversable.sequenceSliceOption;
pub const traverseSliceResult = traversable.traverseSliceResult;
pub const sequenceSliceResult = traversable.sequenceSliceResult;

/// Arrow - 计算的抽象
pub const arrow = @import("arrow.zig");
pub const FunctionArrow = arrow.FunctionArrow;
pub const ComposedArrow = arrow.ComposedArrow;
pub const FirstArrow = arrow.FirstArrow;
pub const SecondArrow = arrow.SecondArrow;
pub const SplitArrow = arrow.SplitArrow;
pub const FanoutArrow = arrow.FanoutArrow;
pub const Either = arrow.Either;
pub const Pair = arrow.Pair;
pub const arr = arrow.arr;
pub const idArrow = arrow.idArrow;
pub const constArrow = arrow.constArrow;
pub const swap = arrow.swap;
pub const dup = arrow.dup;

/// Comonad - Monad 的对偶
pub const comonad = @import("comonad.zig");
pub const Identity = comonad.Identity;
pub const NonEmpty = comonad.NonEmpty;
pub const Store = comonad.Store;
pub const Env = comonad.Env;
pub const Traced = comonad.Traced;

// ============ v0.5.0 高级抽象扩展 ============

/// Bifunctor - 双参数 Functor
pub const bifunctor = @import("bifunctor.zig");
pub const BifunctorPair = bifunctor.Pair;
pub const BifunctorEither = bifunctor.Either;
pub const ResultBifunctor = bifunctor.ResultBifunctor;
pub const These = bifunctor.These;
pub const pair = bifunctor.pair;
pub const left = bifunctor.left;
pub const right = bifunctor.right;

/// Profunctor - 输入逆变、输出协变的 Functor
pub const profunctor_mod = @import("profunctor.zig");
pub const FunctionProfunctor = profunctor_mod.FunctionProfunctor;
pub const Star = profunctor_mod.Star;
pub const Costar = profunctor_mod.Costar;
pub const UpStar = profunctor_mod.UpStar;
pub const StrongProfunctor = profunctor_mod.StrongProfunctor;
pub const ChoiceProfunctor = profunctor_mod.ChoiceProfunctor;
pub const profunctor = profunctor_mod.profunctor;
pub const dimapFn = profunctor_mod.dimap;
pub const lmapFn = profunctor_mod.lmapFn;
pub const rmapFn = profunctor_mod.rmapFn;
pub const starFn = profunctor_mod.star;
pub const costarFn = profunctor_mod.costar;

/// Optics - 数据结构的焦点抽象
pub const optics = @import("optics.zig");
pub const Iso = optics.Iso;
pub const OpticsLens = optics.Lens;
pub const Prism = optics.Prism;
pub const Affine = optics.Affine;
pub const OpticsGetter = optics.Getter;
pub const OpticsSetter = optics.Setter;
pub const OpticsFold = optics.Fold;
pub const isoFn = optics.iso;
pub const lensFn = optics.lens;
pub const prismFn = optics.prism;
pub const affineFn = optics.affine;
pub const getterFn = optics.getter;
pub const somePrism = optics.somePrism;
pub const headAffine = optics.headAffine;
pub const identityIso = optics.identityIso;

/// Stream - 惰性无限流
pub const stream = @import("stream.zig");
pub const StreamType = stream.Stream;
pub const iterateStream = stream.iterate;
pub const repeatStreamFn = stream.repeatStream;
pub const cycleStream = stream.cycle;
pub const rangeStreamFn = stream.rangeStream;
pub const unfoldStream = stream.unfold;
pub const MapStream = stream.MapStream;
pub const FilterStream = stream.FilterStream;
pub const ZipWithStream = stream.ZipWithStream;
pub const TakeWhileStream = stream.TakeWhileStream;
pub const ScanlStream = stream.ScanlStream;
pub const mapStreamFn = stream.mapStream;
pub const filterStreamFn = stream.filterStream;
pub const zipWithStream = stream.zipWith;
pub const takeWhileStream = stream.takeWhile;
pub const scanlStream = stream.scanl;

/// Zipper - 高效局部数据更新
pub const zipper = @import("zipper.zig");
pub const ListZipper = zipper.ListZipper;
pub const BinaryTree = zipper.BinaryTree;
pub const TreeZipper = zipper.TreeZipper;
pub const listZipper = zipper.listZipper;
pub const treeZipper = zipper.treeZipper;

/// Semigroup - 结合操作的代数结构
pub const semigroup = @import("semigroup.zig");
pub const Semigroup = semigroup.Semigroup;
pub const sumSemigroupI32 = semigroup.sumSemigroup(i32);
pub const productSemigroupI32 = semigroup.productSemigroup(i32);
pub const maxSemigroupI32 = semigroup.maxSemigroup(i32);
pub const minSemigroupI32 = semigroup.minSemigroup(i32);
pub const allSemigroupBool = semigroup.allSemigroup;
pub const anySemigroupBool = semigroup.anySemigroup;
pub const stringSemigroupAlloc = semigroup.stringSemigroupAlloc;
pub const arraySemigroupAlloc = semigroup.arraySemigroupAlloc;
pub const functionSemigroup = semigroup.functionSemigroup;
pub const optionSemigroup = semigroup.optionSemigroup;

/// Functor - 可映射的类型构造器
pub const functor = @import("functor.zig");
pub const FunctorIdentity = functor.Identity;
pub const optionFunctor = functor.optionFunctor;
pub const identityFunctor = functor.identityFunctor;

/// Alternative - 选择和重复操作
pub const alternative = @import("alternative.zig");
pub const emptyOption = alternative.emptyOption;
pub const orOption = alternative.orOption;
pub const manyOption = alternative.manyOption;
pub const someOption = alternative.someOption;
pub const optionalOption = alternative.optionalOption;

/// Distributive - 分配律
pub const distributive = @import("distributive.zig");
pub const distributeOption = distributive.distributeOption;
pub const codistributeOption = distributive.codistributeOption;
pub const distributePairOption = distributive.distributePairOption;

/// Prelude - 函数式编程常用函数和类型别名
pub const prelude = @import("prelude.zig");
pub const Maybe = prelude.Maybe;
pub const PreludeEither = prelude.Either;
pub const PreludeId = prelude.Id;
pub const Unit = prelude.Unit;
pub const preludeId = prelude.id;
pub const preludeConstant = prelude.constant;
pub const preludeCompose2 = prelude.compose2;
pub const preludePipe = prelude.pipe;
pub const when = prelude.when;
pub const unless = prelude.unless;
pub const whenM = prelude.whenM;
pub const boolToOption = prelude.boolToOption;
pub const optionToBool = prelude.optionToBool;
pub const preludeSome = prelude.some;
pub const preludeNone = prelude.none;
pub const preludeOk = prelude.ok;
pub const preludeErr = prelude.err;
pub const preludePure = prelude.pure;
pub const preludeUnit = prelude.unit;

/// Category Theory - 范畴论基础
pub const category = @import("category.zig");
pub const function_category = category.function_category;
pub const kleisli = category.kleisli;
pub const covariant = category.covariant;
pub const category_laws = category.laws;

// ============ v0.7.0 Monad 组合和工具 ============

/// Selective Applicative Functors - 介于 Applicative 和 Monad 之间的抽象
pub const selective = @import("selective.zig");
pub const SelectiveEither = selective.Either;
pub const selectOption = selective.selectOption;
pub const branchOption = selective.branchOption;
pub const ifSOption = selective.ifSOption;
pub const whenSOption = selective.whenSOption;
pub const selectMOption = selective.selectMOption;
pub const eitherToSelector = selective.combinators.eitherToSelector;
pub const conditionalSelector = selective.combinators.conditionalSelector;
pub const firstSuccess = selective.combinators.firstSuccess;
pub const conditionalExecution = selective.combinators.conditionalExecution;

/// Monad Transformers - 组合不同 Monad
pub const mtl = @import("mtl.zig");
pub const EitherT = mtl.EitherT;
pub const OptionT = mtl.OptionT;
pub const IdentityMonad = mtl.Identity;

// ============ v0.8.0 性能优化与基准测试 ============

/// Benchmark - 性能基准测试框架
pub const benchmark = @import("benchmark.zig");
pub const Benchmark = benchmark.Benchmark;
pub const BenchmarkResult = benchmark.BenchmarkResult;
pub const runBenchmark = benchmark.runBenchmark;

/// FileSystem - 文件系统效果
pub const file_system = @import("file_system.zig");
pub const FileSystemEffect = file_system.FileSystemEffect;
pub const FileSystemHandler = file_system.FileSystemHandler;
pub const readFile = file_system.readFile;
pub const writeFile = file_system.writeFile;
pub const fileExists = file_system.fileExists;

/// Parallel - 并行计算抽象
pub const parallel = @import("parallel.zig");
pub const seqMap = parallel.seqMap;
pub const seqFilter = parallel.seqFilter;
pub const seqReduce = parallel.seqReduce;
pub const seqFold = parallel.seqFold;
pub const seqZip = parallel.seqZip;
pub const seqFlatMap = parallel.seqFlatMap;
pub const batchMap = parallel.batchMap;
pub const batchReduce = parallel.batchReduce;
pub const BatchConfig = parallel.BatchConfig;
pub const SplitStrategy = parallel.SplitStrategy;
pub const computeSplits = parallel.computeSplits;
pub const Par = parallel.Par;
pub const parZip = parallel.parZip;
pub const parSequence = parallel.parSequence;
pub const parTraverse = parallel.parTraverse;
pub const parMap = parallel.parMap;
pub const parFilter = parallel.parFilter;
// 调度器接口（预留实现）
pub const Task = parallel.Task;
pub const TaskStatus = parallel.TaskStatus;
pub const TaskPriority = parallel.TaskPriority;
pub const TaskQueue = parallel.TaskQueue;
pub const Scheduler = parallel.Scheduler;
pub const SchedulerConfig = parallel.SchedulerConfig;
pub const FixedThreadPool = parallel.FixedThreadPool;
pub const WorkStealingScheduler = parallel.WorkStealingScheduler;
pub const LoadBalancer = parallel.LoadBalancer;
pub const LoadBalanceStrategy = parallel.LoadBalanceStrategy;

/// Random - 随机数效果
pub const random = @import("random.zig");
pub const RandomOp = random.RandomOp;
pub const RandomEffect = random.RandomEffect;
pub const RandomResult = random.RandomResult;
pub const RandomHandler = random.RandomHandler;
pub const randomInt = random.randomInt;
pub const randomUint = random.randomUint;
pub const randomFloat = random.randomFloat;
pub const randomFloatRange = random.randomFloatRange;
pub const randomBytes = random.randomBytes;
pub const randomBool = random.randomBool;
pub const randomChoice = random.randomChoice;
pub const shuffleRandom = random.shuffle;
pub const sampleRandom = random.sample;

/// Time - 时间效果
pub const time = @import("time.zig");
pub const TimeOp = time.TimeOp;
pub const TimeEffect = time.TimeEffect;
pub const TimeResult = time.TimeResult;
pub const TimeFormat = time.TimeFormat;
pub const DateTime = time.DateTime;
pub const Duration = time.Duration;
pub const TimeHandler = time.TimeHandler;
pub const MockTimeHandler = time.MockTimeHandler;
pub const currentTime = time.currentTime;
pub const currentTimeMillis = time.currentTimeMillis;
pub const monotonicTime = time.monotonicTime;
pub const sleepNs = time.sleepNs;
pub const sleepMs = time.sleepMs;
pub const sleepDuration = time.sleep;
pub const formatTime = time.formatTime;
pub const parseTime = time.parseTime;
pub const measureTime = time.measure;

/// Config - 配置效果
pub const config = @import("config.zig");
pub const ConfigOp = config.ConfigOp;
pub const ConfigEffect = config.ConfigEffect;
pub const ConfigResult = config.ConfigResult;
pub const ConfigValue = config.ConfigValue;
pub const ConfigFormat = config.ConfigFormat;
pub const ConfigHandler = config.ConfigHandler;
pub const EnvConfigHandler = config.EnvConfigHandler;
pub const getConfig = config.getConfig;
pub const setConfig = config.setConfig;
pub const deleteConfig = config.deleteConfig;
pub const hasConfig = config.hasConfig;
pub const configKeys = config.configKeys;
pub const loadConfig = config.loadConfig;
pub const saveConfig = config.saveConfig;
pub const clearConfig = config.clearConfig;
pub const getConfigOrDefault = config.getConfigOrDefault;

// ============ v0.9.0 实用工具与集成 ============

/// JSON - 函数式JSON处理
pub const json = @import("json.zig");
pub const JsonValue = json.JsonValue;
pub const JsonPath = json.JsonPath;
pub const JsonError = json.JsonError;
pub const parseJson = json.parseJson;
pub const stringifyJson = json.stringifyJson;
pub const mapJson = json.mapJson;
pub const filterJson = json.filterJson;
pub const foldJson = json.foldJson;
pub const transformJson = json.transformJson;
pub const jsonPipeline = json.jsonPipeline;
pub const mergeJson = json.mergeJson;
pub const pluckJson = json.pluckJson;
pub const groupByJson = json.groupByJson;

/// HTTP - 函数式HTTP客户端
pub const http = @import("http.zig");
pub const HttpMethod = http.HttpMethod;
pub const HttpHeader = http.HttpHeader;
pub const HttpRequest = http.HttpRequest;
pub const HttpResponse = http.HttpResponse;
pub const HttpClient = http.HttpClient;
pub const HttpError = http.HttpError;
pub const HttpEffect = http.HttpEffect;
pub const RetryConfig = http.RetryConfig;
pub const RetryableHttpClient = http.RetryableHttpClient;
pub const RequestBuilder = http.RequestBuilder;
pub const MiddlewareChain = http.MiddlewareChain;
pub const parseJsonResponse = http.parseJsonResponse;
pub const httpGet = http.get;
pub const httpPost = http.post;
pub const httpPostJson = http.postJson;

/// Codec - 编解码器框架
pub const codec = @import("codec.zig");
pub const CodecError = codec.CodecError;
pub const CodecRegistry = codec.CodecRegistry;
pub const JsonEncoder = codec.JsonEncoder;
pub const JsonDecoder = codec.JsonDecoder;
pub const BinaryEncoder = codec.BinaryEncoder;
pub const BinaryDecoder = codec.BinaryDecoder;
pub const Codec = codec.Codec;
pub const CustomCodec = codec.CustomCodec;
pub const Base64Codec = codec.Base64Codec;
pub const HexCodec = codec.HexCodec;
pub const encodeJson = codec.encodeJson;
pub const decodeJson = codec.decodeJson;
pub const encodeBinary = codec.encodeBinary;
pub const decodeBinary = codec.decodeBinary;

/// Validation - 函数式验证框架 (扩展)
pub const validation_ext = @import("validation.zig");
pub const ValidationPipeline = validation_ext.ValidationPipeline;
pub const StringValidators = validation_ext.StringValidators;
pub const NumberValidators = validation_ext.NumberValidators;
pub const GenericValidators = validation_ext.GenericValidators;
pub const ValidationCombinators = validation_ext.Combinators;

// ============ v1.1.0 增强功能 ============

/// ConnectionPool - HTTP 连接池
pub const connection_pool = @import("connection_pool.zig");
pub const ConnectionPool = connection_pool.ConnectionPool;
pub const ConnectionPoolBuilder = connection_pool.ConnectionPoolBuilder;
pub const PooledConnection = connection_pool.ConnectionPool.PooledConnection;
pub const connectionPoolBuilder = connection_pool.connectionPool;

/// Auth - 认证支持
pub const auth = @import("auth.zig");
pub const BasicAuth = auth.BasicAuth;
pub const BearerToken = auth.BearerToken;
pub const ApiKey = auth.ApiKey;
pub const CustomAuth = auth.CustomAuth;
pub const AuthMiddleware = auth.AuthMiddleware;
pub const AuthBuilder = auth.AuthBuilder;
pub const AuthType = auth.AuthType;
pub const authBuilder = auth.auth;

/// I18n - 国际化支持
pub const i18n = @import("i18n.zig");
pub const Locale = i18n.Locale;
pub const MessageBundle = i18n.MessageBundle;
pub const MessageKey = i18n.MessageKey;
pub const LocaleContext = i18n.LocaleContext;
pub const BuiltinMessages = i18n.BuiltinMessages;
pub const formatMessage = i18n.formatMessage;

/// Schema - JSON Schema 验证
pub const schema = @import("schema.zig");
pub const Schema = schema.Schema;
pub const SchemaType = schema.SchemaType;
pub const SchemaBuilder = schema.SchemaBuilder;
pub const ValidationResult = schema.ValidationResult;
pub const ValidationError = schema.ValidationError;
pub const objectSchema = schema.objectSchema;

// ============ v1.2.0 网络效果 ============

/// TCP - TCP 客户端
pub const tcp = @import("tcp.zig");
pub const TcpClient = tcp.TcpClient;
pub const TcpConfig = tcp.TcpConfig;
pub const TcpError = tcp.TcpError;
pub const TcpClientBuilder = tcp.TcpClientBuilder;
pub const tcpClient = tcp.tcpClient;

/// UDP - UDP 客户端
pub const udp = @import("udp.zig");
pub const UdpSocket = udp.UdpSocket;
pub const UdpConfig = udp.UdpConfig;
pub const UdpError = udp.UdpError;
pub const UdpSocketBuilder = udp.UdpSocketBuilder;
pub const udpSocket = udp.udpSocket;

/// Network - 网络效果系统
pub const network = @import("network.zig");
pub const NetworkOp = network.NetworkOp;
pub const NetworkEffect = network.NetworkEffect;
pub const NetworkResult = network.NetworkResult;
pub const NetworkError = network.NetworkError;
pub const NetworkHandler = network.NetworkHandler;
pub const NetworkSequence = network.NetworkSequence;

/// WebSocket - WebSocket 客户端
pub const websocket = @import("websocket.zig");
pub const WebSocketClient = websocket.WebSocketClient;
pub const WebSocketConfig = websocket.WebSocketConfig;
pub const WebSocketError = websocket.WebSocketError;
pub const WebSocketClientBuilder = websocket.WebSocketClientBuilder;
pub const WebSocketFrame = websocket.Frame;
pub const WebSocketOpcode = websocket.Opcode;
pub const WebSocketMessage = websocket.Message;
pub const WebSocketCloseCode = websocket.CloseCode;
pub const webSocketClient = websocket.webSocketClient;
pub const parseWebSocketUrl = websocket.parseUrl;

// ============ v1.3.0 弹性模式 ============

/// Retry - 重试策略
pub const retry_mod = @import("retry.zig");
pub const RetryPolicy = retry_mod.RetryPolicy;
pub const ResilienceRetryConfig = retry_mod.RetryConfig;
pub const RetryStrategy = retry_mod.RetryStrategy;
pub const RetryStats = retry_mod.RetryStats;
pub const ResilienceRetryResult = retry_mod.RetryResult;
pub const Retrier = retry_mod.Retrier;
pub const RetryPolicyBuilder = retry_mod.RetryPolicyBuilder;
pub const RetryEffect = retry_mod.RetryEffect;
pub const retryPolicy = retry_mod.retryPolicy;

/// CircuitBreaker - 断路器
pub const circuit_breaker = @import("circuit_breaker.zig");
pub const CircuitBreaker = circuit_breaker.CircuitBreaker;
pub const CircuitState = circuit_breaker.CircuitState;
pub const CircuitBreakerConfig = circuit_breaker.CircuitBreakerConfig;
pub const CircuitBreakerError = circuit_breaker.CircuitBreakerError;
pub const CircuitStats = circuit_breaker.CircuitStats;
pub const CircuitBreakerBuilder = circuit_breaker.CircuitBreakerBuilder;
pub const CircuitBreakerEffect = circuit_breaker.CircuitBreakerEffect;
pub const circuitBreakerBuilder = circuit_breaker.circuitBreaker;

/// Bulkhead - 隔板模式
pub const bulkhead_mod = @import("bulkhead.zig");
pub const Bulkhead = bulkhead_mod.Bulkhead;
pub const BulkheadConfig = bulkhead_mod.BulkheadConfig;
pub const BulkheadError = bulkhead_mod.BulkheadError;
pub const BulkheadStats = bulkhead_mod.BulkheadStats;
pub const BulkheadBuilder = bulkhead_mod.BulkheadBuilder;
pub const BulkheadEffect = bulkhead_mod.BulkheadEffect;
pub const Semaphore = bulkhead_mod.Semaphore;
pub const RejectionPolicy = bulkhead_mod.RejectionPolicy;
pub const bulkheadBuilder = bulkhead_mod.bulkhead;

/// Timeout - 超时控制
pub const timeout_mod = @import("timeout.zig");
pub const ResilienceTimeout = timeout_mod.Timeout;
pub const TimeoutConfig = timeout_mod.TimeoutConfig;
pub const TimeoutError = timeout_mod.TimeoutError;
pub const TimeoutStats = timeout_mod.TimeoutStats;
pub const TimeoutBuilder = timeout_mod.TimeoutBuilder;
pub const TimeoutEffect = timeout_mod.TimeoutEffect;
pub const Deadline = timeout_mod.Deadline;
pub const timeoutBuilder = timeout_mod.timeout;
pub const withTimeout = timeout_mod.withTimeout;

/// Fallback - 降级策略
pub const fallback = @import("fallback.zig");
pub const FallbackStrategy = fallback.FallbackStrategy;
pub const FallbackConfig = fallback.FallbackConfig;
pub const FallbackStats = fallback.FallbackStats;
pub const FallbackResult = fallback.FallbackResult;
pub const FallbackMod = fallback.Fallback;
pub const FallbackChain = fallback.FallbackChain;
pub const CacheFallback = fallback.CacheFallback;
pub const FallbackEffect = fallback.FallbackEffect;
pub const withFallbackValue = fallback.withFallbackValue;
pub const withFallbackFn = fallback.withFallbackFn;
pub const tryOrNull = fallback.tryOrNull;

// ============ 测试 ============

test {
    // 运行所有子模块的测试
    std.testing.refAllDecls(@This());
}

test "Option example" {
    const opt = some(i32, 42);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    const empty = none(i32);
    try std.testing.expect(empty.isNone());
    try std.testing.expectEqual(@as(i32, 0), empty.unwrapOr(0));
}

test "Result example" {
    const Error = enum { NotFound, InvalidInput };

    const success = ok(i32, Error, 42);
    try std.testing.expect(success.isOk());

    const failure = err(i32, Error, .NotFound);
    try std.testing.expect(failure.isErr());
}

test "Pipe example" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result_val = Pipe(i32).init(5)
        .then(i32, double)
        .then(i32, addOne)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 11), result_val);
}

test "compose example" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const composed = compose(i32, i32, i32, double, addOne);
    try std.testing.expectEqual(@as(i32, 12), composed(5)); // double(addOne(5)) = double(6) = 12
}

test "Monoid example" {
    const numbers = [_]i64{ 1, 2, 3, 4, 5 };
    const sum_result = sumMonoid.concat(&numbers);
    try std.testing.expectEqual(@as(i64, 15), sum_result);
}
