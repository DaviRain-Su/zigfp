//! Lens - 不可变数据更新
//!
//! `Lens(S, A)` 是一个可组合的 getter/setter 对，
//! 用于访问和更新嵌套数据结构。

const std = @import("std");

/// Lens 类型 - 聚焦嵌套结构
pub fn Lens(comptime S: type, comptime A: type) type {
    return struct {
        /// 获取函数
        get: *const fn (S) A,
        /// 设置函数
        set: *const fn (S, A) S,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建 Lens
        pub fn init(
            getter: *const fn (S) A,
            setter: *const fn (S, A) S,
        ) Self {
            return .{ .get = getter, .set = setter };
        }

        // ============ 核心操作 ============

        /// 获取聚焦的值
        pub fn view(self: Self, s: S) A {
            return self.get(s);
        }

        /// 设置聚焦的值，返回新结构
        pub fn put(self: Self, s: S, a: A) S {
            return self.set(s, a);
        }

        /// 对聚焦的值应用函数
        pub fn over(self: Self, s: S, f: *const fn (A) A) S {
            return self.set(s, f(self.get(s)));
        }
    };
}

/// 组合两个 Lens，聚焦更深层（使用 comptime 参数）
pub fn composeLens(
    comptime S: type,
    comptime A: type,
    comptime B: type,
    comptime outerGet: *const fn (S) A,
    comptime outerSet: *const fn (S, A) S,
    comptime innerGet: *const fn (A) B,
    comptime innerSet: *const fn (A, B) A,
) Lens(S, B) {
    return Lens(S, B).init(
        struct {
            fn get(s: S) B {
                return innerGet(outerGet(s));
            }
        }.get,
        struct {
            fn set(s: S, b: B) S {
                const a = outerGet(s);
                const newA = innerSet(a, b);
                return outerSet(s, newA);
            }
        }.set,
    );
}

/// 为结构体字段创建 Lens
/// 注意：由于 Zig 的 comptime 限制，这需要显式的 getter/setter
pub fn makeLens(
    comptime S: type,
    comptime A: type,
    getter: *const fn (S) A,
    setter: *const fn (S, A) S,
) Lens(S, A) {
    return Lens(S, A).init(getter, setter);
}

// ============ 测试 ============

const Point = struct {
    x: i32,
    y: i32,
};

const Circle = struct {
    center: Point,
    radius: i32,
};

// 手动创建 Lens（由于 Zig 限制）
const pointXGet = struct {
    fn f(p: Point) i32 {
        return p.x;
    }
}.f;

const pointXSet = struct {
    fn f(p: Point, x: i32) Point {
        return Point{ .x = x, .y = p.y };
    }
}.f;

const pointXLens = Lens(Point, i32).init(pointXGet, pointXSet);

const pointYGet = struct {
    fn f(p: Point) i32 {
        return p.y;
    }
}.f;

const pointYSet = struct {
    fn f(p: Point, y: i32) Point {
        return Point{ .x = p.x, .y = y };
    }
}.f;

const pointYLens = Lens(Point, i32).init(pointYGet, pointYSet);

const circleCenterGet = struct {
    fn f(c: Circle) Point {
        return c.center;
    }
}.f;

const circleCenterSet = struct {
    fn f(c: Circle, center: Point) Circle {
        return Circle{ .center = center, .radius = c.radius };
    }
}.f;

const circleCenterLens = Lens(Circle, Point).init(circleCenterGet, circleCenterSet);

const circleRadiusGet = struct {
    fn f(c: Circle) i32 {
        return c.radius;
    }
}.f;

const circleRadiusSet = struct {
    fn f(c: Circle, radius: i32) Circle {
        return Circle{ .center = c.center, .radius = radius };
    }
}.f;

const circleRadiusLens = Lens(Circle, i32).init(circleRadiusGet, circleRadiusSet);

test "Lens.view" {
    const point = Point{ .x = 10, .y = 20 };

    try std.testing.expectEqual(@as(i32, 10), pointXLens.view(point));
    try std.testing.expectEqual(@as(i32, 20), pointYLens.view(point));
}

test "Lens.put" {
    const point = Point{ .x = 10, .y = 20 };

    const newPoint = pointXLens.put(point, 100);

    try std.testing.expectEqual(@as(i32, 100), newPoint.x);
    try std.testing.expectEqual(@as(i32, 20), newPoint.y);

    // 原始 point 不变
    try std.testing.expectEqual(@as(i32, 10), point.x);
}

test "Lens.over" {
    const point = Point{ .x = 10, .y = 20 };

    const doubled = pointXLens.over(point, struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 20), doubled.x);
    try std.testing.expectEqual(@as(i32, 20), doubled.y);
}

test "composeLens" {
    const circle = Circle{
        .center = Point{ .x = 5, .y = 10 },
        .radius = 15,
    };

    // 组合 Lens: Circle -> Point -> i32
    const circleCenterXLens = composeLens(
        Circle,
        Point,
        i32,
        circleCenterGet,
        circleCenterSet,
        pointXGet,
        pointXSet,
    );

    // view
    try std.testing.expectEqual(@as(i32, 5), circleCenterXLens.view(circle));

    // put
    const newCircle = circleCenterXLens.put(circle, 100);
    try std.testing.expectEqual(@as(i32, 100), newCircle.center.x);
    try std.testing.expectEqual(@as(i32, 10), newCircle.center.y); // y 不变
    try std.testing.expectEqual(@as(i32, 15), newCircle.radius); // radius 不变
}

test "composeLens.over" {
    const circle = Circle{
        .center = Point{ .x = 5, .y = 10 },
        .radius = 15,
    };

    const circleCenterYLens = composeLens(
        Circle,
        Point,
        i32,
        circleCenterGet,
        circleCenterSet,
        pointYGet,
        pointYSet,
    );

    const newCircle = circleCenterYLens.over(circle, struct {
        fn f(y: i32) i32 {
            return y + 100;
        }
    }.f);

    try std.testing.expectEqual(@as(i32, 5), newCircle.center.x);
    try std.testing.expectEqual(@as(i32, 110), newCircle.center.y);
}

// ============ Lens 法则测试 ============

test "Lens GetPut law" {
    // lens.set(s, lens.get(s)) == s
    const point = Point{ .x = 10, .y = 20 };
    const result = pointXLens.put(point, pointXLens.view(point));

    try std.testing.expectEqual(point.x, result.x);
    try std.testing.expectEqual(point.y, result.y);
}

test "Lens PutGet law" {
    // lens.get(lens.set(s, a)) == a
    const point = Point{ .x = 10, .y = 20 };
    const newX: i32 = 100;
    const result = pointXLens.view(pointXLens.put(point, newX));

    try std.testing.expectEqual(newX, result);
}

test "Lens PutPut law" {
    // lens.set(lens.set(s, a), b) == lens.set(s, b)
    const point = Point{ .x = 10, .y = 20 };
    const a: i32 = 50;
    const b: i32 = 100;

    const lhs = pointXLens.put(pointXLens.put(point, a), b);
    const rhs = pointXLens.put(point, b);

    try std.testing.expectEqual(lhs.x, rhs.x);
    try std.testing.expectEqual(lhs.y, rhs.y);
}
