const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(u8);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var rows = std.ArrayList([]const u8).init(alloc);
    defer rows.deinit();
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        try rows.append(line);
    }
    const map = Map{ .map = rows.items };
    const start = Coord{ .x = 0, .y = 0 };
    const end = Coord{ .x = map.width() - 1, .y = map.height() - 1 };
    const out = try search(alloc, map, start, end, 0, 3);
    return lib.intToString(alloc, out.?);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var rows = std.ArrayList([]const u8).init(alloc);
    defer rows.deinit();
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        try rows.append(line);
    }
    const map = Map{ .map = rows.items };
    const start = Coord{ .x = 0, .y = 0 };
    const end = Coord{ .x = map.width() - 1, .y = map.height() - 1 };
    const out = try search(alloc, map, start, end, 4, 10);
    return lib.intToString(alloc, out.?);
}

fn search(alloc: mem.Allocator, map: Map, start: Coord, end: Coord, min: usize, max: usize) !?usize {
    var dist = std.AutoArrayHashMap(State, usize).init(alloc);
    defer dist.deinit();
    var heap = std.PriorityQueue(State, Dist, lessThan).init(alloc, &dist);
    defer heap.deinit();
    const start_state = State{ .coord = start, .dir = .none, .count = 0 };
    try heap.add(start_state);
    try dist.put(start_state, 0);

    while (heap.removeOrNull()) |state| {
        if (state.coord.eql(end)) return dist.get(state).?;

        const distance = dist.get(state).?;
        const neighbors = map.neighbors(state.coord);
        next: for (neighbors) |opt| if (opt) |neighbor| {
            const neighbor_tile = neighbor[0];
            const neighbor_dir = neighbor[1];

            if (state.dir.reverse() == neighbor_dir) continue;
            if (state.dir != .none and state.dir != neighbor_dir and state.count < min) continue;
            const count = if (state.dir == neighbor_dir) state.count + 1 else 1;
            if (count > max) continue;
            const next_state = State{
                .coord = neighbor_tile.coord,
                .dir = neighbor_dir,
                .count = count,
            };

            const other = try dist.getOrPutValue(next_state, std.math.maxInt(usize));
            const tentative = distance + neighbor_tile.value - '0';
            if (tentative < other.value_ptr.*) {
                other.value_ptr.* = tentative;
                for (heap.items) |item| if (item.eql(next_state)) continue :next;
                try heap.add(next_state);
            }
        };
    }
    return null;
}

fn lessThan(context: Dist, a: State, b: State) std.math.Order {
    const aa = context.getOrPutValue(a, std.math.maxInt(usize)) catch unreachable;
    const bb = context.getOrPutValue(b, std.math.maxInt(usize)) catch unreachable;
    return std.math.order(aa.value_ptr.*, bb.value_ptr.*);
}

const Dist = *std.AutoArrayHashMap(State, usize);

const State = struct {
    coord: Coord,
    dir: Direction,
    count: u8,

    const Self = @This();

    fn eql(self: Self, other: Self) bool {
        return self.coord.eql(other.coord) and
            self.dir == other.dir and
            self.count == other.count;
    }
};

const Map = struct {
    map: [][]const u8,

    const Self = @This();

    fn width(self: *const Self) u8 {
        return @intCast(self.map[0].len);
    }

    fn height(self: *const Self) u8 {
        return @intCast(self.map.len);
    }

    fn tile(self: *const Self, x: u8, y: u8) Tile {
        return .{ .value = self.map[y][x], .coord = .{ .x = x, .y = y } };
    }

    fn neighbors(self: *const Self, coord: Coord) [4]?struct { Tile, Direction } {
        var tiles = [_]?struct { Tile, Direction }{null} ** 4;
        if (coord.x > 0) tiles[0] = .{ self.tile(coord.x - 1, coord.y), .left };
        if (coord.y > 0) tiles[1] = .{ self.tile(coord.x, coord.y - 1), .up };
        if (coord.x < self.width() - 1) tiles[2] = .{ self.tile(coord.x + 1, coord.y), .right };
        if (coord.y < self.height() - 1) tiles[3] = .{ self.tile(coord.x, coord.y + 1), .down };
        return tiles;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        for (self.map) |row| {
            try writer.print("{s}\n", .{row});
        }
    }
};

const Tile = struct {
    value: u8,
    coord: Coord,

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{} {c}", .{ self.coord, self.value });
    }
};

const Direction = enum {
    up,
    down,
    left,
    right,
    none,

    const Self = @This();

    fn reverse(self: Self) Self {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
            .none => .none,
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
        try writer.print("{s}", .{@tagName(self)});
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("102", out_1);
    try t.expectEqualStrings("94", out_2);
}
