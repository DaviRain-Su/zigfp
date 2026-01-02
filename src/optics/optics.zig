//! Optics 模块
//!
//! Optics 是对数据结构中"焦点"的抽象，提供了一种组合式的方式来访问和修改嵌套数据。
//!
//! 主要类型：
//! - `Iso(S, A)` - 同构，双向无损转换
//! - `Prism(S, A)` - 部分同构，可能失败的构造/解构
//! - `Affine(S, A)` - 可选焦点，可能不存在的访问
//! - `Getter(S, A)` - 只读访问
//! - `Setter(S, A)` - 只写访问
//!
//! Optics 层次结构：
//! ```
//!      Iso
//!       |
//!     Prism --- Lens
//!       |        |
//!    Affine ----+
//!       |
//!   Traversal
//!       |
//!     Fold
//! ```

const std = @import("std");
const option_mod = @import("../core/option.zig");
const Option = option_mod.Option;

// ============ Iso (同构) ============

/// Iso - 同构，表示两种类型之间的无损双向转换
/// S 和 A 之间可以自由转换，不丢失信息
///
/// 法则：
/// - to(from(a)) = a
/// - from(to(s)) = s
pub fn Iso(comptime S: type, comptime A: type) type {
    return struct {
        /// S -> A
        to_fn: *const fn (S) A,
        /// A -> S
        from_fn: *const fn (A) S,

        const Self = @This();

        // ============ 构造器 ============

        pub fn init(to_fn: *const fn (S) A, from_fn: *const fn (A) S) Self {
            return .{ .to_fn = to_fn, .from_fn = from_fn };
        }

        // ============ 基本操作 ============

        /// 正向转换 S -> A
        pub fn to(self: Self, s: S) A {
            return self.to_fn(s);
        }

        /// 反向转换 A -> S
        pub fn from(self: Self, a: A) S {
            return self.from_fn(a);
        }

        /// 通过 Iso 修改值
        pub fn modify(self: Self, s: S, f: *const fn (A) A) S {
            const a = self.to(s);
            const new_a = f(a);
            return self.from(new_a);
        }

        /// 设置新值
        pub fn set(self: Self, a: A) S {
            return self.from(a);
        }

        // ============ 组合操作 ============

        /// 反转 Iso: Iso(S, A) -> Iso(A, S)
        pub fn reverse(self: Self) Iso(A, S) {
            return Iso(A, S).init(self.from_fn, self.to_fn);
        }

        /// 组合两个 Iso: Iso(S, A) . Iso(A, B) -> Iso(S, B)
        pub fn compose(self: Self, comptime B: type, other: Iso(A, B)) IsoComposed(S, A, B) {
            return IsoComposed(S, A, B).init(self, other);
        }

        /// 转换为 Lens
        pub fn asLens(self: Self) Lens(S, A) {
            return AsLensWrapper(S, A).create(self.to_fn, self.from_fn);
        }

        /// 转换为 Prism
        pub fn asPrism(self: Self) Prism(S, A) {
            return AsPrismWrapper(S, A).create(self.to_fn, self.from_fn);
        }

        /// 转换为 Getter
        pub fn asGetter(self: Self) Getter(S, A) {
            return Getter(S, A).init(self.to_fn);
        }
    };
}

/// Iso 组合包装器
fn IsoComposed(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        first: Iso(S, A),
        second: Iso(A, B),

        const Self = @This();

        pub fn init(first: Iso(S, A), second: Iso(A, B)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn to(self: Self, s: S) B {
            return self.second.to(self.first.to(s));
        }

        pub fn from(self: Self, b: B) S {
            return self.first.from(self.second.from(b));
        }
    };
}

/// Iso -> Lens 包装器
fn AsLensWrapper(comptime S: type, comptime A: type) type {
    return struct {
        var stored_to: *const fn (S) A = undefined;
        var stored_from: *const fn (A) S = undefined;

        fn get(s: S) A {
            return stored_to(s);
        }

        fn set(a: A, _: S) S {
            return stored_from(a);
        }

        pub fn create(to_fn: *const fn (S) A, from_fn: *const fn (A) S) Lens(S, A) {
            stored_to = to_fn;
            stored_from = from_fn;
            return Lens(S, A).init(&get, &set);
        }
    };
}

