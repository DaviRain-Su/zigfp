//! Monad Transformers 模块
//!
//! Monad Transformer 允许组合不同的 Monad，为基础 Monad 添加额外功能。
//! 这实现了 Monad 的垂直组合，而 Applicative Functor 实现了水平组合。
//!
//! 支持的 Transformer:
//! - EitherT(M, E, A) - 为 M 添加 Either 错误处理
//! - OptionT(M, A) - 为 M 添加 Option 空值处理
//! - StateT(M, S, A) - 为 M 添加状态管理
//! - ReaderT(M, R, A) - 为 M 添加环境读取
//! - WriterT(M, W, A) - 为 M 添加日志累积
//!
//! 核心操作:
//! - lift - 将基础 Monad 提升到 Transformer
//! - hoist - 在相同 Transformer 类型间转换基础 Monad
//! - run - 运行 Transformer 获得基础 Monad

const std = @import("std");
const Option = @import("option.zig").Option;
const Result = @import("result.zig").Result;

/// Identity Monad - 最简单的 Monad，用于构建其他 Monad
pub fn Identity(comptime A: type) type {
    return struct {
        value: A,

        const Self = @This();

        pub fn pure(a: A) Self {
            return Self{ .value = a };
        }

        pub fn map(comptime B: type, self: Self, f: *const fn (A) B) Identity(B) {
            return Identity(B){ .value = f(self.value) };
        }

        pub fn bind(comptime B: type, self: Self, f: *const fn (A) Identity(B)) Identity(B) {
            return f(self.value);
        }

        pub fn run(self: Self) A {
            return self.value;
        }
    };
}

/// EitherT(M, E, A) - Either Monad Transformer
/// 将 Either 功能添加到任意 Monad M
pub fn EitherT(comptime M: type, comptime E: type, comptime A: type) type {
    return struct {
        /// 内部 Monad 类型: M(Either(E, A))
        inner: M,

        const Self = @This();

        /// 创建 EitherT 的构造函数
        pub fn init(inner: M) Self {
            return Self{ .inner = inner };
        }

        /// 从 Either 值创建 EitherT
        pub fn fromEither(either: Result(A, E)) M {
            return switch (either) {
                .ok => |a| M.pure(Result(A, E).ok(a)),
                .err => |e| M.pure(Result(A, E).err(e)),
            };
        }

        /// 提升基础 Monad 到 EitherT
        pub fn lift(base_monad: anytype) Self {
            const lifted = M.map(base_monad, struct {
                fn toEither(a: @TypeOf(base_monad).T) Result(@TypeOf(base_monad).T, E) {
                    return Result(@TypeOf(base_monad).T, E).ok(a);
                }
            }.toEither);
            return Self.init(lifted);
        }

        /// 绑定操作 - EitherT 的 >>= 实现
        pub fn bind(self: Self, f: *const fn (A) Self) Self {
            const new_inner = M.bind(self.inner, struct {
                const F = @TypeOf(f);
                const CapturedSelf = Self;

                fn bindFn(either: Result(A, E)) M {
                    return switch (either) {
                        .ok => |a| f(a).inner,
                        .err => |e| M.pure(Result(A, E).err(e)),
                    };
                }
            }.bindFn);

            return Self.init(new_inner);
        }

        /// 函子映射
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) EitherT(M, E, B) {
            const new_inner = M.map(Result(B, E), self.inner, struct {
                fn mapFn(either: Result(A, E)) Result(B, E) {
                    return switch (either) {
                        .ok => |a| .{ .ok = f(a) },
                        .err => |e| .{ .err = e },
                    };
                }
            }.mapFn);

            return EitherT(M, E, B).init(new_inner);
        }

        /// 应用函子 - 应用 EitherT 包含的函数
        pub fn apply(self: Self, comptime B: type, f_eithert: EitherT(M, E, *const fn (A) B)) EitherT(M, E, B) {
            const new_inner = M.bind(self.inner, struct {
                const FEitherT = @TypeOf(f_eithert);
                const CapturedSelf = Self;

                fn applyFn(either: Result(A, E)) M {
                    return switch (either) {
                        .ok => |a| M.bind(f_eithert.inner, struct {
                            fn applyFn2(f_either: Result(*const fn (A) B, E)) Result(B, E) {
                                return switch (f_either) {
                                    .ok => |f| Result(B, E).ok(f(a)),
                                    .err => |e| Result(B, E).err(e),
                                };
                            }
                        }.applyFn2),
                        .err => |e| M.pure(Result(B, E).err(e)),
                    };
                }
            }.applyFn);

            return EitherT(M, E, B).init(new_inner);
        }

        /// 运行 EitherT 获得基础 Monad
        pub fn run(self: Self) M {
            return self.inner;
        }
    };
}

