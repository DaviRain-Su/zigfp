//! Monad 家族模块
//!
//! 提供各种 Monad 实现：
//! - Reader - 依赖注入
//! - Writer - 日志累积
//! - State - 状态管理
//! - Cont - 续延
//! - Free - 自由 Monad
//! - MTL - Monad 变换器
//! - Selective - 选择性应用函子

const std = @import("std");

pub const reader = @import("reader.zig");
pub const writer = @import("writer.zig");
pub const state = @import("state.zig");
pub const cont = @import("cont.zig");
pub const free = @import("free.zig");
pub const mtl = @import("mtl.zig");
pub const selective = @import("selective.zig");

// ============ Reader ============
pub const Reader = reader.Reader;
pub const ReaderValue = reader.ReaderValue;
pub const ask = reader.ask;
pub const asks = reader.asks;

// ============ Writer ============
pub const Writer = writer.Writer;
pub const tell = writer.tell;

// ============ State ============
pub const State = state.State;
pub const StateValue = state.StateValue;
pub const get = state.get;
pub const modify = state.modify;
pub const StatefulOps = state.StatefulOps;

// ============ Cont ============
pub const Cont = cont.Cont;
pub const CPS = cont.CPS;
pub const TrampolineCPS = cont.TrampolineCPS;

// ============ Free ============
pub const Free = free.Free;
pub const Trampoline = free.Trampoline;
pub const Program = free.Program;
pub const ProgramOp = free.ProgramOp;
pub const ConsoleF = free.ConsoleF;
pub const ConsoleIO = free.ConsoleIO;
pub const printLine = free.printLine;
pub const readLine = free.readLine;

// ============ MTL ============
pub const EitherT = mtl.EitherT;
pub const OptionT = mtl.OptionT;
pub const IdentityMonad = mtl.Identity;

// ============ Selective ============
pub const SelectiveEither = selective.Either;
pub const selectOption = selective.selectOption;
pub const branchOption = selective.branchOption;
pub const ifSOption = selective.ifSOption;
pub const whenSOption = selective.whenSOption;
pub const selectMOption = selective.selectMOption;
pub const selectiveCombinators = selective.combinators;

test {
    std.testing.refAllDecls(@This());
}
