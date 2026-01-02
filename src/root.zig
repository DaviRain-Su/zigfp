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
pub const invalidMany = validation.invalidMany;
pub const Validator = validation.Validator;
pub const validator = validation.validator;
pub const StringError = validation.StringError;
pub const NumberError = validation.NumberError;
pub const notEmpty = validation.notEmpty;
pub const validateAll = validation.validateAll;

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