/// OptionT(M, A) - Option Monad Transformer
/// 将 Option 功能添加到任意 Monad M
pub fn OptionT(comptime M: type, comptime A: type) type {
    return struct {
        /// 内部 Monad 类型: M(Option(A))
        inner: M,

        const Self = @This();

        /// 创建 OptionT 的构造函数
        pub fn init(inner: M) Self {
            return Self{ .inner = inner };
        }

        /// 从 Option 值创建 OptionT
        pub fn fromOption(opt: Option(A)) M {
            return M.pure(opt);
        }

        /// 提升基础 Monad 到 OptionT
        pub fn lift(base_monad: anytype) Self {
            const lifted = M.map(base_monad, struct {
                fn toOption(a: @TypeOf(base_monad).T) Option(@TypeOf(base_monad).T) {
                    return Option(@TypeOf(base_monad).T).Some(a);
                }
            }.toOption);
            return Self.init(lifted);
        }

        /// 绑定操作
        pub fn bind(self: Self, f: *const fn (A) Self) Self {
            const new_inner = M.bind(self.inner, struct {
                const F = @TypeOf(f);
                const CapturedSelf = Self;

                fn bindFn(opt: Option(A)) M {
                    return switch (opt) {
                        .some => |a| f(a).inner,
                        .none => M.pure(Option(A).None()),
                    };
                }
            }.bindFn);

            return Self.init(new_inner);
        }

        /// 函子映射
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) OptionT(M, B) {
            const new_inner = M.map(Option(B), self.inner, struct {
                fn mapFn(opt: Option(A)) Option(B) {
                    return switch (opt) {
                        .some => |a| .{ .some = f(a) },
                        .none => .none,
                    };
                }
            }.mapFn);

            return OptionT(M, B).init(new_inner);
        }

        /// 运行 OptionT 获得基础 Monad
        pub fn run(self: Self) M {
            return self.inner;
        }
    };
}

