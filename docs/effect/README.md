# Effect 模块

效果系统，提供副作用的函数式抽象。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [effect.md](effect.md) | `Effect` | 代数效果系统基础 |
| [io.md](io.md) | `IO(T)` | IO 效果，控制台操作 |
| file_system.md | `FileSystemEffect` | 文件系统效果 |
| random.md | `RandomEffect` | 随机数效果 |
| time.md | `TimeEffect` | 时间效果 |
| config.md | `ConfigEffect` | 配置效果 |

## 导入方式

```zig
const effect = @import("zigfp").effect;

const IO = effect.IO;
const Effect = effect.Effect;
const FileSystemEffect = effect.file_system.FileSystemEffect;
```

## 核心概念

### Effect System

代数效果系统将副作用从纯计算中分离出来：

```zig
// 定义效果
const myEffect = Effect(MyOp, i32).pure(42)
    .flatMap(MyOp, i32, struct {
        fn f(x: i32) Effect(MyOp, i32) {
            return Effect(MyOp, i32).perform(.{ .log = "computed" });
        }
    }.f);

// 使用 Handler 解释效果
const result = handler.run(myEffect);
```

### IO - 控制台操作

```zig
const program = IO(void).putStrLn("Hello, World!")
    .then(IO([]const u8).getLine())
    .flatMap(void, []const u8, struct {
        fn f(input: []const u8) IO(void) {
            return IO(void).putStrLn(input);
        }
    }.f);

program.run();
```

### FileSystem - 文件操作

```zig
const content = try FileSystemEffect.readFile(allocator, "config.json");
defer allocator.free(content);

try FileSystemEffect.writeFile("output.txt", "Hello, File!");
```

### Random - 随机数

```zig
const randomInt = RandomEffect.randomInt(i32, 1, 100);
const randomFloat = RandomEffect.randomFloat(0.0, 1.0);
const shuffled = RandomEffect.shuffle(allocator, items);
```

### Time - 时间操作

```zig
const now = TimeEffect.currentTime();
const duration = TimeEffect.measure(someExpensiveOperation);
try TimeEffect.sleep(Duration.fromMillis(100));
```
