//! zigFP - Zig 函数式编程工具库
//!
//! 将函数式语言的核心特性带入 Zig，用函数式风格写高性能代码。
//!
//! ## 核心模块
//! - `core` - 核心类型 (Option, Result, Lazy, Validation)
//! - `monad` - Monad 类型 (Reader, Writer, State, Cont, Free)
//! - `functor` - Functor 抽象 (Functor, Applicative, Bifunctor, Profunctor)
//! - `algebra` - 代数结构 (Semigroup, Monoid, Foldable, Traversable)
//! - `data` - 数据结构 (Stream, Zipper, Iterator, Arrow, Comonad)
//! - `function` - 函数工具 (compose, pipe, memoize)
//! - `effect` - 效果系统 (Effect, IO, FileSystem, Random, Time, Config)
//! - `parser` - 解析器 (Parser, Json, Codec)
//! - `network` - 网络操作 (TCP, UDP, WebSocket, HTTP, ConnectionPool)
//! - `resilience` - 弹性模式 (Retry, CircuitBreaker, Bulkhead, Timeout, Fallback)
//! - `concurrent` - 并发工具 (Parallel, Benchmark)
//! - `util` - 实用工具 (Auth, I18n, Schema)
//! - `optics` - 光学类型 (Lens, Iso, Prism)

const std = @import("std");

// ============ 子模块导入 ============

/// 核心类型模块 - Option, Result, Lazy, Validation
pub const core = @import("core/mod.zig");

/// Monad 模块 - Reader, Writer, State, Cont, Free, MTL, Selective
pub const monad = @import("monad/mod.zig");

/// Functor 模块 - Functor, Applicative, Bifunctor, Profunctor, Distributive
pub const functor = @import("functor/mod.zig");

/// 代数结构模块 - Semigroup, Monoid, Alternative, Foldable, Traversable, Category
pub const algebra = @import("algebra/mod.zig");

/// 数据结构模块 - Stream, Zipper, Iterator, Arrow, Comonad
pub const data = @import("data/mod.zig");

/// 函数工具模块 - compose, pipe, memoize
pub const function = @import("function/mod.zig");

/// 效果系统模块 - Effect, IO, FileSystem, Random, Time, Config
pub const effect = @import("effect/mod.zig");

/// 解析器模块 - Parser, Json, Codec
pub const parser = @import("parser/mod.zig");

/// 网络模块 - TCP, UDP, WebSocket, HTTP, ConnectionPool, Network
pub const network = @import("network/mod.zig");

/// 弹性模式模块 - Retry, CircuitBreaker, Bulkhead, Timeout, Fallback
pub const resilience = @import("resilience/mod.zig");

/// 并发模块 - Parallel, Benchmark
pub const concurrent = @import("concurrent/mod.zig");

/// 工具模块 - Auth, I18n, Schema
pub const util = @import("util/mod.zig");

/// 光学模块 - Lens, Iso, Prism, Affine
pub const optics = @import("optics/mod.zig");

/// Prelude - 常用函数和类型别名
pub const prelude = @import("prelude.zig");

// ============ 核心类型便捷导出 ============

// Core
pub const Option = core.Option;
pub const some = core.some;
pub const none = core.none;
pub const Result = core.Result;
pub const ok = core.ok;
pub const err = core.err;
pub const Lazy = core.Lazy;
pub const Validation = core.Validation;
pub const valid = core.valid;
pub const invalid = core.invalid;

// Function
pub const compose = function.compose;
pub const identity = function.identity;
pub const flip = function.flip;
pub const Pipe = function.Pipe;
pub const pipe = function.pipe;
pub const Memoized = function.Memoized;
pub const memoize = function.memoizeFn;

// Monad
pub const Reader = monad.Reader;
pub const Writer = monad.Writer;
pub const State = monad.State;
pub const Cont = monad.Cont;
pub const Free = monad.Free;
pub const ask = monad.ask;
pub const asks = monad.asks;
pub const tell = monad.tell;
pub const get = monad.get;
pub const modify = monad.modify;

