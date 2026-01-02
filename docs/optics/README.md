# Optics 模块

光学类型，提供数据结构焦点的组合式访问和更新。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [lens.md](lens.md) | `Lens(S, A)` | 聚焦结构字段 |
| optics.md | `Iso`, `Prism`, `Affine` | 完整光学类型系统 |

## 导入方式

```zig
const optics = @import("zigfp").optics;

const Lens = optics.Lens;
const Iso = optics.Iso;
const Prism = optics.Prism;
```

## 光学类型层次

```
     Iso
      |
    Prism --- Lens
      |        |
   Affine ----+
      |
  Traversal
      |
    Fold
```

## 快速示例

### Lens - 聚焦字段

```zig
const Person = struct { name: []const u8, age: i32 };

const ageLens = Lens(Person, i32).init(
    struct { fn get(p: Person) i32 { return p.age; } }.get,
    struct { fn set(p: Person, a: i32) Person {
        return .{ .name = p.name, .age = a };
    } }.set
);

const person = Person{ .name = "Alice", .age = 30 };
const age = ageLens.view(person);           // 30
const older = ageLens.put(person, 31);      // { "Alice", 31 }
const birthday = ageLens.over(person, addOne);  // { "Alice", 31 }
```

### Iso - 同构

```zig
// Celsius <-> Fahrenheit 同构
const tempIso = Iso(f64, f64).init(
    struct { fn to(c: f64) f64 { return c * 9.0 / 5.0 + 32.0; } }.to,
    struct { fn from(f: f64) f64 { return (f - 32.0) * 5.0 / 9.0; } }.from
);

const fahrenheit = tempIso.to(100.0);   // 212.0
const celsius = tempIso.from(32.0);     // 0.0
```

### Prism - 部分同构

```zig
// Option 的 Some Prism
const somePrism = Prism(Option(i32), i32).init(
    struct { fn preview(opt: Option(i32)) ?i32 {
        return if (opt.isSome()) opt.unwrap() else null;
    } }.preview,
    struct { fn review(x: i32) Option(i32) {
        return Option(i32).Some(x);
    } }.review
);
```

### Affine - 可选焦点

```zig
// 数组头元素的 Affine
const headAffine = Affine([]const i32, i32).init(
    struct { fn preview(arr: []const i32) ?i32 {
        return if (arr.len > 0) arr[0] else null;
    } }.preview,
    struct { fn set(arr: []const i32, x: i32) []const i32 {
        if (arr.len == 0) return arr;
        // 实际实现需要分配新数组
        return arr;
    } }.set
);
```

## Lens 法则

1. **GetPut**: `set(s, get(s)) = s`
2. **PutGet**: `get(set(s, a)) = a`
3. **PutPut**: `set(set(s, a), b) = set(s, b)`
