//! 函子相关抽象模块
//!
//! 提供各种函子类型：
//! - Functor - 可映射类型
//! - Applicative - 应用函子
//! - Bifunctor - 双参数函子
//! - Profunctor - 逆变/协变函子
//! - Distributive - 分配律

const std = @import("std");

pub const functor = @import("functor.zig");
pub const applicative = @import("applicative.zig");
pub const bifunctor = @import("bifunctor.zig");
pub const profunctor = @import("profunctor.zig");
pub const distributive = @import("distributive.zig");
pub const natural = @import("natural.zig");

// ============ Functor ============
pub const FunctorIdentity = functor.Identity;
pub const optionFunctor = functor.optionFunctor;
pub const identityFunctor = functor.identityFunctor;

// ============ Applicative ============
pub const OptionApplicative = applicative.OptionApplicative;
pub const ResultApplicative = applicative.ResultApplicative;
pub const ListApplicative = applicative.ListApplicative;
pub const liftA2Option = applicative.liftA2Option;
pub const liftA3Option = applicative.liftA3Option;
pub const liftA2Result = applicative.liftA2Result;

// ============ Bifunctor ============
pub const BifunctorPair = bifunctor.Pair;
pub const BifunctorEither = bifunctor.Either;
pub const ResultBifunctor = bifunctor.ResultBifunctor;
pub const These = bifunctor.These;
pub const pair = bifunctor.pair;
pub const left = bifunctor.left;
pub const right = bifunctor.right;

// ============ Profunctor ============
pub const FunctionProfunctor = profunctor.FunctionProfunctor;
pub const Star = profunctor.Star;
pub const Costar = profunctor.Costar;
pub const UpStar = profunctor.UpStar;
pub const StrongProfunctor = profunctor.StrongProfunctor;
pub const ChoiceProfunctor = profunctor.ChoiceProfunctor;
pub const profunctorFn = profunctor.profunctor;
pub const dimapFn = profunctor.dimap;
pub const lmapFn = profunctor.lmapFn;
pub const rmapFn = profunctor.rmapFn;
pub const starFn = profunctor.star;
pub const costarFn = profunctor.costar;

// ============ Distributive ============
pub const distributeOption = distributive.distributeOption;
pub const codistributeOption = distributive.codistributeOption;
pub const distributePairOption = distributive.distributePairOption;

// ============ Natural Transformation ============
pub const optionToResult = natural.optionToResult;
pub const resultToOption = natural.resultToOption;
pub const resultErrToOption = natural.resultErrToOption;
pub const sliceHeadOption = natural.sliceHeadOption;
pub const sliceLastOption = natural.sliceLastOption;
pub const sliceAtOption = natural.sliceAtOption;
pub const flattenOption = natural.flattenOption;
pub const flattenResult = natural.flattenResult;
pub const safeCast = natural.safeCast;
pub const fromNullable = natural.fromNullable;
pub const toNullable = natural.toNullable;

test {
    std.testing.refAllDecls(@This());
}
