//! 数据结构模块
//!
//! 提供函数式数据结构：
//! - Stream - 惰性流
//! - Zipper - 可导航结构
//! - Iterator - 函数式迭代器
//! - Arrow - 箭头抽象
//! - Comonad - 余单子

const std = @import("std");

pub const stream = @import("stream.zig");
pub const zipper = @import("zipper.zig");
pub const iterator = @import("iterator.zig");
pub const arrow = @import("arrow.zig");
pub const comonad = @import("comonad.zig");

// ============ Stream ============
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

// ============ Zipper ============
pub const ListZipper = zipper.ListZipper;
pub const BinaryTree = zipper.BinaryTree;
pub const TreeZipper = zipper.TreeZipper;
pub const listZipper = zipper.listZipper;
pub const treeZipper = zipper.treeZipper;

// ============ Iterator ============
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

// ============ Arrow ============
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

// ============ Comonad ============
pub const Identity = comonad.Identity;
pub const NonEmpty = comonad.NonEmpty;
pub const Store = comonad.Store;
pub const Env = comonad.Env;
pub const Traced = comonad.Traced;

test {
    std.testing.refAllDecls(@This());
}