/// Iso -> Prism 包装器
fn AsPrismWrapper(comptime S: type, comptime A: type) type {
    return struct {
        var stored_to: *const fn (S) A = undefined;
        var stored_from: *const fn (A) S = undefined;

        fn preview(s: S) Option(A) {
            return Option(A).Some(stored_to(s));
        }

        fn review(a: A) S {
            return stored_from(a);
        }

        pub fn create(to_fn: *const fn (S) A, from_fn: *const fn (A) S) Prism(S, A) {
            stored_to = to_fn;
            stored_from = from_fn;
            return Prism(S, A).init(&preview, &review);
        }
    };
}

// ============ Lens ============

/// Lens - 聚焦于数据结构中的一个部分
/// 总是可以 get 和 set 焦点值
///
/// 法则：
/// - get(set(a, s)) = a
/// - set(get(s), s) = s
/// - set(a', set(a, s)) = set(a', s)
pub fn Lens(comptime S: type, comptime A: type) type {
    return struct {
        get_fn: *const fn (S) A,
        set_fn: *const fn (A, S) S,

        const Self = @This();

        pub fn init(get_fn: *const fn (S) A, set_fn: *const fn (A, S) S) Self {
            return .{ .get_fn = get_fn, .set_fn = set_fn };
        }

        /// 获取焦点值
        pub fn get(self: Self, s: S) A {
            return self.get_fn(s);
        }

        /// 设置焦点值
        pub fn set(self: Self, a: A, s: S) S {
            return self.set_fn(a, s);
        }

        /// 修改焦点值
        pub fn modify(self: Self, s: S, f: *const fn (A) A) S {
            const a = self.get(s);
            const new_a = f(a);
            return self.set(new_a, s);
        }

        /// 组合两个 Lens: Lens(S, A) . Lens(A, B) -> Lens(S, B)
        pub fn compose(self: Self, comptime B: type, other: Lens(A, B)) LensComposed(S, A, B) {
            return LensComposed(S, A, B).init(self, other);
        }

        /// 转换为 Getter
        pub fn asGetter(self: Self) Getter(S, A) {
            return Getter(S, A).init(self.get_fn);
        }

        /// 转换为 Affine
        pub fn asAffine(self: Self) Affine(S, A) {
            return LensToAffineWrapper(S, A).create(self.get_fn, self.set_fn);
        }
    };
}

/// Lens 组合包装器
fn LensComposed(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        first: Lens(S, A),
        second: Lens(A, B),

        const Self = @This();

        pub fn init(first: Lens(S, A), second: Lens(A, B)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn get(self: Self, s: S) B {
            return self.second.get(self.first.get(s));
        }

        pub fn set(self: Self, b: B, s: S) S {
            const a = self.first.get(s);
            const new_a = self.second.set(b, a);
            return self.first.set(new_a, s);
        }

        pub fn modify(self: Self, s: S, f: *const fn (B) B) S {
            const a = self.first.get(s);
            const new_a = self.second.modify(a, f);
            return self.first.set(new_a, s);
        }
    };
}

/// Lens -> Affine 包装器
fn LensToAffineWrapper(comptime S: type, comptime A: type) type {
    return struct {
        var stored_get: *const fn (S) A = undefined;
        var stored_set: *const fn (A, S) S = undefined;

        fn preview(s: S) Option(A) {
            return Option(A).Some(stored_get(s));
        }

        fn set(a: A, s: S) S {
            return stored_set(a, s);
        }

        pub fn create(get_fn: *const fn (S) A, set_fn: *const fn (A, S) S) Affine(S, A) {
            stored_get = get_fn;
            stored_set = set_fn;
            return Affine(S, A).init(&preview, &set);
        }
    };
}

// ============ Prism (部分同构) ============

