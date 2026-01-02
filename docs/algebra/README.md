# Algebra 模块

代数结构，提供可组合操作的数学抽象。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| semigroup.md | `Semigroup` | 半群，结合操作 |
| [monoid.md](monoid.md) | `Monoid` | 幺半群，带单位元的半群 |
| alternative.md | `Alternative` | 选择和重复操作 |
| foldable.md | `Foldable` | 可折叠结构 |
| traversable.md | `Traversable` | 可遍历结构 |
| category.md | Category | 范畴论基础 |

## 导入方式

```zig
const algebra = @import("zigfp").algebra;

const Monoid = algebra.Monoid;
const Semigroup = algebra.Semigroup;
```

## 核心概念

### Semigroup

半群定义了一个结合操作 `combine`。

**法则**:
- 结合律: `combine(combine(a, b), c) = combine(a, combine(b, c))`

```zig
const sumSemigroup = semigroup.sumSemigroup(i32);
const result = sumSemigroup.combine(1, 2);  // 3
```

### Monoid

Monoid 是带有单位元的 Semigroup。

**法则**:
- 左单位元: `combine(empty, a) = a`
- 右单位元: `combine(a, empty) = a`

```zig
const sumMonoid = monoid.sumMonoid;
const result = sumMonoid.concat(&[_]i64{1, 2, 3, 4, 5});  // 15
```

### Foldable

可折叠结构支持将数据归约为单一值。

```zig
const sum = SliceFoldable(i32).foldLeft(
    &[_]i32{1, 2, 3},
    0,
    struct { fn f(acc: i32, x: i32) i32 { return acc + x; } }.f
);
// sum = 6
```

### Traversable

可遍历结构支持带效果的遍历。

```zig
// 遍历切片，如果任何元素返回 None，则整体返回 None
const result = SliceTraversable(i32).traverseOption(
    allocator,
    slice,
    parseIntOption
);
```
