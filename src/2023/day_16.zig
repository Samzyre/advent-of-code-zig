const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(i32);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var map = std.ArrayList([]const u8).init(alloc);
    defer map.deinit();
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        try map.append(line);
    }
    var field = Field.init(alloc, map.items);
    defer field.deinit();
    field.queue.append(.{});
    const out = field.energized();
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var map = std.ArrayList([]const u8).init(alloc);
    defer map.deinit();
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        try map.append(line);
    }
    var max: u32 = 0;
    for (0..map.items.len) |row| {
        {
            var field = Field.init(alloc, map.items);
            defer field.deinit();
            field.queue.append(.{ .y = @intCast(row), .dir = .right });
            max = @max(max, field.energized());
        }
        {
            var field = Field.init(alloc, map.items);
            defer field.deinit();
            field.queue.append(.{ .x = @intCast(field.map[0].len - 1), .y = @intCast(row), .dir = .left });
            max = @max(max, field.energized());
        }
    }
    for (0..map.items[0].len) |col| {
        {
            var field = Field.init(alloc, map.items);
            defer field.deinit();
            field.queue.append(.{ .x = @intCast(col), .dir = .down });
            max = @max(max, field.energized());
        }
        {
            var field = Field.init(alloc, map.items);
            defer field.deinit();
            field.queue.append(.{ .x = @intCast(col), .y = @intCast(field.map.len - 1), .dir = .up });
            max = @max(max, field.energized());
        }
    }
    return lib.intToString(alloc, max);
}

const Field = struct {
    alloc: mem.Allocator,
    queue: CursorQueue,
    map: [][]const u8,

    const Self = @This();

    fn init(alloc: mem.Allocator, map: [][]const u8) Self {
        return .{
            .alloc = alloc,
            .queue = CursorQueue.init(alloc),
            .map = map,
        };
    }

    fn deinit(self: *Self) void {
        self.queue.deinit();
    }

    fn energized(self: *Self) u32 {
        var sum: u32 = 0;
        sum += self.queue.walk(self.map);
        return sum;
    }
};

const CursorQueue = struct {
    alloc: mem.Allocator,
    queue: std.ArrayList(Cursor),
    visited: std.AutoArrayHashMap(Cursor, void),
    unique: std.AutoArrayHashMap(Coord, void),

    const Self = @This();

    fn init(alloc: mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .queue = std.ArrayList(Cursor).init(alloc),
            .visited = std.AutoArrayHashMap(Cursor, void).init(alloc),
            .unique = std.AutoArrayHashMap(Coord, void).init(alloc),
        };
    }

    fn deinit(self: *Self) void {
        self.queue.deinit();
        self.visited.deinit();
        self.unique.deinit();
    }

    fn append(self: *Self, cursor: Cursor) void {
        self.queue.append(cursor) catch unreachable;
    }

    fn pop(self: *Self) ?Cursor {
        return self.queue.popOrNull();
    }

    fn walk(self: *Self, map: [][]const u8) u32 {
        while (self.pop()) |b| {
            var cursor = b;
            if (self.visited.contains(cursor)) continue;
            self.visited.put(cursor, {}) catch unreachable;
            self.unique.put(cursor.coord(), {}) catch unreachable;
            // print("{}\n", .{cursor});
            const tile = map[@intCast(cursor.y)][@intCast(cursor.x)];
            const next = cursor.next(tile);
            if (next[1]) |alt| {
                if (alt.inBounds(map)) {
                    self.append(alt);
                }
            }
            const this = next[0];
            if (this.inBounds(map)) {
                self.append(this);
            }
        }
        return @intCast(self.unique.count());
    }
};

const Cursor = struct {
    dir: Direction = .right,
    x: i32 = 0,
    y: i32 = 0,

    const Self = @This();

    fn coord(self: Self) Coord {
        return .{ .x = self.x, .y = self.y };
    }

    fn inBounds(self: Self, map: [][]const u8) bool {
        return !((self.y < 0 and self.dir == .up) or
            (self.y > map.len - 1 and self.dir == .down) or
            (self.x < 0 and self.dir == .left) or
            (self.x > map[0].len - 1 and self.dir == .right));
    }

    fn next(self: Self, tile: u8) struct { Cursor, ?Cursor } {
        return switch (tile) {
            '/' => switch (self.dir) {
                .up => .{ .{ .x = self.x +| 1, .y = self.y, .dir = .right }, null },
                .down => .{ .{ .x = self.x -| 1, .y = self.y, .dir = .left }, null },
                .left => .{ .{ .x = self.x, .y = self.y +| 1, .dir = .down }, null },
                .right => .{ .{ .x = self.x, .y = self.y -| 1, .dir = .up }, null },
            },
            '\\' => switch (self.dir) {
                .up => .{ .{ .x = self.x -| 1, .y = self.y, .dir = .left }, null },
                .down => .{ .{ .x = self.x +| 1, .y = self.y, .dir = .right }, null },
                .left => .{ .{ .x = self.x, .y = self.y -| 1, .dir = .up }, null },
                .right => .{ .{ .x = self.x, .y = self.y +| 1, .dir = .down }, null },
            },
            '-' => switch (self.dir) {
                .up, .down => .{
                    .{ .x = self.x -| 1, .y = self.y, .dir = .left },
                    .{ .x = self.x +| 1, .y = self.y, .dir = .right },
                },
                .left => .{ .{ .x = self.x -| 1, .y = self.y, .dir = self.dir }, null },
                .right => .{ .{ .x = self.x +| 1, .y = self.y, .dir = self.dir }, null },
            },
            '|' => switch (self.dir) {
                .up => .{ .{ .x = self.x, .y = self.y -| 1, .dir = self.dir }, null },
                .down => .{ .{ .x = self.x, .y = self.y +| 1, .dir = self.dir }, null },
                .left, .right => .{
                    .{ .x = self.x, .y = self.y -| 1, .dir = .up },
                    .{ .x = self.x, .y = self.y +| 1, .dir = .down },
                },
            },
            else => switch (self.dir) {
                .up => .{ .{ .x = self.x, .y = self.y -| 1, .dir = self.dir }, null },
                .down => .{ .{ .x = self.x, .y = self.y +| 1, .dir = self.dir }, null },
                .left => .{ .{ .x = self.x -| 1, .y = self.y, .dir = self.dir }, null },
                .right => .{ .{ .x = self.x +| 1, .y = self.y, .dir = self.dir }, null },
            },
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
        try writer.print("({d}, {d}) {s}", .{ self.x, self.y, @tagName(self.dir) });
    }
};

const Direction = enum {
    up,
    down,
    left,
    right,
};

test "test" {
    const t = std.testing;
    const input =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("46", out_1);
    try t.expectEqualStrings("51", out_2);
}