/// StateT(M, S, A) - State Monad Transformer
/// 将 State 功能添加到任意 Monad M
pub fn StateT(comptime M: type, comptime S: type, comptime A: type) type {
    return struct {
        /// 内部函数: S → M(struct { A, S })
        run: *const fn (S) M,

        const Self = @This();

        /// 创建 StateT 的构造函数
        pub fn init(run_fn: *const fn (S) M) Self {
            return Self{ .run = run_fn };
        }

        /// 从状态函数创建 StateT
        pub fn fromState(comptime state_fn: *const fn (S) struct { A, S }) Self {
            return Self.init(struct {
                fn stateRunner(s: S) M {
                    const result = state_fn(s);
                    return M.pure(result);
                }
            }.stateRunner);
        }

        /// 提升基础 Monad 到 StateT
        pub fn lift(base_monad: anytype) Self {
            return Self.init(struct {
                const BaseMonad = @TypeOf(base_monad);
                fn liftedRunner(s: S) M {
                    const result = M.bind(base_monad, struct {
                        fn bindFn(a: BaseMonad.T) struct { BaseMonad.T, S } {
                            return .{ a, s };
                        }
                    }.bindFn);
                    return result;
                }
            }.liftedRunner);
        }

        /// 绑定操作
        pub fn bind(self: Self, f: *const fn (A) Self) Self {
            return Self.init(struct {
                const F = @TypeOf(f);
                const CapturedSelf = Self;

                fn bindRunner(s: S) M {
                    const ma = self.run(s);
                    return M.bind(ma, struct {
                        fn bindFn(state_result: struct { A, S }) M {
                            const a = state_result[0];
                            const new_s = state_result[1];
                            const next_transformer = f(a);
                            return next_transformer.run(new_s);
                        }
                    }.bindFn);
                }
            }.bindRunner);
        }

        /// 函子映射
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) StateT(M, S, B) {
            return StateT(M, S, B).init(struct {
                fn mapRunner(s: S) M {
                    const ma = self.run(s);
                    return M.map(@TypeOf(ma).T, ma, struct {
                        fn mapFn(state_result: @TypeOf(ma).T) @TypeOf(ma).T {
                            const a = state_result[0];
                            const s2 = state_result[1];
                            return .{ f(a), s2 };
                        }
                    }.mapFn);
                }
            }.mapRunner);
        }

        /// 获取当前状态
        pub fn get() Self {
            return Self.init(struct {
                fn getRunner(s: S) M {
                    return M.pure(.{ s, s });
                }
            }.getRunner);
        }

        /// 设置新状态
        pub fn put(new_state: S) Self {
            return Self.init(struct {
                fn putRunner(s: S) M {
                    _ = s;
                    return M.pure(.{ {}, new_state });
                }
            }.putRunner);
        }

        /// 修改状态
        pub fn modify(f: *const fn (S) S) Self {
            return Self.init(struct {
                fn modifyRunner(s: S) M {
                    const new_s = f(s);
                    return M.pure(.{ {}, new_s });
                }
            }.modifyRunner);
        }

        /// 运行 StateT
        pub fn runStateT(self: Self, initial_state: S) M {
            return self.run(initial_state);
        }
    };
}

/// ReaderT(M, R, A) - Reader Monad Transformer
/// 将 Reader 功能添加到任意 Monad M
pub fn ReaderT(comptime M: type, comptime R: type, comptime A: type) type {
    return struct {
        /// 内部函数: R → M(A)
        run: *const fn (R) M,

        const Self = @This();

        /// 创建 ReaderT 的构造函数
        pub fn init(run_fn: *const fn (R) M) Self {
            return Self{ .run = run_fn };
        }

        /// 从函数创建 ReaderT
        pub fn fromReader(comptime reader_fn: *const fn (R) A) Self {
            return Self.init(struct {
                fn readerRunner(r: R) M {
                    const result = reader_fn(r);
                    return M.pure(result);
                }
            }.readerRunner);
        }

        /// 提升基础 Monad 到 ReaderT
        pub fn lift(base_monad: anytype) Self {
            return Self.init(struct {
                fn liftedRunner(r: R) M {
                    _ = r;
                    return base_monad;
                }
            }.liftedRunner);
        }

        /// 绑定操作
        pub fn bind(self: Self, f: *const fn (A) Self) Self {
            return Self.init(struct {
                const F = @TypeOf(f);
                const CapturedSelf = Self;

                fn bindRunner(r: R) M {
                    const ma = self.run(r);
                    return M.bind(ma, struct {
                        fn bindFn(a: A) M {
                            const next_transformer = f(a);
                            return next_transformer.run(r);
                        }
                    }.bindFn);
                }
            }.bindRunner);
        }

        /// 函子映射
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) ReaderT(M, R, B) {
            return ReaderT(M, R, B).init(struct {
                fn mapRunner(r: R) M {
                    const ma = self.run(r);
                    return M.map(B, ma, struct {
                        fn mapFn(a: A) B {
                            return f(a);
                        }
                    }.mapFn);
                }
            }.mapRunner);
        }

        /// 读取环境
        pub fn ask() Self {
            return Self.init(struct {
                fn askRunner(r: R) M {
                    return M.pure(r);
                }
            }.askRunner);
        }

        /// 使用环境值计算
        pub fn asks(comptime B: type, f: *const fn (R) B) ReaderT(M, R, B) {
            return ReaderT(M, R, B).init(struct {
                fn asksRunner(r: R) M {
                    const result = f(r);
                    return M.pure(result);
                }
            }.asksRunner);
        }

        /// 运行 ReaderT
        pub fn runReaderT(self: Self, env: R) M {
            return self.run(env);
        }
    };
}

