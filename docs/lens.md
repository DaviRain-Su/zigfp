# Lens

> 不可变数据更新，聚焦嵌套结构

## 概述

`Lens(S, A)` 是一个可组合的 getter/setter 对，用于访问和更新嵌套数据结构。
它让不可变数据的更新变得简洁且可组合。

## 类型定义

```zig
pub fn Lens(comptime S: type, comptime A: type) type {
    return struct {
        get: *const fn (S) A,
        set: *const fn (S, A) S,
    };
}
```

## 问题场景

传统不可变更新：
```zig
const User = struct {
    name: []const u8,
    address: Address,
};

const Address = struct {
    city: []const u8,
    zip: []const u8,
};

// 更新嵌套字段很繁琐
fn updateCity(user: User, city: []const u8) User {
    return User{
        .name = user.name,
        .address = Address{
            .city = city,
            .zip = user.address.zip,
        },
    };
}
```

使用 Lens：
```zig
const userCity = addressLens.compose(cityLens);
const newUser = userCity.set(user, "New York");
```

## API

### view - 获取值

```zig
/// 获取聚焦的值
pub fn view(self: Self, s: S) A
```

### set / put - 设置值

```zig
/// 设置聚焦的值，返回新结构
pub fn set(self: Self, s: S, a: A) S
pub fn put(self: Self, s: S, a: A) S  // 别名
```

### over - 修改值

```zig
/// 对聚焦的值应用函数
pub fn over(self: Self, s: S, f: *const fn (A) A) S
```

### compose - 组合 Lens

```zig
/// 组合两个 Lens，聚焦更深层
pub fn compose(self: Self, comptime B: type, other: Lens(A, B)) Lens(S, B)
```

## 便捷函数

### field - 字段 Lens

```zig
/// 为结构体字段创建 Lens
pub fn field(comptime S: type, comptime name: []const u8) Lens(S, FieldType(S, name))
```

**使用示例**:

```zig
const User = struct {
    name: []const u8,
    age: i32,
};

const nameLens = fp.field(User, "name");
const ageLens = fp.field(User, "age");

const user = User{ .name = "Alice", .age = 30 };

const name = nameLens.view(user);        // "Alice"
const older = ageLens.over(user, incr);  // User{ .name = "Alice", .age = 31 }
```

## 嵌套示例

```zig
const fp = @import("zigfp");

const Address = struct {
    street: []const u8,
    city: []const u8,
};

const Person = struct {
    name: []const u8,
    address: Address,
};

const Company = struct {
    name: []const u8,
    ceo: Person,
};

// 创建 Lens
const ceoLens = fp.field(Company, "ceo");
const addressLens = fp.field(Person, "address");
const cityLens = fp.field(Address, "city");

// 组合 Lens
const ceoCityLens = ceoLens
    .compose(Address, addressLens)
    .compose([]const u8, cityLens);

// 使用
const company = Company{
    .name = "Acme",
    .ceo = Person{
        .name = "Bob",
        .address = Address{
            .street = "123 Main St",
            .city = "Boston",
        },
    },
};

// 获取
const city = ceoCityLens.view(company);  // "Boston"

// 更新（返回新结构，原结构不变）
const newCompany = ceoCityLens.set(company, "New York");
// company.ceo.address.city 仍是 "Boston"
// newCompany.ceo.address.city 是 "New York"

// 修改
const upperCompany = ceoCityLens.over(company, toUpper);
// upperCompany.ceo.address.city 是 "BOSTON"
```

## Lens 法则

Lens 满足以下法则：

1. **GetPut**: `lens.set(s, lens.get(s)) == s`
   - 设置刚获取的值不改变结构

2. **PutGet**: `lens.get(lens.set(s, a)) == a`
   - 获取刚设置的值返回设置的值

3. **PutPut**: `lens.set(lens.set(s, a), b) == lens.set(s, b)`
   - 连续设置，只有最后一个生效

## 与其他语言对比

| 语言 | 库 | 语法 |
|------|-----|------|
| Haskell | lens | `view` / `set` / `over` |
| Scala | Monocle | `get` / `replace` / `modify` |
| TypeScript | monocle-ts | `get` / `set` / `modify` |
| **Zig** | **zigFP** | `view` / `set` / `over` |

## 性能

- **极低开销**: 结构体浅复制
- **编译时优化**: 内联函数调用

## 源码

`src/lens.zig`
