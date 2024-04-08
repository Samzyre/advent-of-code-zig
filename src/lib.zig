const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const math = std.math;
const testing = std.testing;

/// Hacky allocator for hacky situations.
var aoc_allocator: ?mem.Allocator = null;

pub fn allocator() mem.Allocator {
    return aoc_allocator.?;
}

pub fn setAllocator(alloc: mem.Allocator) void {
    aoc_allocator = alloc;
}

pub fn intToString(alloc: mem.Allocator, value: anytype) ![]u8 {
    return std.fmt.allocPrint(alloc, "{d}", .{value});
}

pub fn Coord(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,

        const Self = @This();

        pub fn new(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn distance(self: Self, other: Self) usize {
            const x = if (self.x < other.x) other.x - self.x else self.x - other.x;
            const y = if (self.y < other.y) other.y - self.y else self.y - other.y;
            return x + y;
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn format(
            self: Self,
            comptime _fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = _fmt;
            _ = options;
            try writer.print("({d}, {d})", .{ self.x, self.y });
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        z: T,

        const Self = @This();

        pub fn new(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }

        pub fn isUnsigned(self: Self) bool {
            return self.x >= 0 and self.y >= 0 and self.z >= 0;
        }

        pub fn normalized(self: Self) Self {
            return .{
                .x = math.clamp(self.x, -1, 1),
                .y = math.clamp(self.y, -1, 1),
                .z = math.clamp(self.z, -1, 1),
            };
        }

        pub fn inBoundsXY(self: Self, x0: T, y0: T, x1: T, y1: T) bool {
            return self.x >= x0 and
                self.x <= x1 and
                self.y >= y0 and
                self.y <= y1;
        }

        pub fn distance(self: Self, other: Self) T {
            return math.sqrt(math.pow(T, other.x - self.x, 2) +
                math.pow(T, other.y - self.y, 2) +
                math.pow(T, other.z - self.z, 2));
        }

        pub fn length(self: Self) T {
            return math.sqrt(math.pow(T, self.x, 2) +
                math.pow(T, self.y, 2) +
                math.pow(T, self.z, 2));
        }

        pub fn dot(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        pub fn crossXY(self: Self, other: Self) T {
            return self.x * other.y - self.y * other.x;
        }

        pub fn cross(self: Self, other: Self) Self {
            return .{
                .x = self.y * other.z - self.z * other.y,
                .y = self.z * other.x - self.x * other.z,
                .z = self.x * other.y - self.y * other.x,
            };
        }

        pub fn mul(self: Self, n: T) Self {
            return .{
                .x = self.x * n,
                .y = self.y * n,
                .z = self.z * n,
            };
        }

        pub fn div(self: Self, n: T) Self {
            return .{
                .x = self.x / n,
                .y = self.y / n,
                .z = self.z / n,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }

        pub fn toFloat(self: Self) Vec3(f64) {
            return .{
                .x = @floatFromInt(self.x),
                .y = @floatFromInt(self.y),
                .z = @floatFromInt(self.z),
            };
        }

        pub fn format(
            self: @This(),
            comptime _fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = _fmt;
            _ = options;
            try writer.print("({d}, {d}, {d})", .{ self.x, self.y, self.z });
        }
    };
}
