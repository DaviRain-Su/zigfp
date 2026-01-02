//! Pipe 管道 - 链式操作
//!
//! `Pipe(T)` 提供流畅的 API 进行链式数据处理。

const std = @import("std");

/// Pipe 类型 - 管道操作
pub fn Pipe(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        // ============ 构造函数 ============

        /// 创建管道
        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        // ============ 转换操作 ============

        /// 应用函数并继续管道
        pub fn then(self: Self, comptime U: type, f: *const fn (T) U) Pipe(U) {
            return Pipe(U).init(f(self.value));
        }

        /// 执行副作用函数，不改变值
        pub fn tap(self: Self, f: *const fn (T) void) Self {
            f(self.value);
            return self;
        }

        /// 条件为真时应用函数
        pub fn when(self: Self, cond: bool, f: *const fn (T) T) Self {
            return if (cond) Self.init(f(self.value)) else self;
        }

        /// 条件为假时应用函数
        pub fn unless(self: Self, cond: bool, f: *const fn (T) T) Self {
            return if (!cond) Self.init(f(self.value)) else self;
        }

        // ============ 获取结果 ============

        /// 获取管道中的最终值
        pub fn unwrap(self: Self) T {
            return self.value;
        }

        /// 别名：获取值
        pub fn get(self: Self) T {
            return self.value;
        }

        // ============ 高级操作 ============

        /// 映射操作 - 和 then 相同，但更符合 FP 习惯
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) Pipe(U) {
            return self.then(U, f);
        }

        /// 条件过滤 - 如果谓词为真返回 Some(value)，否则返回 None
        pub fn filter(self: Self, pred: *const fn (T) bool) ?T {
            return if (pred(self.value)) self.value else null;
        }

        /// 应用带副作用的函数，返回原值（别名 tap）
        pub fn effect(self: Self, f: *const fn (T) void) Self {
            return self.tap(f);
        }

        /// 调试输出 - 使用自定义格式化函数
        pub fn debug(self: Self, label: []const u8, formatter: *const fn (T) void) Self {
            _ = label;
            formatter(self.value);
            return self;
        }

        /// 检查值是否满足条件
        pub fn satisfies(self: Self, pred: *const fn (T) bool) bool {
            return pred(self.value);
        }

        /// 将值与另一个值配对
        pub fn zip(self: Self, comptime U: type, other: U) Pipe(struct { T, U }) {
            return Pipe(struct { T, U }).init(.{ self.value, other });
        }

        /// 将值包装到 Option 类型
        pub fn toOption(self: Self) ?T {
            return self.value;
        }

        /// 根据条件选择不同的转换函数
        pub fn branch(
            self: Self,
            comptime U: type,
            cond: bool,
            ifTrue: *const fn (T) U,
            ifFalse: *const fn (T) U,
        ) Pipe(U) {
            return Pipe(U).init(if (cond) ifTrue(self.value) else ifFalse(self.value));
        }

        /// 重复应用函数 n 次
        pub fn repeat(self: Self, n: usize, f: *const fn (T) T) Self {
            var result = self.value;
            var i: usize = 0;
            while (i < n) : (i += 1) {
                result = f(result);
            }
            return Self.init(result);
        }
    };
}

/// 便捷函数：创建管道
pub fn pipe(comptime T: type, value: T) Pipe(T) {
    return Pipe(T).init(value);
}

// ============ OptionPipe - 处理可选值的管道 ============

/// OptionPipe - 处理 ?T 类型的管道
pub fn OptionPipe(comptime T: type) type {
    return struct {
        value: ?T,

        const Self = @This();

        pub fn init(value: ?T) Self {
            return .{ .value = value };
        }

        pub fn some(value: T) Self {
            return .{ .value = value };
        }

        pub fn none() Self {
            return .{ .value = null };
        }

        /// 映射：如果有值则应用函数
        pub fn map(self: Self, comptime U: type, f: *const fn (T) U) OptionPipe(U) {
            return OptionPipe(U).init(if (self.value) |v| f(v) else null);
        }

        /// 扁平映射：函数返回 Option
        pub fn flatMap(self: Self, comptime U: type, f: *const fn (T) ?U) OptionPipe(U) {
            return OptionPipe(U).init(if (self.value) |v| f(v) else null);
        }

        /// 过滤：如果谓词为假则变为 None
        pub fn filter(self: Self, pred: *const fn (T) bool) Self {
            return if (self.value) |v|
                if (pred(v)) self else Self.none()
            else
                self;
        }

        /// 获取值或默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }

        /// 获取值或使用函数计算默认值
        pub fn unwrapOrElse(self: Self, f: *const fn () T) T {
            return self.value orelse f();
        }

        /// 获取原始 Option 值
        pub fn unwrap(self: Self) ?T {
            return self.value;
        }

        /// 检查是否有值
        pub fn isSome(self: Self) bool {
            return self.value != null;
        }

        /// 检查是否为空
        pub fn isNone(self: Self) bool {
            return self.value == null;
        }

        /// 如果有值则执行副作用
        pub fn ifSome(self: Self, f: *const fn (T) void) Self {
            if (self.value) |v| f(v);
            return self;
        }

        /// 如果为空则执行副作用
        pub fn ifNone(self: Self, f: *const fn () void) Self {
            if (self.value == null) f();
            return self;
        }

        /// 与另一个 OptionPipe 组合（如果都有值）
        pub fn and_(self: Self, comptime U: type, other: OptionPipe(U)) OptionPipe(U) {
            return if (self.value != null) other else OptionPipe(U).none();
        }

        /// 或操作：如果为空则使用另一个值
        pub fn or_(self: Self, other: Self) Self {
            return if (self.value != null) self else other;
        }

        /// 将 OptionPipe 转换为普通 Pipe
        pub fn toPipe(self: Self, default: T) Pipe(T) {
            return Pipe(T).init(self.value orelse default);
        }
    };
}