/// WriterT(M, W, A) - Writer Monad Transformer
/// 将 Writer 功能添加到任意 Monad M
pub fn WriterT(comptime M: type, comptime W: type, comptime A: type) type {
    return struct {
        /// 内部 Monad 类型: M(struct { A, W })
        inner: M,

        const Self = @This();

        /// 创建 WriterT 的构造函数
        pub fn init(inner: M) Self {
            return Self{ .inner = inner };
        }

        /// 从值和日志创建 WriterT
        pub fn fromWriter(value: A, log: W) Self {
            return Self.init(M.pure(.{ value, log }));
        }

        /// 提升基础 Monad 到 WriterT
        pub fn lift(base_monad: anytype) Self {
            return M.map(base_monad, struct {
                fn toWriter(a: @TypeOf(base_monad).T) struct { @TypeOf(base_monad).T, W } {
                    return .{ a, std.mem.zeroes(W) };
                }
            }.toWriter);
        }

        /// 绑定操作
        pub fn bind(self: Self, f: *const fn (A) Self) Self {
            const new_inner = M.bind(self.inner, struct {
                const F = @TypeOf(f);
                const CapturedSelf = Self;

                fn bindFn(writer_result: struct { A, W }) M {
                    const a = writer_result[0];
                    const w1 = writer_result[1];
                    const next_transformer = f(a);
                    return M.map(next_transformer.inner, struct {
                        fn mapFn(next_result: struct { A, W }) struct { A, W } {
                            const b = next_result[0];
                            const w2 = next_result[1];
                            // 简化实现：保留第一个日志
                            const combined_log = w1;
                            _ = w2;
                            return .{ b, combined_log };
                        }
                    }.mapFn);
                }
            }.bindFn);

            return Self.init(new_inner);
        }

        /// 函子映射
        pub fn map(self: Self, comptime B: type, f: *const fn (A) B) WriterT(M, W, B) {
            const new_inner = M.map(struct { B, W }, self.inner, struct {
                fn mapFn(writer_result: struct { A, W }) struct { B, W } {
                    const a = writer_result[0];
                    const w = writer_result[1];
                    return .{ f(a), w };
                }
            }.mapFn);

            return WriterT(M, W, B).init(new_inner);
        }

        /// 告诉日志消息
        pub fn tell(log: W) Self {
            return Self.init(M.pure(.{ {}, log }));
        }

        /// 监听计算并返回日志
        pub fn listen(self: Self) WriterT(M, W, struct { A, W }) {
            const new_inner = M.map(self.inner, struct {
                fn listenFn(writer_result: struct { A, W }) struct { struct { A, W }, W } {
                    const a = writer_result[0];
                    const w = writer_result[1];
                    return .{ .{ a, w }, w };
                }
            }.listenFn);

            return WriterT(M, W, struct { A, W }).init(new_inner);
        }

        /// 运行 WriterT 获得基础 Monad
        pub fn run(self: Self) M {
            return self.inner;
        }
    };
}

// ============ 便捷构造函数 ============

/// 创建 EitherT 的便捷函数
pub fn eitherT(comptime M: type, comptime E: type, comptime A: type, inner: M) EitherT(M, E, A) {
    return EitherT(M, E, A).init(inner);
}