/// Prism - 部分同构，可能失败的构造/解构
/// 可以总是构造 S，但解构可能失败
///
/// 法则：
/// - preview(review(a)) = Some(a)
/// - review <$> preview(s) = Just s（如果 preview 成功）
pub fn Prism(comptime S: type, comptime A: type) type {
    return struct {
        /// 尝试从 S 提取 A（可能失败）
        preview_fn: *const fn (S) Option(A),
        /// 从 A 构造 S（总是成功）
        review_fn: *const fn (A) S,

        const Self = @This();

        pub fn init(preview_fn: *const fn (S) Option(A), review_fn: *const fn (A) S) Self {
            return .{ .preview_fn = preview_fn, .review_fn = review_fn };
        }

        /// 尝试提取焦点值
        pub fn preview(self: Self, s: S) Option(A) {
            return self.preview_fn(s);
        }

        /// 从焦点值构造整体
        pub fn review(self: Self, a: A) S {
            return self.review_fn(a);
        }

        /// 如果存在则修改焦点值
        pub fn modify(self: Self, s: S, f: *const fn (A) A) S {
            const opt_a = self.preview(s);
            if (opt_a.isSome()) {
                const new_a = f(opt_a.unwrap());
                return self.review(new_a);
            }
            return s;
        }

        /// 如果存在则设置焦点值
        pub fn set(self: Self, a: A, s: S) S {
            const opt = self.preview(s);
            if (opt.isSome()) {
                return self.review(a);
            }
            return s;
        }

        /// 组合两个 Prism: Prism(S, A) . Prism(A, B) -> Prism(S, B)
        pub fn compose(self: Self, comptime B: type, other: Prism(A, B)) PrismComposed(S, A, B) {
            return PrismComposed(S, A, B).init(self, other);
        }

        /// 转换为 Affine
        pub fn asAffine(self: Self) Affine(S, A) {
            return PrismToAffineWrapper(S, A).create(self.preview_fn, self.review_fn);
        }
    };
}

/// Prism 组合包装器
fn PrismComposed(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        first: Prism(S, A),
        second: Prism(A, B),

        const Self = @This();

        pub fn init(first: Prism(S, A), second: Prism(A, B)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn preview(self: Self, s: S) Option(B) {
            const opt_a = self.first.preview(s);
            if (opt_a.isSome()) {
                return self.second.preview(opt_a.unwrap());
            }
            return Option(B).None();
        }

        pub fn review(self: Self, b: B) S {
            return self.first.review(self.second.review(b));
        }
    };
}

/// Prism -> Affine 包装器
fn PrismToAffineWrapper(comptime S: type, comptime A: type) type {
    return struct {
        var stored_preview: *const fn (S) Option(A) = undefined;
        var stored_review: *const fn (A) S = undefined;

        fn preview(s: S) Option(A) {
            return stored_preview(s);
        }

        fn set(a: A, s: S) S {
            const opt = stored_preview(s);
            if (opt.isSome()) {
                return stored_review(a);
            }
            return s;
        }

        pub fn create(preview_fn: *const fn (S) Option(A), review_fn: *const fn (A) S) Affine(S, A) {
            stored_preview = preview_fn;
            stored_review = review_fn;
            return Affine(S, A).init(&preview, &set);
        }
    };
}

// ============ Affine (可选焦点) ============

/// Affine - 可选焦点，结合了 Lens 和 Prism 的特性
/// 焦点可能不存在，但如果存在可以修改
///
/// 也称为 Optional 或 AffineTraversal
pub fn Affine(comptime S: type, comptime A: type) type {
    return struct {
        /// 尝试获取焦点值
        preview_fn: *const fn (S) Option(A),
        /// 设置焦点值（如果存在）
        set_fn: *const fn (A, S) S,

        const Self = @This();

        pub fn init(preview_fn: *const fn (S) Option(A), set_fn: *const fn (A, S) S) Self {
            return .{ .preview_fn = preview_fn, .set_fn = set_fn };
        }

        /// 尝试获取焦点值
        pub fn preview(self: Self, s: S) Option(A) {
            return self.preview_fn(s);
        }

        /// 设置焦点值
        pub fn set(self: Self, a: A, s: S) S {
            return self.set_fn(a, s);
        }

        /// 如果存在则修改焦点值
        pub fn modify(self: Self, s: S, f: *const fn (A) A) S {
            const opt_a = self.preview(s);
            if (opt_a.isSome()) {
                const new_a = f(opt_a.unwrap());
                return self.set(new_a, s);
            }
            return s;
        }

        /// 组合两个 Affine
        pub fn compose(self: Self, comptime B: type, other: Affine(A, B)) AffineComposed(S, A, B) {
            return AffineComposed(S, A, B).init(self, other);
        }
    };
}

/// Affine 组合包装器
fn AffineComposed(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        first: Affine(S, A),
        second: Affine(A, B),

        const Self = @This();

        pub fn init(first: Affine(S, A), second: Affine(A, B)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn preview(self: Self, s: S) Option(B) {
            const opt_a = self.first.preview(s);
            if (opt_a.isSome()) {
                return self.second.preview(opt_a.unwrap());
            }
            return Option(B).None();
        }

        pub fn set(self: Self, b: B, s: S) S {
            const opt_a = self.first.preview(s);
            if (opt_a.isSome()) {
                const a = opt_a.unwrap();
                const new_a = self.second.set(b, a);
                return self.first.set(new_a, s);
            }
            return s;
        }
    };
}

