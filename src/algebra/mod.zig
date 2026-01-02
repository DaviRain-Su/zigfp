//! 代数结构模块
//!
//! 提供代数抽象：
//! - Semigroup - 半群
//! - Monoid - 幺半群
//! - Alternative - 选择操作
//! - Foldable - 可折叠结构
//! - Traversable - 可遍历结构
//! - Category - 范畴论基础

const std = @import("std");

pub const semigroup = @import("semigroup.zig");
pub const monoid = @import("monoid.zig");
pub const alternative = @import("alternative.zig");
pub const foldable = @import("foldable.zig");
pub const traversable = @import("traversable.zig");
pub const category = @import("category.zig");

// ============ Semigroup ============
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

// ============ Monoid ============
pub const Monoid = monoid.Monoid;
pub const sumMonoid = monoid.sumMonoid;
pub const productMonoid = monoid.productMonoid;
pub const allMonoid = monoid.allMonoid;
pub const anyMonoid = monoid.anyMonoid;
pub const sumMonoidI32 = monoid.sumMonoidI32;
pub const productMonoidI32 = monoid.productMonoidI32;
pub const maxMonoidI32 = monoid.maxMonoidI32;
pub const minMonoidI32 = monoid.minMonoidI32;

// ============ Alternative ============
pub const emptyOption = alternative.emptyOption;
pub const orOption = alternative.orOption;
pub const manyOption = alternative.manyOption;
pub const someOption = alternative.someOption;
pub const optionalOption = alternative.optionalOption;

// ============ Foldable ============
pub const SliceFoldable = foldable.SliceFoldable;
pub const NumericFoldable = foldable.NumericFoldable;
pub const OptionFoldable = foldable.OptionFoldable;
pub const foldWithMonoid = foldable.foldWithMonoid;
pub const foldLeft = foldable.foldLeft;
pub const foldRight = foldable.foldRight;

// ============ Traversable ============
pub const SliceTraversable = traversable.SliceTraversable;
pub const OptionTraversable = traversable.OptionTraversable;
pub const traverseSliceOption = traversable.traverseSliceOption;
pub const sequenceSliceOption = traversable.sequenceSliceOption;
pub const traverseSliceResult = traversable.traverseSliceResult;
pub const sequenceSliceResult = traversable.sequenceSliceResult;

// ============ Category ============
pub const function_category = category.function_category;
pub const kleisli = category.kleisli;
pub const covariant = category.covariant;
pub const category_laws = category.laws;

test {
    std.testing.refAllDecls(@This());
}