// Algebra
pub const Monoid = algebra.Monoid;
pub const Semigroup = algebra.Semigroup;
pub const sumMonoid = algebra.monoid.sumMonoid;
pub const productMonoid = algebra.monoid.productMonoid;

// Optics
pub const Lens = optics.Lens;
pub const Iso = optics.Iso;
pub const Prism = optics.Prism;

// Effect
pub const IO = effect.IO;
pub const Effect = effect.Effect;

// Parser
pub const Parser = parser.Parser;
pub const JsonValue = parser.JsonValue;

// Network
pub const TcpConfig = network.TcpConfig;
pub const TcpClient = network.TcpClient;
pub const UdpConfig = network.UdpConfig;
pub const UdpSocket = network.UdpSocket;
pub const WebSocketConfig = network.WebSocketConfig;
pub const WebSocketClient = network.WebSocketClient;
pub const HttpMethod = network.HttpMethod;
pub const HttpStatus = network.HttpStatus;
pub const HttpConfig = network.HttpConfig;
pub const HttpRequest = network.HttpRequest;
pub const HttpResponse = network.HttpResponse;
pub const ConnectionPoolConfig = network.ConnectionPoolConfig;
pub const ConnectionPool = network.ConnectionPool;

// Resilience
pub const RetryStrategy = resilience.RetryStrategy;
pub const RetryConfig = resilience.RetryConfig;
pub const RetryStats = resilience.RetryStats;
pub const RetryPolicy = resilience.RetryPolicy;
pub const RetryPolicyBuilder = resilience.RetryPolicyBuilder;
pub const retryPolicy = resilience.retryPolicy;
pub const CircuitState = resilience.CircuitState;
pub const CircuitBreakerConfig = resilience.CircuitBreakerConfig;
pub const CircuitStats = resilience.CircuitStats;
pub const CircuitBreaker = resilience.CircuitBreaker;
pub const CircuitBreakerBuilder = resilience.CircuitBreakerBuilder;
pub const circuitBreaker = resilience.circuitBreaker;
pub const BulkheadConfig = resilience.BulkheadConfig;
pub const BulkheadStats = resilience.BulkheadStats;
pub const Bulkhead = resilience.Bulkhead;
pub const TimeoutConfig = resilience.TimeoutConfig;
pub const TimeoutStats = resilience.TimeoutStats;
pub const Timeout = resilience.Timeout;
pub const FallbackStrategy = resilience.FallbackStrategy;
pub const FallbackConfig = resilience.FallbackConfig;
pub const FallbackStats = resilience.FallbackStats;
pub const Fallback = resilience.Fallback;

// Concurrent - Sequential operations
pub const seqMap = concurrent.seqMap;
pub const seqFilter = concurrent.seqFilter;
pub const seqReduce = concurrent.seqReduce;
pub const seqFold = concurrent.seqFold;
pub const seqZip = concurrent.seqZip;

// Concurrent - Batch operations
pub const BatchConfig = concurrent.BatchConfig;
pub const batchMap = concurrent.batchMap;
pub const batchReduce = concurrent.batchReduce;

// Concurrent - Par Monad
pub const Par = concurrent.Par;
pub const parZip = concurrent.parZip;
pub const parSequence = concurrent.parSequence;

// Concurrent - Real Thread Pool
pub const RealThreadPoolConfig = concurrent.RealThreadPoolConfig;
pub const RealThreadPool = concurrent.RealThreadPool;
pub const realParMap = concurrent.realParMap;
pub const realParFilter = concurrent.realParFilter;
pub const realParReduce = concurrent.realParReduce;

// Concurrent - Benchmark
pub const BenchmarkResult = concurrent.BenchmarkResult;

// Util
pub const BasicAuth = util.BasicAuth;
pub const Locale = util.Locale;
pub const Schema = util.Schema;

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
    const sum_result = algebra.monoid.sumMonoid.concat(&numbers);
    try std.testing.expectEqual(@as(i64, 15), sum_result);
}
