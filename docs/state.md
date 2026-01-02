# State Monad

> 状态管理，纯函数式状态变换

## 概述

`State(S, T)` 表示一个状态变换函数，接受初始状态 `S`，返回值 `T` 和新状态 `S`。
它让我们用纯函数的方式处理有状态的计算。

## 类型定义

```zig
pub fn State(comptime S: type, comptime T: type) type {
    return struct {
        run: *const fn (S) struct { T, S },

        pub fn runState(self: Self, initial: S) struct { T, S } { ... }
        pub fn evalState(self: Self, initial: S) T { ... }
        pub fn execState(self: Self, initial: S) S { ... }
    };
}
```

## 核心思想

传统可变状态:
```zig
var counter: i32 = 0;
fn increment() i32 {
    counter += 1;
    return counter;
}
// 依赖全局可变状态，难以测试和推理
```

State Monad:
```zig
fn increment() State(i32, i32) {
    return State(i32, i32){
        .run = struct {
            fn f(s: i32) struct { i32, i32 } {
                return .{ s + 1, s + 1 };
            }
        }.f,
    };
}
// 状态变换是显式的、纯的
```

## API

### pure - 包装值

```zig
/// 返回值，不改变状态
pub fn pure(v: T) State(S, T)
```

### get - 获取状态

```zig
/// 返回当前状态
pub fn get() State(S, S)
```

### put - 设置状态

```zig
/// 设置新状态
pub fn put(new: S) State(S, void)
```

### modify - 修改状态

```zig
/// 对状态应用函数
pub fn modify(f: *const fn (S) S) State(S, void)
```

### map - Functor

```zig
/// 对返回值应用函数
pub fn map(self: Self, comptime U: type, f: *const fn (T) U) State(S, U)
```

### flatMap - Monad

```zig
/// 链式状态操作
pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) State(S, U)) State(S, U)
```

### 执行函数

```zig
/// 运行状态计算，返回值和最终状态
pub fn runState(self: Self, initial: S) struct { T, S }

/// 只返回值
pub fn evalState(self: Self, initial: S) T

/// 只返回最终状态
pub fn execState(self: Self, initial: S) S
```

## 使用示例

```zig
const fp = @import("zigfp");

// 计数器状态
const Counter = i32;

fn increment() fp.State(Counter, i32) {
    return fp.State(Counter, i32){
        .run = struct {
            fn f(count: Counter) struct { i32, Counter } {
                return .{ count, count + 1 };
            }
        }.f,
    };
}

fn add(n: i32) fp.State(Counter, void) {
    return fp.State(Counter, void).modify(struct {
        fn f(count: Counter) Counter {
            return count + n;
        }
    }.f);
}

// 组合状态操作
const program = increment()
    .flatMap(i32, struct {
        fn f(x: i32) fp.State(Counter, i32) {
            return add(10).flatMap(void, struct {
                fn g(_: void) fp.State(Counter, i32) {
                    return increment();
                }
            }.g);
        }
    }.f);

const result = program.runState(0);
// result[0] = 1 (第二次 increment 的返回值)
// result[1] = 12 (最终状态: 0 + 1 + 10 + 1)
```

## 栈操作示例

```zig
const Stack = ArrayList(i32);

fn push(x: i32) fp.State(Stack, void) {
    return fp.State(Stack, void).modify(struct {
        fn f(stack: Stack) Stack {
            var s = stack;
            s.append(x);
            return s;
        }
    }.f);
}

fn pop() fp.State(Stack, fp.Option(i32)) {
    return fp.State(Stack, fp.Option(i32)){
        .run = struct {
            fn f(stack: Stack) struct { fp.Option(i32), Stack } {
                if (stack.items.len == 0) {
                    return .{ fp.none(i32), stack };
                }
                var s = stack;
                const top = s.pop();
                return .{ fp.some(i32, top), s };
            }
        }.f,
    };
}

// 使用
const program = push(1)
    .flatMap(void, fn(_) { return push(2); })
    .flatMap(void, fn(_) { return push(3); })
    .flatMap(void, fn(_) { return pop(); });

const result = program.runState(Stack.init(allocator));
// result[0] = some(3)
// result[1] = Stack{1, 2}
```

## Monad 法则

State 满足 Monad 法则：

1. **Left Identity**: `pure(a).flatMap(f).runState(s) == f(a).runState(s)`
2. **Right Identity**: `m.flatMap(pure).runState(s) == m.runState(s)`
3. **Associativity**: `m.flatMap(f).flatMap(g) == m.flatMap(x => f(x).flatMap(g))`

## 源码

`src/state.zig`
