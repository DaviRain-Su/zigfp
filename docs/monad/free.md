# Free Monad

> 将任何 Functor 提升为 Monad，构建可解释的 DSL

## 概述

Free Monad 是函数式编程中的高级抽象，它允许：

1. 将程序表示为数据结构
2. 延迟执行，允许不同的解释器
3. 分离程序描述和执行

这非常适合构建 DSL（领域特定语言）、测试和效果隔离。

## 核心概念

### Free Monad 结构

```
Free F A = Pure A | Suspend (F (Free F A))
```

- `Pure`: 包装一个纯值，计算结束
- `Suspend`: 挂起一个操作，等待解释

### 在 zigFP 中

```zig
const fp = @import("zigfp");

// Free Monad 类型
const MyFree = fp.Free(MyFunctor, ResultType);

// 创建纯值
const pure_val = MyFree.pure(42);

// 挂起操作
const suspended = MyFree.liftF(my_operation);
```

## Trampoline - 栈安全递归

Trampoline 是 Free Monad 的简化形式，用于实现栈安全的递归。

### 基本用法

```zig
const fp = @import("zigfp");

// 创建完成的 Trampoline
const done = fp.Trampoline(i32).done(42);
const result = done.run();  // 42

// 创建延迟的 Trampoline
const delayed = fp.Trampoline(i32).more(struct {
    fn next() fp.Trampoline(i32) {
        return fp.Trampoline(i32).done(100);
    }
}.next);
const result2 = delayed.run();  // 100
```

### 递归示例

```zig
// 传统递归 - 可能栈溢出
fn factorial(n: u64) u64 {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// Trampoline 版本 - 栈安全
fn factorialTrampoline(n: u64, acc: u64) Trampoline(u64) {
    if (n <= 1) {
        return Trampoline(u64).done(acc);
    }
    // 返回延迟计算，而非递归调用
    return Trampoline(u64).more(struct {
        fn next() Trampoline(u64) {
            return factorialTrampoline(n - 1, n * acc);
        }
    }.next);
}

// 使用
const result = factorialTrampoline(10000, 1).run();
```

## Program DSL

`Program` 是一个简化的 DSL 示例，展示如何用 Free Monad 构建程序。

```zig
const fp = @import("zigfp");

// 创建打印操作
const printHello = fp.Program(void).print("Hello, World!");

// 创建返回值
const pure42 = fp.Program(i32).pure(42);

// 链接程序
const combined = printHello.andThen(pure42);
```

## Console DSL

更复杂的 Console DSL 示例：

```zig
const fp = @import("zigfp");

// Console 操作类型
// - print: 打印消息
// - read: 读取输入

// 打印消息
const io1 = fp.printLine("Enter your name:");

// 读取输入
const io2 = fp.readLine("Name: ");
```

## 解释器模式

Free Monad 的强大之处在于可以用不同的解释器执行同一程序：

```zig
// 程序描述（与执行分离）
const program = myDSL()
    .print("Hello")
    .read()
    .print("Goodbye");

// 生产环境解释器 - 真实 IO
fn realInterpreter(prog: MyProgram) !void {
    switch (prog) {
        .print => |msg| try stdout.print("{s}\n", .{msg}),
        .read => return try stdin.readLine(),
        // ...
    }
}

// 测试解释器 - 模拟 IO
fn testInterpreter(prog: MyProgram, testInput: []const u8) []const u8 {
    switch (prog) {
        .print => |_| {},  // 忽略输出
        .read => return testInput,  // 返回测试输入
        // ...
    }
}
```

## 使用场景

### 1. 效果隔离

将副作用描述为数据，便于测试和推理。

```zig
// 描述副作用，不执行
const effects = myProgram();

// 测试时使用模拟解释器
const result = testInterpreter(effects, mockData);

// 生产时使用真实解释器
const result = realInterpreter(effects);
```

### 2. 构建 DSL

为特定领域创建表达力强的语言。

```zig
// 数据库 DSL
const query = db()
    .select("users")
    .where("age > 18")
    .orderBy("name");

// 解释为 SQL
const sql = sqlInterpreter(query);

// 解释为内存查询
const results = memoryInterpreter(query, data);
```

### 3. 工作流编排

描述复杂的业务流程。

```zig
const workflow = process()
    .validateInput()
    .processPayment()
    .sendNotification()
    .updateDatabase();
```

## 与其他语言对比

| 概念 | Haskell | Scala | zigFP |
|------|---------|-------|-------|
| Free Monad | `Free f a` | `Free[F, A]` | `Free(F, A)` |
| 纯值 | `Pure a` | `Pure(a)` | `pure(a)` |
| 挂起 | `Free (f (Free f a))` | `Suspend(fa)` | `liftF(op)` |
| Trampoline | `Trampoline a` | `Trampoline[A]` | `Trampoline(A)` |

## 限制

由于 Zig 不支持闭包和高阶类型，zigFP 的 Free Monad 有以下限制：

1. **Functor 必须是类型函数**：`fn (type) type`
2. **解释器需要手动实现**：无法自动派生
3. **组合受限**：flatMap 需要编译时已知的函数

## 源码

`src/free.zig`
