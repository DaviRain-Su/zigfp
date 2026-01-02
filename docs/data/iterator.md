# Iterator - 函数式迭代器

> 增强的迭代器操作，支持函数式链式调用

## 概述

`Iterator` 模块提供了类似于 Rust Iterator trait 或 Haskell list 操作的函数式迭代器。
支持 `map`、`filter`、`fold`、`take`、`skip` 等常用操作。

## 核心类型

### SliceIterator

从切片创建的迭代器，是最基础的迭代器类型。

```zig
const fp = @import("zigfp");

const data = [_]i32{ 1, 2, 3, 4, 5 };
var iter = fp.fromSlice(i32, &data);

while (iter.next()) |item| {
    // 处理每个元素
}
```

### RangeIterator

生成数字范围的迭代器。

```zig
// 0, 1, 2, 3, 4
var iter = fp.range(i32, 0, 5);

// 0, 2, 4, 6, 8 (步长为 2)
var iter2 = fp.rangeStep(i32, 0, 10, 2);
```

### MapIterator

对每个元素应用转换函数。

```zig
const data = [_]i32{ 1, 2, 3 };
var source = fp.fromSlice(i32, &data);

const double = struct {
    fn f(x: i32) i32 { return x * 2; }
}.f;

var mapped = fp.MapIterator(i32, i32).init(&source, double);
// 输出: 2, 4, 6
```

### FilterIterator

过滤满足条件的元素。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5, 6 };
var source = fp.fromSlice(i32, &data);

const isEven = struct {
    fn f(x: i32) bool { return @mod(x, 2) == 0; }
}.f;

var filtered = fp.FilterIterator(i32).init(&source, isEven);
// 输出: 2, 4, 6
```

### TakeIterator / SkipIterator

取前 n 个元素或跳过前 n 个元素。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5 };

// 取前 3 个: 1, 2, 3
var source1 = fp.fromSlice(i32, &data);
var taken = fp.TakeIterator(i32).init(&source1, 3);

// 跳过前 2 个: 3, 4, 5
var source2 = fp.fromSlice(i32, &data);
var skipped = fp.SkipIterator(i32).init(&source2, 2);
```

### ZipIterator

合并两个迭代器为元组对。

```zig
const names = [_][]const u8{ "Alice", "Bob", "Charlie" };
const ages = [_]i32{ 25, 30, 35 };

var iter1 = fp.fromSlice([]const u8, &names);
var iter2 = fp.fromSlice(i32, &ages);
var zipped = fp.ZipIterator([]const u8, i32).init(&iter1, &iter2);

// 输出: ("Alice", 25), ("Bob", 30), ("Charlie", 35)
```

### EnumerateIterator

为每个元素添加索引。

```zig
const data = [_]i32{ 10, 20, 30 };
var source = fp.fromSlice(i32, &data);
var enumerated = fp.EnumerateIterator(i32).init(&source);

// 输出: (0, 10), (1, 20), (2, 30)
```

### RepeatIterator

无限重复某个值。

```zig
var iter = fp.repeat(i32, 42);

// 取前 5 个
var list = try iter.take(5, allocator);
defer list.deinit(allocator);
// list.items = { 42, 42, 42, 42, 42 }
```

## 终端操作

### fold / reduce

折叠/归约操作。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5 };
var iter = fp.fromSlice(i32, &data);

const result = iter.fold(i32, 0, struct {
    fn add(acc: i32, x: i32) i32 { return acc + x; }
}.add);
// result = 15
```

### sum / product

求和与求积。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5 };

var iter1 = fp.fromSlice(i32, &data);
const sum = iter1.sum();  // 15

var iter2 = fp.fromSlice(i32, &data);
const product = iter2.product();  // 120
```

### max / min

获取最大/最小值。

```zig
const data = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
var iter1 = fp.fromSlice(i32, &data);
var iter2 = fp.fromSlice(i32, &data);

const max = iter1.max();  // 9
const min = iter2.min();  // 1
```

### find

查找满足条件的第一个元素。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5 };
var iter = fp.fromSlice(i32, &data);

const isEven = struct {
    fn f(x: i32) bool { return @mod(x, 2) == 0; }
}.f;

const found = iter.find(isEven);  // 2
```

### all / any

检查是否所有/存在元素满足条件。

```zig
const data = [_]i32{ 2, 4, 6, 8 };
var iter1 = fp.fromSlice(i32, &data);
var iter2 = fp.fromSlice(i32, &data);

const isEven = struct {
    fn f(x: i32) bool { return @mod(x, 2) == 0; }
}.f;

const allEven = iter1.all(isEven);  // true
const anyOdd = iter2.any(struct {
    fn f(x: i32) bool { return @mod(x, 2) != 0; }
}.f);  // false
```

### collect

收集到 ArrayList。

```zig
const data = [_]i32{ 1, 2, 3 };
var iter = fp.fromSlice(i32, &data);

var list = try iter.collect(allocator);
defer list.deinit(allocator);
```

### count

计数元素数量。

```zig
const data = [_]i32{ 1, 2, 3, 4, 5 };
var iter = fp.fromSlice(i32, &data);
const n = iter.count();  // 5
```

## 与其他语言对比

| 操作 | Rust | Haskell | zigFP |
|------|------|---------|-------|
| 创建 | `iter()` | - | `fromSlice()` |
| 映射 | `map()` | `map` | `MapIterator` |
| 过滤 | `filter()` | `filter` | `FilterIterator` |
| 折叠 | `fold()` | `foldl` | `fold()` |
| 取前n | `take()` | `take` | `TakeIterator` |
| 跳过n | `skip()` | `drop` | `SkipIterator` |
| 合并 | `zip()` | `zip` | `ZipIterator` |
| 索引 | `enumerate()` | `zip [0..]` | `EnumerateIterator` |
| 范围 | `0..5` | `[0..4]` | `range(0, 5)` |

## 注意事项

1. **迭代器是消耗性的**：一旦遍历完成，需要重新创建
2. **使用 `reset()` 重置**：`SliceIterator` 支持 `reset()` 方法
3. **内存管理**：`collect()` 返回的 ArrayList 需要手动释放

## 源码

`src/iterator.zig`
