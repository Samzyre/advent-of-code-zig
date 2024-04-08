const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(u32);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const map = try Map.parseInit(alloc, input);
    defer map.deinit();
    const out = try map.loopSize() / 2;
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const map = try Map.parseInit(alloc, input);
    defer map.deinit();
    const out = try map.enclosedSize();
    return lib.intToString(alloc, out);
}

const Map = struct {
    start: Coord = Coord{},
    width: u32 = 0,
    height: u32 = 0,
    rows: std.ArrayList(std.ArrayList(u8)),

    fn init(alloc: mem.Allocator) Map {
        return .{ .rows = std.ArrayList(std.ArrayList(u8)).init(alloc) };
    }

    fn deinit(self: @This()) void {
        for (self.rows.items) |r| r.deinit();
        self.rows.deinit();
    }

    fn parseInit(alloc: mem.Allocator, text: []const u8) !Map {
        var self = Map.init(alloc);
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        var row: u32 = 0;
        while (lines.next()) |line| {
            if (mem.indexOfScalar(u8, line, 'S')) |start| {
                self.start = Coord{ .x = @intCast(start), .y = @intCast(row) };
            }
            var bytes = try std.ArrayList(u8).initCapacity(alloc, 140);
            try bytes.appendSlice(line);
            try self.rows.append(bytes);
            row += 1;
        }
        self.width = @intCast(self.rows.items[0].items.len);
        self.height = row;
        return self;
    }

    fn getCoordTile(self: @This(), coord: Coord) Tile {
        return Tile{
            .shape = Shape.from(self.getCoordByte(coord)),
            .coord = coord,
        };
    }

    fn getCoordByte(self: @This(), coord: Coord) u8 {
        return self.rows.items[coord.y].items[coord.x];
    }

    fn getNeighborCoords(self: *const @This(), coord: Coord) [4]?Coord {
        var coords = [_]?Coord{null} ** 4;
        if (coord.x > 0)
            coords[@intFromEnum(Direction.left)] = Coord{ .x = coord.x - 1, .y = coord.y };
        if (coord.y > 0)
            coords[@intFromEnum(Direction.up)] = Coord{ .x = coord.x, .y = coord.y - 1 };
        if (coord.x < self.width - 1)
            coords[@intFromEnum(Direction.right)] = Coord{ .x = coord.x + 1, .y = coord.y };
        if (coord.y < self.height - 1)
            coords[@intFromEnum(Direction.down)] = Coord{ .x = coord.x, .y = coord.y + 1 };
        return coords;
    }

    fn getConnectedTiles(self: @This(), current: Tile) [4]?Tile {
        var connected = [_]?Tile{null} ** 4;
        var index: u32 = 0;
        const neighbors = self.getNeighborCoords(current.coord);
        for (neighbors) |n| if (n) |valid| {
            const other = self.getCoordTile(valid);
            if (current.canConnect(other)) {
                connected[index] = other;
                index += 1;
            }
        };
        return connected;
    }

    const Loop = struct {
        path: std.AutoArrayHashMap(Tile, void),

        fn init(alloc: mem.Allocator) @This() {
            return .{ .path = std.AutoArrayHashMap(Tile, void).init(alloc) };
        }

        fn deinit(self: *@This()) void {
            self.path.deinit();
        }

        fn find(self: *@This(), map: *const Map, tile: Tile) !?[]Tile {
            try self.path.put(tile, {});
            const array = self.path.keys();
            for (map.getConnectedTiles(tile)) |n| if (n) |next| {
                if (self.path.contains(next)) {
                    if (next.eql(array[0]) and array.len > 2) {
                        return self.path.keys();
                    }
                    continue;
                }
                if (try self.find(map, next)) |ret| return ret;
            };
            // Reset if no loop was found (start tile would have dangling connections).
            for (1..self.path.count()) |_| _ = self.path.pop();
            return null;
        }
    };

    const NoSolution = error{NoSolution}.NoSolution;

    fn loopSize(self: @This()) !usize {
        const alloc = self.rows.allocator;
        var loop = Loop.init(alloc);
        defer loop.deinit();
        if (try loop.find(&self, self.getCoordTile(self.start))) |l| return l.len;
        return NoSolution;
    }

    fn enclosedSize(self: @This()) !usize {
        const alloc = self.rows.allocator;
        var loop = Loop.init(alloc);
        defer loop.deinit();
        const loop_tiles = try loop.find(&self, self.getCoordTile(self.start)) orelse {
            return NoSolution;
        };
        var sum: isize = 0;
        for (loop_tiles, 1..) |this, idx| {
            const next = loop_tiles[idx % loop_tiles.len];
            sum += @as(isize, this.coord.x * next.coord.y) -
                @as(isize, next.coord.x * this.coord.y);
        }
        return @abs(sum) / 2 - loop_tiles.len / 2 + 1;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{}\n", .{self.start});
        for (self.rows.items) |row| {
            try writer.print("{s}\n", .{row.items});
        }
    }
};