/// 便捷函数：从可选值创建 OptionPipe
pub fn optionPipe(comptime T: type, value: ?T) OptionPipe(T) {
    return OptionPipe(T).init(value);
}

// ============ 测试 ============

test "Pipe.init and unwrap" {
    const p = Pipe(i32).init(42);
    try std.testing.expectEqual(@as(i32, 42), p.unwrap());
}

test "Pipe.then" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .then(i32, double) // 10
        .then(i32, addOne) // 11
        .unwrap();

    try std.testing.expectEqual(@as(i32, 11), result);
}

test "Pipe.then with type conversion" {
    const intToFloat = struct {
        fn f(x: i32) f64 {
            return @floatFromInt(x);
        }
    }.f;

    const doubleFloat = struct {
        fn f(x: f64) f64 {
            return x * 2.0;
        }
    }.f;

    const result = Pipe(i32).init(21)
        .then(f64, intToFloat)
        .then(f64, doubleFloat)
        .unwrap();

    try std.testing.expectEqual(@as(f64, 42.0), result);
}

test "Pipe.tap" {
    const logValue = struct {
        fn f(x: i32) void {
            _ = x;
            // 模拟副作用
        }
    }.f;

    const result = Pipe(i32).init(42)
        .tap(logValue)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "Pipe.when true" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(true, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 10), result);
}

test "Pipe.when false" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(false, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 5), result);
}

test "Pipe.unless" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result1 = Pipe(i32).init(5)
        .unless(false, double)
        .unwrap();
    try std.testing.expectEqual(@as(i32, 10), result1);

    const result2 = Pipe(i32).init(5)
        .unless(true, double)
        .unwrap();
    try std.testing.expectEqual(@as(i32, 5), result2);
}

test "Pipe complex chain" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addOne = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const shouldDouble = true;
    const shouldTriple = false;

    const triple = struct {
        fn f(x: i32) i32 {
            return x * 3;
        }
    }.f;

    const result = Pipe(i32).init(5)
        .when(shouldDouble, double) // 10
        .when(shouldTriple, triple) // 仍是 10
        .then(i32, addOne) // 11
        .unwrap();

    try std.testing.expectEqual(@as(i32, 11), result);
}

test "pipe convenience function" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = pipe(i32, 21)
        .then(i32, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 42), result);
}

// ============ 新增 Pipe 操作测试 ============

test "Pipe.map" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = Pipe(i32).init(21)
        .map(i32, double)
        .unwrap();

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "Pipe.filter true" {
    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const result = Pipe(i32).init(42).filter(isPositive);
    try std.testing.expectEqual(@as(?i32, 42), result);
}

test "Pipe.filter false" {
    const isNegative = struct {
        fn f(x: i32) bool {
            return x < 0;
        }
    }.f;

    const result = Pipe(i32).init(42).filter(isNegative);
    try std.testing.expectEqual(@as(?i32, null), result);
}

test "Pipe.satisfies" {
    const isEven = struct {
        fn f(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.f;

    try std.testing.expect(Pipe(i32).init(42).satisfies(isEven));
    try std.testing.expect(!Pipe(i32).init(41).satisfies(isEven));
}

test "Pipe.zip" {
    const result = Pipe(i32).init(1)
        .zip([]const u8, "hello")
        .unwrap();

    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqualStrings("hello", result[1]);
}

test "Pipe.toOption" {
    const opt = Pipe(i32).init(42).toOption();
    try std.testing.expectEqual(@as(?i32, 42), opt);
}

test "Pipe.branch" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const negate = struct {
        fn f(x: i32) i32 {
            return -x;
        }
    }.f;

    const resultTrue = Pipe(i32).init(5).branch(i32, true, double, negate).unwrap();
    try std.testing.expectEqual(@as(i32, 10), resultTrue);

    const resultFalse = Pipe(i32).init(5).branch(i32, false, double, negate).unwrap();
    try std.testing.expectEqual(@as(i32, -5), resultFalse);
}

test "Pipe.repeat" {
    const increment = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const result = Pipe(i32).init(0).repeat(5, increment).unwrap();
    try std.testing.expectEqual(@as(i32, 5), result);
}

// ============ OptionPipe 测试 ============

test "OptionPipe.init" {
    const some = OptionPipe(i32).init(42);
    try std.testing.expectEqual(@as(?i32, 42), some.unwrap());

    const none = OptionPipe(i32).init(null);
    try std.testing.expectEqual(@as(?i32, null), none.unwrap());
}

test "OptionPipe.some and none" {
    const some = OptionPipe(i32).some(42);
    try std.testing.expect(some.isSome());
    try std.testing.expect(!some.isNone());

    const none = OptionPipe(i32).none();
    try std.testing.expect(!none.isSome());
    try std.testing.expect(none.isNone());
}

test "OptionPipe.map with some" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = OptionPipe(i32).some(21)
        .map(i32, double)
        .unwrap();

    try std.testing.expectEqual(@as(?i32, 42), result);
}