// ============ Getter (只读访问) ============

/// Getter - 只读访问，总是可以获取值
pub fn Getter(comptime S: type, comptime A: type) type {
    return struct {
        get_fn: *const fn (S) A,

        const Self = @This();

        pub fn init(get_fn: *const fn (S) A) Self {
            return .{ .get_fn = get_fn };
        }

        /// 获取焦点值
        pub fn get(self: Self, s: S) A {
            return self.get_fn(s);
        }

        /// 组合两个 Getter
        pub fn compose(self: Self, comptime B: type, other: Getter(A, B)) GetterComposed(S, A, B) {
            return GetterComposed(S, A, B).init(self, other);
        }
    };
}

/// Getter 组合包装器
fn GetterComposed(comptime S: type, comptime A: type, comptime B: type) type {
    return struct {
        first: Getter(S, A),
        second: Getter(A, B),

        const Self = @This();

        pub fn init(first: Getter(S, A), second: Getter(A, B)) Self {
            return .{ .first = first, .second = second };
        }

        pub fn get(self: Self, s: S) B {
            return self.second.get(self.first.get(s));
        }
    };
}

// ============ Setter (只写访问) ============

/// Setter - 只写访问，只能设置不能获取
pub fn Setter(comptime S: type, comptime A: type) type {
    return struct {
        modify_fn: *const fn (S, *const fn (A) A) S,

        const Self = @This();

        pub fn init(modify_fn: *const fn (S, *const fn (A) A) S) Self {
            return .{ .modify_fn = modify_fn };
        }

        /// 修改焦点值
        pub fn modify(self: Self, s: S, f: *const fn (A) A) S {
            return self.modify_fn(s, f);
        }

        /// 设置焦点值
        pub fn set(self: Self, a: A, s: S) S {
            const constFn = struct {
                var stored_a: A = undefined;
                fn f(_: A) A {
                    return stored_a;
                }
            };
            constFn.stored_a = a;
            return self.modify(s, &constFn.f);
        }
    };
}

// ============ Fold (多焦点只读) ============

/// Fold - 可以读取多个焦点值
pub fn Fold(comptime S: type, comptime A: type) type {
    return struct {
        fold_fn: *const fn (S, std.mem.Allocator) std.mem.Allocator.Error![]A,

        const Self = @This();

        pub fn init(fold_fn: *const fn (S, std.mem.Allocator) std.mem.Allocator.Error![]A) Self {
            return .{ .fold_fn = fold_fn };
        }

        /// 获取所有焦点值
        pub fn toList(self: Self, s: S, allocator: std.mem.Allocator) ![]A {
            return self.fold_fn(s, allocator);
        }

        /// 获取第一个焦点值
        pub fn headOption(self: Self, s: S, allocator: std.mem.Allocator) !Option(A) {
            const list = try self.fold_fn(s, allocator);
            defer allocator.free(list);
            if (list.len > 0) {
                return Option(A).Some(list[0]);
            }
            return Option(A).None();
        }
    };
}

// ============ 便捷构造函数 ============

/// 创建 Iso
pub fn iso(comptime S: type, comptime A: type, to_fn: *const fn (S) A, from_fn: *const fn (A) S) Iso(S, A) {
    return Iso(S, A).init(to_fn, from_fn);
}

/// 创建 Lens
pub fn lens(comptime S: type, comptime A: type, get_fn: *const fn (S) A, set_fn: *const fn (A, S) S) Lens(S, A) {
    return Lens(S, A).init(get_fn, set_fn);
}

/// 创建 Prism
pub fn prism(comptime S: type, comptime A: type, preview_fn: *const fn (S) Option(A), review_fn: *const fn (A) S) Prism(S, A) {
    return Prism(S, A).init(preview_fn, review_fn);
}

/// 创建 Affine
pub fn affine(comptime S: type, comptime A: type, preview_fn: *const fn (S) Option(A), set_fn: *const fn (A, S) S) Affine(S, A) {
    return Affine(S, A).init(preview_fn, set_fn);
}

/// 创建 Getter
pub fn getter(comptime S: type, comptime A: type, get_fn: *const fn (S) A) Getter(S, A) {
    return Getter(S, A).init(get_fn);
}

