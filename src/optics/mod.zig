//! 光学模块
//!
//! 提供函数式光学类型用于数据访问和更新：
//! - Lens - 聚焦结构字段
//! - Optics - 完整光学类型系统（Iso, Prism, Affine 等）

const std = @import("std");

pub const lens = @import("lens.zig");
pub const optics = @import("optics.zig");

// ============ Lens ============
pub const Lens = lens.Lens;
pub const composeLens = lens.composeLens;
pub const makeLens = lens.makeLens;

// ============ Optics ============
pub const Iso = optics.Iso;
pub const Prism = optics.Prism;
pub const Affine = optics.Affine;
pub const Getter = optics.Getter;
pub const Setter = optics.Setter;

test {
    std.testing.refAllDecls(@This());
}
