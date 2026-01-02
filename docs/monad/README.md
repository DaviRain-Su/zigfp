# Monad 模块

Monad 类型家族，提供计算上下文的抽象。

## 模块列表

| 文件 | 类型 | 说明 |
|------|------|------|
| [reader.md](reader.md) | `Reader(Env, T)` | 依赖注入模式 |
| [writer.md](writer.md) | `Writer(W, T)` | 日志/累积模式 |
| [state.md](state.md) | `State(S, T)` | 状态管理 |
| [cont.md](cont.md) | `Cont(R, A)` | Continuation，CPS 风格 |
| [free.md](free.md) | `Free(F, A)` | Free Monad + Trampoline |
| mtl.md | `EitherT`, `OptionT` | Monad Transformers |
| selective.md | Selective | 选择性应用函子 |

## 导入方式

```zig
const monad = @import("zigfp").monad;

const Reader = monad.Reader;
const Writer = monad.Writer;
const State = monad.State;
```

## 快速示例

### Reader - 依赖注入

```zig
const Config = struct { multiplier: i32 };

const computation = Reader(Config, i32).asks(struct {
    fn f(cfg: Config) i32 { return cfg.multiplier * 10; }
}.f);

const result = computation.run(.{ .multiplier = 5 });
// result = 50
```

### Writer - 日志累积

```zig
const w = Writer([]const u8, i32).init(42, "computed value");
const w2 = w.tell(" and logged");
// w2.log = "computed value and logged"
```

### State - 状态管理

```zig
const counter = State(i32, i32).init(struct {
    fn f(s: i32) struct { i32, i32 } {
        return .{ s, s + 1 };
    }
}.f);

const result = counter.run(0);
// result = { value: 0, state: 1 }
```