test "OptionPipe.map with none" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const result = OptionPipe(i32).none()
        .map(i32, double)
        .unwrap();

    try std.testing.expectEqual(@as(?i32, null), result);
}

test "OptionPipe.flatMap with some returning some" {
    const safeDivide = struct {
        fn f(x: i32) ?i32 {
            return if (x != 0) @divTrunc(100, x) else null;
        }
    }.f;

    const result = OptionPipe(i32).some(5)
        .flatMap(i32, safeDivide)
        .unwrap();

    try std.testing.expectEqual(@as(?i32, 20), result);
}

test "OptionPipe.flatMap with some returning none" {
    const safeDivide = struct {
        fn f(x: i32) ?i32 {
            return if (x != 0) @divTrunc(100, x) else null;
        }
    }.f;

    const result = OptionPipe(i32).some(0)
        .flatMap(i32, safeDivide)
        .unwrap();

    try std.testing.expectEqual(@as(?i32, null), result);
}

test "OptionPipe.filter" {
    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const positive = OptionPipe(i32).some(42).filter(isPositive);
    try std.testing.expect(positive.isSome());

    const negative = OptionPipe(i32).some(-42).filter(isPositive);
    try std.testing.expect(negative.isNone());

    const none = OptionPipe(i32).none().filter(isPositive);
    try std.testing.expect(none.isNone());
}

test "OptionPipe.unwrapOr" {
    try std.testing.expectEqual(@as(i32, 42), OptionPipe(i32).some(42).unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 0), OptionPipe(i32).none().unwrapOr(0));
}

test "OptionPipe.unwrapOrElse" {
    const getDefault = struct {
        fn f() i32 {
            return 99;
        }
    }.f;

    try std.testing.expectEqual(@as(i32, 42), OptionPipe(i32).some(42).unwrapOrElse(getDefault));
    try std.testing.expectEqual(@as(i32, 99), OptionPipe(i32).none().unwrapOrElse(getDefault));
}

test "OptionPipe.and_" {
    const some1 = OptionPipe(i32).some(1);
    const some2 = OptionPipe([]const u8).some("hello");
    const noneStr = OptionPipe([]const u8).none();

    // some.and_(some) = some
    const result1 = some1.and_([]const u8, some2);
    try std.testing.expect(result1.isSome());

    // some.and_(none) = none
    const result2 = some1.and_([]const u8, noneStr);
    try std.testing.expect(result2.isNone());

    // none.and_(some) = none
    const noneInt = OptionPipe(i32).none();
    const result3 = noneInt.and_([]const u8, some2);
    try std.testing.expect(result3.isNone());
}

test "OptionPipe.or_" {
    const some1 = OptionPipe(i32).some(1);
    const some2 = OptionPipe(i32).some(2);
    const none = OptionPipe(i32).none();

    // some.or_(some) = first some
    try std.testing.expectEqual(@as(?i32, 1), some1.or_(some2).unwrap());

    // some.or_(none) = some
    try std.testing.expectEqual(@as(?i32, 1), some1.or_(none).unwrap());

    // none.or_(some) = some
    try std.testing.expectEqual(@as(?i32, 2), none.or_(some2).unwrap());

    // none.or_(none) = none
    try std.testing.expectEqual(@as(?i32, null), none.or_(none).unwrap());
}

test "OptionPipe.toPipe" {
    const result1 = OptionPipe(i32).some(42).toPipe(0).unwrap();
    try std.testing.expectEqual(@as(i32, 42), result1);

    const result2 = OptionPipe(i32).none().toPipe(99).unwrap();
    try std.testing.expectEqual(@as(i32, 99), result2);
}

test "OptionPipe chaining" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const isPositive = struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f;

    const result = OptionPipe(i32).some(5)
        .map(i32, double) // 10
        .filter(isPositive) // still 10
        .map(i32, double) // 20
        .unwrapOr(0);

    try std.testing.expectEqual(@as(i32, 20), result);
}

test "optionPipe convenience function" {
    const some = optionPipe(i32, 42);
    try std.testing.expect(some.isSome());

    const none = optionPipe(i32, null);
    try std.testing.expect(none.isNone());
}