// ============ 常用 Optics ============

/// Option 的 some prism
pub fn somePrism(comptime A: type) Prism(Option(A), A) {
    const Impl = struct {
        fn preview(opt: Option(A)) Option(A) {
            return opt;
        }

        fn review(a: A) Option(A) {
            return Option(A).Some(a);
        }
    };

    return Prism(Option(A), A).init(&Impl.preview, &Impl.review);
}

/// 列表头部的 Affine
pub fn headAffine(comptime T: type) Affine([]const T, T) {
    const Impl = struct {
        fn preview(slice: []const T) Option(T) {
            if (slice.len > 0) {
                return Option(T).Some(slice[0]);
            }
            return Option(T).None();
        }

        fn set(_: T, s: []const T) []const T {
            // 注意：这只是返回原 slice，实际修改需要分配新内存
            return s;
        }
    };

    return Affine([]const T, T).init(&Impl.preview, &Impl.set);
}

/// identity Iso
pub fn identityIso(comptime A: type) Iso(A, A) {
    const Impl = struct {
        fn id(a: A) A {
            return a;
        }
    };

    return Iso(A, A).init(&Impl.id, &Impl.id);
}

// ============ 测试 ============

test "Iso.init and basic operations" {
    // Celsius <-> Fahrenheit 转换
    const CelsiusToFahrenheit = struct {
        fn to(c: f64) f64 {
            return c * 9.0 / 5.0 + 32.0;
        }

        fn from(f: f64) f64 {
            return (f - 32.0) * 5.0 / 9.0;
        }
    };

    const tempIso = Iso(f64, f64).init(&CelsiusToFahrenheit.to, &CelsiusToFahrenheit.from);

    // 0°C = 32°F
    try std.testing.expectApproxEqAbs(@as(f64, 32.0), tempIso.to(0.0), 0.001);
    // 32°F = 0°C
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), tempIso.from(32.0), 0.001);

    // 100°C = 212°F
    try std.testing.expectApproxEqAbs(@as(f64, 212.0), tempIso.to(100.0), 0.001);
}

test "Iso roundtrip law" {
    // to(from(a)) = a
    // from(to(s)) = s
    const double = struct {
        fn to(x: i32) i64 {
            return @as(i64, x) * 2;
        }

        fn from(x: i64) i32 {
            return @intCast(@divTrunc(x, 2));
        }
    };

    const iso_val = Iso(i32, i64).init(&double.to, &double.from);

    // 对于可逆的转换
    const original: i32 = 42;
    const converted = iso_val.to(original);
    const back = iso_val.from(converted);
    try std.testing.expectEqual(original, back);
}

test "Iso.reverse" {
    const intToStr = struct {
        fn to(x: i32) i64 {
            return @intCast(x);
        }

        fn from(x: i64) i32 {
            return @intCast(x);
        }
    };

    const iso_val = Iso(i32, i64).init(&intToStr.to, &intToStr.from);
    const reversed = iso_val.reverse();

    try std.testing.expectEqual(@as(i32, 42), reversed.to(42));
    try std.testing.expectEqual(@as(i64, 42), reversed.from(42));
}

test "Iso.modify" {
    const double = struct {
        fn to(x: i32) i32 {
            return x * 2;
        }

        fn from(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    };

    const iso_val = Iso(i32, i32).init(&double.to, &double.from);

    const addTen = struct {
        fn f(x: i32) i32 {
            return x + 10;
        }
    }.f;

    // 5 -> to(5)=10 -> 10+10=20 -> from(20)=10
    const result = iso_val.modify(5, &addTen);
    try std.testing.expectEqual(@as(i32, 10), result);
}

test "Lens.init and basic operations" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xLens = struct {
        fn get(p: Point) i32 {
            return p.x;
        }

        fn set(x: i32, p: Point) Point {
            return .{ .x = x, .y = p.y };
        }
    };

    const l = Lens(Point, i32).init(&xLens.get, &xLens.set);
    const point = Point{ .x = 10, .y = 20 };

    try std.testing.expectEqual(@as(i32, 10), l.get(point));

    const newPoint = l.set(100, point);
    try std.testing.expectEqual(@as(i32, 100), newPoint.x);
    try std.testing.expectEqual(@as(i32, 20), newPoint.y);
}

