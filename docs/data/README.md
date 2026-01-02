# Data 模块

数据结构，提供函数式风格的数据容器。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| stream.md | `Stream(T)` | 惰性无限流 |
| zipper.md | `ListZipper`, `TreeZipper` | 可导航数据结构 |
| [iterator.md](iterator.md) | `Iterator(T)` | 函数式迭代器 |
| arrow.md | `Arrow` | 函数抽象 |
| comonad.md | `Comonad` | Monad 的对偶 |

## 导入方式

```zig
const data = @import("zigfp").data;

const Stream = data.stream.Stream;
const ListZipper = data.zipper.ListZipper;
```

## 快速示例

### Stream - 惰性无限流

```zig
// 创建无限自然数流
const nats = Stream(i32).iterate(0, struct {
    fn f(n: i32) i32 { return n + 1; }
}.f);

// 取前 10 个
const first10 = nats.take(allocator, 10);
// [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

### Zipper - 可导航结构

```zig
// 创建列表 zipper
var z = ListZipper(i32).fromSlice(&[_]i32{1, 2, 3, 4, 5});

// 向右移动
z = z.moveRight().?;  // focus = 2

// 修改当前焦点
z = z.modify(struct {
    fn f(x: i32) i32 { return x * 10; }
}.f);  // focus = 20
```

### Iterator - 函数式迭代器

```zig
const doubled = fromSlice(&[_]i32{1, 2, 3, 4, 5})
    .map(i32, struct { fn f(x: i32) i32 { return x * 2; } }.f)
    .filter(struct { fn f(x: i32) bool { return x > 4; } }.f)
    .take(3);
// [6, 8, 10]
```

### Comonad - 上下文计算

Comonad 是 Monad 的对偶，关注"从上下文中提取值"而非"将值放入上下文"。

```zig
const store = Store(i32, i32).init(
    struct { fn f(pos: i32) i32 { return pos * pos; } }.f,
    5
);
const value = store.extract();  // 25
```