/// 创建 OptionT 的便捷函数
pub fn optionT(comptime M: type, comptime A: type, inner: M) OptionT(M, A) {
    return OptionT(M, A).init(inner);
}

/// 创建 StateT 的便捷函数
pub fn stateT(comptime M: type, comptime S: type, comptime A: type, run_fn: *const fn (S) M) StateT(M, S, A) {
    return StateT(M, S, A).init(run_fn);
}

/// 创建 ReaderT 的便捷函数
pub fn readerT(comptime M: type, comptime R: type, comptime A: type, run_fn: *const fn (R) M) ReaderT(M, R, A) {
    return ReaderT(M, R, A).init(run_fn);
}

/// 创建 WriterT 的便捷函数
pub fn writerT(comptime M: type, comptime W: type, comptime A: type, inner: M) WriterT(M, W, A) {
    return WriterT(M, W, A).init(inner);
}

// ============ 组合工具 ============

/// Transformer 组合工具
pub const combinators = struct {
    /// 提升函数到 EitherT
    pub fn liftEitherT(comptime M: type, comptime E: type, comptime A: type, comptime B: type, f: *const fn (A) B) fn (EitherT(M, E, A)) EitherT(M, E, B) {
        return struct {
            fn lifted(et: EitherT(M, E, A)) EitherT(M, E, B) {
                return et.map(B, f);
            }
        }.lifted;
    }

    /// 提升函数到 OptionT
    pub fn liftOptionT(comptime M: type, comptime A: type, comptime B: type, f: *const fn (A) B) fn (OptionT(M, A)) OptionT(M, B) {
        return struct {
            fn lifted(ot: OptionT(M, A)) OptionT(M, B) {
                return ot.map(B, f);
            }
        }.lifted;
    }
};

// ============ 示例 ============

/// 使用示例
pub const examples = struct {
    /// EitherT 使用示例
    pub fn eitherTExample() void {
        // 这里需要具体的 Monad 实现作为例子
        // 由于 Zig 没有原生 Monad，这里用 Identity Monad 作为示例
    }

    /// OptionT 使用示例
    pub fn optionTExample() void {
        // OptionT 示例
    }
};

// ============ 测试 ============

test "Identity Monad" {
    const id = Identity(i32).pure(42);
    try std.testing.expectEqual(@as(i32, 42), id.run());

    const mapped = Identity(i32).map(bool, id, struct {
        fn intToBool(x: i32) bool {
            return x > 0;
        }
    }.intToBool);
    try std.testing.expect(mapped.run());

    const bound = Identity(i32).bind(bool, id, struct {
        fn intToBoolMonad(x: i32) Identity(bool) {
            return Identity(bool).pure(x > 0);
        }
    }.intToBoolMonad);
    try std.testing.expect(bound.run());
}

test "StateT with Identity Monad" {
    const state_transformer = StateT(Identity(struct { i32, i32 }), i32, i32).fromState(struct {
        fn stateFn(s: i32) struct { i32, i32 } {
            return .{ s + 1, s + 1 };
        }
    }.stateFn);

    const result = state_transformer.runStateT(10).run();
    try std.testing.expectEqual(@as(i32, 11), result[0]);
    try std.testing.expectEqual(@as(i32, 11), result[1]);
}

test "ReaderT with Identity Monad" {
    const reader_transformer = ReaderT(Identity(i32), []const u8, i32).fromReader(struct {
        fn readerFn(env: []const u8) i32 {
            return @intCast(env.len);
        }
    }.readerFn);

    const result = reader_transformer.runReaderT("hello").run();
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "WriterT with Identity Monad" {
    const writer_transformer = WriterT(Identity(struct { i32, []const u8 }), []const u8, i32).fromWriter(42, "log message");

    const result = writer_transformer.run().run();
    try std.testing.expectEqual(@as(i32, 42), result[0]);
    try std.testing.expectEqualStrings("log message", result[1]);
}
