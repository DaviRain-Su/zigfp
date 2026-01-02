# Functor 模块

Functor 抽象，提供可映射类型的统一接口。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| functor.md | `Functor`, `Identity` | 可映射的类型构造器 |
| applicative.md | `Applicative` | 应用函子，介于 Functor 和 Monad 之间 |
| bifunctor.md | `Bifunctor` | 双参数 Functor (Pair/Either/These) |
| profunctor.md | `Profunctor` | 逆变/协变 Functor |
| distributive.md | Distributive | 分配律 |

## 导入方式

```zig
const functor = @import("zigfp").functor;

const Identity = functor.functor.Identity;
const OptionApplicative = functor.applicative.OptionApplicative;
```

## 核心概念

### Functor

Functor 是可以被映射的类型构造器。核心操作是 `map`。

**法则**:
- Identity: `map(id) = id`
- Composition: `map(f . g) = map(f) . map(g)`

### Applicative

Applicative 是 Functor 的扩展，支持在上下文中应用函数。

**法则**:
- Identity: `pure(id) <*> v = v`
- Composition: `pure(.) <*> u <*> v <*> w = u <*> (v <*> w)`
- Homomorphism: `pure(f) <*> pure(x) = pure(f(x))`
- Interchange: `u <*> pure(y) = pure($ y) <*> u`

### Bifunctor

Bifunctor 可以同时映射两个类型参数。

```zig
// Pair 是一个 Bifunctor
const p = Pair(i32, []const u8).init(42, "hello");
const mapped = p.bimap(
    struct { fn f(x: i32) i64 { return x * 2; } }.f,
    struct { fn f(s: []const u8) usize { return s.len; } }.f
);
// mapped = (84, 5)
```