test "Lens.modify" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xLens = struct {
        fn get(p: Point) i32 {
            return p.x;
        }

        fn set(x: i32, p: Point) Point {
            return .{ .x = x, .y = p.y };
        }
    };

    const l = Lens(Point, i32).init(&xLens.get, &xLens.set);
    const point = Point{ .x = 10, .y = 20 };

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const newPoint = l.modify(point, &double);
    try std.testing.expectEqual(@as(i32, 20), newPoint.x);
    try std.testing.expectEqual(@as(i32, 20), newPoint.y);
}

test "Lens laws" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xLens = struct {
        fn get(p: Point) i32 {
            return p.x;
        }

        fn set(x: i32, p: Point) Point {
            return .{ .x = x, .y = p.y };
        }
    };

    const l = Lens(Point, i32).init(&xLens.get, &xLens.set);
    const point = Point{ .x = 10, .y = 20 };

    // get(set(a, s)) = a
    const a: i32 = 42;
    try std.testing.expectEqual(a, l.get(l.set(a, point)));

    // set(get(s), s) = s
    const result = l.set(l.get(point), point);
    try std.testing.expectEqual(point.x, result.x);
    try std.testing.expectEqual(point.y, result.y);
}

test "Prism.init and basic operations" {
    // 一个将正数解析为 Some 的 Prism
    const positivePrism = struct {
        fn preview(n: i32) Option(i32) {
            if (n > 0) {
                return Option(i32).Some(n);
            }
            return Option(i32).None();
        }

        fn review(n: i32) i32 {
            return n;
        }
    };

    const p = Prism(i32, i32).init(&positivePrism.preview, &positivePrism.review);

    // 正数应该成功
    const pos = p.preview(42);
    try std.testing.expect(pos.isSome());
    try std.testing.expectEqual(@as(i32, 42), pos.unwrap());

    // 非正数应该失败
    const neg = p.preview(-5);
    try std.testing.expect(neg.isNone());

    // review 总是成功
    try std.testing.expectEqual(@as(i32, 100), p.review(100));
}

test "Prism laws" {
    const positivePrism = struct {
        fn preview(n: i32) Option(i32) {
            if (n > 0) {
                return Option(i32).Some(n);
            }
            return Option(i32).None();
        }

        fn review(n: i32) i32 {
            return n;
        }
    };

    const p = Prism(i32, i32).init(&positivePrism.preview, &positivePrism.review);

    // preview(review(a)) = Some(a)
    const a: i32 = 42;
    const result = p.preview(p.review(a));
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(a, result.unwrap());
}

test "Affine.init and basic operations" {
    const Data = struct {
        value: ?i32,
    };

    const valueAffine = struct {
        fn preview(d: Data) Option(i32) {
            if (d.value) |v| {
                return Option(i32).Some(v);
            }
            return Option(i32).None();
        }

        fn set(v: i32, d: Data) Data {
            _ = d;
            return .{ .value = v };
        }
    };

    const a = Affine(Data, i32).init(&valueAffine.preview, &valueAffine.set);

    // 有值时成功
    const withValue = Data{ .value = 42 };
    const result = a.preview(withValue);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    // 无值时失败
    const withoutValue = Data{ .value = null };
    const result2 = a.preview(withoutValue);
    try std.testing.expect(result2.isNone());
}

test "Affine.modify" {
    const Data = struct {
        value: ?i32,
    };

    const valueAffine = struct {
        fn preview(d: Data) Option(i32) {
            if (d.value) |v| {
                return Option(i32).Some(v);
            }
            return Option(i32).None();
        }

        fn set(v: i32, _: Data) Data {
            return .{ .value = v };
        }
    };

    const a = Affine(Data, i32).init(&valueAffine.preview, &valueAffine.set);

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    // 有值时修改
    const withValue = Data{ .value = 21 };
    const modified = a.modify(withValue, &double);
    try std.testing.expectEqual(@as(?i32, 42), modified.value);

    // 无值时保持不变
    const withoutValue = Data{ .value = null };
    const unchanged = a.modify(withoutValue, &double);
    try std.testing.expectEqual(@as(?i32, null), unchanged.value);
}

test "Getter.init and get" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xGetter = struct {
        fn get(p: Point) i32 {
            return p.x;
        }
    };

    const g = Getter(Point, i32).init(&xGetter.get);
    const point = Point{ .x = 42, .y = 20 };

    try std.testing.expectEqual(@as(i32, 42), g.get(point));
}

