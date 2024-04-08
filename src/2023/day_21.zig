const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(isize);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var map = Map.init(alloc);
    defer map.deinit();
    try map.parse(input);
    const out = try map.walk(64);
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var map = Map.init(alloc);
    defer map.deinit();
    try map.parse(input);
    const size = map.height();
    const half = size / 2;
    const p = try map.walkLooping(.{ half, half + size, half + size * 2 });
    // print("{any}\n", .{p});
    const c = p[0];
    const b = (4 * p[1] - 3 * c - p[2]) / 2;
    const a = p[1] - c - b;
    const x = ((26501365 - half) / size);
    const out = a * std.math.pow(usize, x, 2) + b * x + c;
    return lib.intToString(alloc, out);
}

const Map = struct {
    alloc: mem.Allocator,
    rows: std.ArrayList([]const u8),
    start: Coord,

    fn init(alloc: mem.Allocator) Map {
        return .{
            .alloc = alloc,
            .rows = std.ArrayList([]const u8).init(alloc),
            .start = undefined,
        };
    }

    fn deinit(self: *@This()) void {
        self.rows.deinit();
    }

    fn parse(self: *@This(), text: []const u8) !void {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        var y: isize = 0;
        while (lines.next()) |line| {
            try self.rows.append(line);
            if (mem.indexOf(u8, line, "S")) |x| {
                self.start = Coord.new(@intCast(x), y);
            }
            y += 1;
        }
    }

    fn width(self: *const @This()) usize {
        return self.rows.items[0].len;
    }

    fn height(self: *const @This()) usize {
        return self.rows.items.len;
    }

    fn get(self: *const @This(), coord: Coord) u8 {
        const iheight: isize = @intCast(self.height());
        const iwidth: isize = @intCast(self.width());
        const y: usize = @intCast(@mod(coord.y, iheight));
        const x: usize = @intCast(@mod(coord.x, iwidth));
        return self.rows.items[y][x];
    }

    fn walk(self: @This(), steps: usize) !usize {
        const CoordSet = std.AutoArrayHashMap(Coord, void);

        var reach = CoordSet.init(self.alloc);
        defer reach.deinit();
        try reach.put(Coord.new(self.start.x, self.start.y), {});

        var next = CoordSet.init(self.alloc);
        defer next.deinit();

        for (0..steps) |_| {
            for (reach.keys()) |coord| {
                const neighbors = self.getNeighbors(coord);
                for (neighbors) |n| if (n) |valid| {
                    try next.put(valid, {});
                };
            }
            mem.swap(CoordSet, &reach, &next);
            next.clearRetainingCapacity();
        }
        return reach.count();
    }

    fn walkLooping(self: @This(), steps: [3]usize) ![3]usize {
        var out = steps;
        mem.sort(usize, &out, {}, std.sort.asc(usize));
        const max = out[2];
        const CoordSet = std.AutoArrayHashMap(Coord, void);

        var reach = CoordSet.init(self.alloc);
        defer reach.deinit();
        try reach.put(Coord.new(self.start.x, self.start.y), {});

        var next = CoordSet.init(self.alloc);
        defer next.deinit();

        for (0..max) |step| {
            for (reach.keys()) |coord| {
                const neighbors = self.getNeighborsLooping(coord);
                for (neighbors) |n| if (n) |valid| {
                    try next.put(valid, {});
                };
            }
            mem.swap(CoordSet, &reach, &next);
            next.clearRetainingCapacity();

            if (mem.indexOfScalar(usize, &steps, step + 1)) |idx| {
                out[idx] = reach.count();
                // print("{} {} {}\n", .{ idx, step, out[idx] });
            }
        }
        return out;
    }

    fn getNeighbors(self: *const @This(), coord: Coord) [4]?Coord {
        var neighbors = [_]?Coord{null} ** 4;
        if (coord.x > 0) neighbors[0] = Coord.new(coord.x - 1, coord.y);
        if (coord.y > 0) neighbors[1] = Coord.new(coord.x, coord.y - 1);
        if (coord.x < self.rows.items[0].len - 1) neighbors[2] = Coord.new(coord.x + 1, coord.y);
        if (coord.y < self.rows.items.len - 1) neighbors[3] = Coord.new(coord.x, coord.y + 1);
        for (neighbors, 0..) |n, i| if (n) |nbr| {
            if (self.get(nbr) == '#') neighbors[i] = null;
        };
        return neighbors;
    }

    fn getNeighborsLooping(self: *const @This(), coord: Coord) [4]?Coord {
        var neighbors = [_]?Coord{null} ** 4;
        neighbors[0] = Coord.new(coord.x - 1, coord.y);
        neighbors[1] = Coord.new(coord.x, coord.y - 1);
        neighbors[2] = Coord.new(coord.x + 1, coord.y);
        neighbors[3] = Coord.new(coord.x, coord.y + 1);
        for (neighbors, 0..) |n, i| if (n) |nbr| {
            if (self.get(nbr) == '#') neighbors[i] = null;
        };
        return neighbors;
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
        \\
    ;
    const steps: []const [2]usize = &[_][2]usize{
        .{ 6, 16 },
        .{ 10, 50 },
        .{ 50, 1594 },
        .{ 100, 6536 },
        // .{ 500, 167004 },
        // .{ 1000, 668697 },
        // .{ 5000, 16733044 },
    };
    var map = Map.init(t.allocator);
    defer map.deinit();
    try map.parse(input);
    const out_1 = try map.walk(6);
    try t.expectEqual(16, out_1);
    for (steps) |s| {
        const out = try map.walkLooping(.{ s[0], 0, 0 });
        try t.expectEqual(s[1], out[0]);
    }
}