const Tile = struct {
    shape: Shape,
    coord: Coord,

    fn relationTo(self: @This(), other: @This()) ?Direction {
        if (self.coord.x < other.coord.x) {
            return .left;
        } else if (self.coord.x > other.coord.x) {
            return .right;
        } else if (self.coord.y < other.coord.y) {
            return .up;
        } else if (self.coord.y > other.coord.y) {
            return .down;
        } else {
            return null;
        }
    }

    fn canConnect(self: @This(), other: @This()) bool {
        return switch (other.relationTo(self).?) {
            .up => self.hasNorth() and other.hasSouth(),
            .down => self.hasSouth() and other.hasNorth(),
            .left => self.hasWest() and other.hasEast(),
            .right => self.hasEast() and other.hasWest(),
        };
    }

    fn hasNorth(self: @This()) bool {
        return switch (self.shape) {
            .start, .north_south, .north_east, .north_west => true,
            .none, .west_east, .south_west, .south_east => false,
        };
    }

    fn hasSouth(self: @This()) bool {
        return switch (self.shape) {
            .start, .north_south, .south_west, .south_east => true,
            .none, .west_east, .north_east, .north_west => false,
        };
    }

    fn hasWest(self: @This()) bool {
        return switch (self.shape) {
            .start, .west_east, .north_west, .south_west => true,
            .none, .north_south, .north_east, .south_east => false,
        };
    }

    fn hasEast(self: @This()) bool {
        return switch (self.shape) {
            .start, .west_east, .north_east, .south_east => true,
            .none, .north_south, .north_west, .south_west => false,
        };
    }

    fn eql(self: @This(), other: @This()) bool {
        return self.coord.eql(other.coord) and self.shape == other.shape;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{} {}", .{ self.shape, self.coord });
    }
};

const Direction = enum {
    up,
    down,
    left,
    right,
};

const Shape = enum {
    north_south,
    north_east,
    north_west,
    south_west,
    south_east,
    west_east,
    start,
    none,

    fn from(byte: u8) Shape {
        return switch (byte) {
            '|' => .north_south,
            '-' => .west_east,
            'L' => .north_east,
            'J' => .north_west,
            '7' => .south_west,
            'F' => .south_east,
            'S' => .start,
            else => .none,
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
        const b: u8 = switch (self) {
            .north_south => '|',
            .west_east => '-',
            .north_east => 'L',
            .north_west => 'J',
            .south_west => '7',
            .south_east => 'F',
            .start => 'S',
            .none => '.',
        };
        try writer.print("{c}", .{b});
    }
};

test "test" {
    const t = std.testing;
    const input_1 =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
        \\
    ;
    const input_2 =
        \\...........
        \\.S-------7.
        \\.|F-----7|.
        \\.||.....||.
        \\.||.....||.
        \\.|L-7.F-J|.
        \\.|..|.|..|.
        \\.L--J.L--J.
        \\...........
        \\
    ;
    const input_3 =
        \\.F----7F7F7F7F-7....
        \\.|F--7||||||||FJ....
        \\.||.FJ||||||||L7....
        \\FJL7L7LJLJ||LJ.L-7..
        \\L--J.L7...LJS7F-7L7.
        \\....F-J..F7FJ|L7L7L7
        \\....L7.F7||L7|.L7L7|
        \\.....|FJLJ|FJ|F7|.LJ
        \\....FJL-7.||.||||...
        \\....L---J.LJ.LJLJ...
        \\
    ;
    const input_4 =
        \\FF7FSF7F7F7F7F7F---7
        \\L|LJ||||||||||||F--J
        \\FL-7LJLJ||||||LJL-77
        \\F--JF--7||LJLJ7F7FJ-
        \\L---JF-JLJ.||-FJLJJ7
        \\|F|F-JF---7F7-L7L|7|
        \\|FFJF7L7F-JF7|JL---7
        \\7-L-JL7||F7|L7F-7F7|
        \\L.L7LFJ|||||FJL7||LJ
        \\L7JLJL-JLJLJL--JLJ.L
        \\
    ;
    const out_1 = try part_1(t.allocator, input_1);
    const out_2 = try part_2(t.allocator, input_2);
    const out_3 = try part_2(t.allocator, input_3);
    const out_4 = try part_2(t.allocator, input_4);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    defer t.allocator.free(out_3);
    defer t.allocator.free(out_4);
    try t.expectEqualStrings("8", out_1);
    try t.expectEqualStrings("4", out_2);
    try t.expectEqualStrings("8", out_3);
    try t.expectEqualStrings("10", out_4);
}