test "Getter.compose" {
    const Inner = struct {
        value: i32,
    };

    const Outer = struct {
        inner: Inner,
    };

    const innerGetter = struct {
        fn get(o: Outer) Inner {
            return o.inner;
        }
    };

    const valueGetter = struct {
        fn get(i: Inner) i32 {
            return i.value;
        }
    };

    const g1 = Getter(Outer, Inner).init(&innerGetter.get);
    const g2 = Getter(Inner, i32).init(&valueGetter.get);
    const composed = g1.compose(i32, g2);

    const data = Outer{ .inner = .{ .value = 42 } };
    try std.testing.expectEqual(@as(i32, 42), composed.get(data));
}

test "somePrism" {
    const p = somePrism(i32);

    // Some 值应该成功
    const someVal = Option(i32).Some(42);
    const result = p.preview(someVal);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    // None 应该失败
    const noneVal = Option(i32).None();
    const result2 = p.preview(noneVal);
    try std.testing.expect(result2.isNone());

    // review 应该构造 Some
    const reviewed = p.review(100);
    try std.testing.expect(reviewed.isSome());
    try std.testing.expectEqual(@as(i32, 100), reviewed.unwrap());
}

test "headAffine" {
    const a = headAffine(i32);

    // 非空数组应该成功
    const arr = [_]i32{ 1, 2, 3 };
    const result = a.preview(&arr);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 1), result.unwrap());

    // 空数组应该失败
    const empty: []const i32 = &.{};
    const result2 = a.preview(empty);
    try std.testing.expect(result2.isNone());
}

test "identityIso" {
    const id = identityIso(i32);

    try std.testing.expectEqual(@as(i32, 42), id.to(42));
    try std.testing.expectEqual(@as(i32, 42), id.from(42));
}

test "convenience functions" {
    // iso
    const double = struct {
        fn to(x: i32) i32 {
            return x * 2;
        }

        fn from(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    };

    const i = iso(i32, i32, &double.to, &double.from);
    try std.testing.expectEqual(@as(i32, 10), i.to(5));

    // getter
    const g = getter(i32, i32, struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);
    try std.testing.expectEqual(@as(i32, 6), g.get(5));
}

test "Iso.asLens" {
    const double = struct {
        fn to(x: i32) i32 {
            return x * 2;
        }

        fn from(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    };

    const i = Iso(i32, i32).init(&double.to, &double.from);
    const l = i.asLens();

    try std.testing.expectEqual(@as(i32, 10), l.get(5));
    try std.testing.expectEqual(@as(i32, 21), l.set(42, 5));
}

test "Iso.asPrism" {
    const double = struct {
        fn to(x: i32) i32 {
            return x * 2;
        }

        fn from(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    };

    const i = Iso(i32, i32).init(&double.to, &double.from);
    const p = i.asPrism();

    const result = p.preview(5);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 10), result.unwrap());
    try std.testing.expectEqual(@as(i32, 21), p.review(42));
}

test "Lens.asGetter" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xLens = struct {
        fn get(p: Point) i32 {
            return p.x;
        }

        fn set(x: i32, p: Point) Point {
            return .{ .x = x, .y = p.y };
        }
    };

    const l = Lens(Point, i32).init(&xLens.get, &xLens.set);
    const g = l.asGetter();

    const point = Point{ .x = 42, .y = 20 };
    try std.testing.expectEqual(@as(i32, 42), g.get(point));
}

test "Lens.asAffine" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const xLens = struct {
        fn get(p: Point) i32 {
            return p.x;
        }

        fn set(x: i32, p: Point) Point {
            return .{ .x = x, .y = p.y };
        }
    };

    const l = Lens(Point, i32).init(&xLens.get, &xLens.set);
    const a = l.asAffine();

    const point = Point{ .x = 42, .y = 20 };
    const result = a.preview(point);
    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "Prism.asAffine" {
    const positivePrism = struct {
        fn preview(n: i32) Option(i32) {
            if (n > 0) {
                return Option(i32).Some(n);
            }
            return Option(i32).None();
        }

        fn review(n: i32) i32 {
            return n;
        }
    };

    const p = Prism(i32, i32).init(&positivePrism.preview, &positivePrism.review);
    const a = p.asAffine();

    const pos = a.preview(42);
    try std.testing.expect(pos.isSome());
    try std.testing.expectEqual(@as(i32, 42), pos.unwrap());

    const neg = a.preview(-5);
    try std.testing.expect(neg.isNone());
}
