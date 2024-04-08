const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(u8);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList([]const u8).init(alloc);
    defer buf.deinit();
    const map = try Map.parse(&buf, input);
    const out = try map.hike_slippery(alloc);
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList([]const u8).init(alloc);
    defer buf.deinit();
    const map = try Map.parse(&buf, input);
    const out = try map.hike_climb(alloc);
    return lib.intToString(alloc, out);
}

const Map = struct {
    rows: []const []const u8,
    start: Coord,
    end: Coord,

    const Self = @This();

    fn parse(buf: *std.ArrayList([]const u8), text: []const u8) !Self {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| try buf.append(line);
        return .{
            .rows = buf.items,
            .start = Coord.new(@intCast(mem.indexOfScalar(u8, buf.items[0], '.').?), 0),
            .end = Coord.new(
                @intCast(mem.lastIndexOfScalar(u8, buf.items[buf.items.len - 1], '.').?),
                @intCast(buf.items.len - 1),
            ),
        };
    }

    fn width(self: *const Self) u8 {
        return @intCast(self.rows[0].len);
    }

    fn height(self: *const Self) u8 {
        return @intCast(self.rows.len);
    }

    fn tile(self: *const Self, coord: Coord) u8 {
        return self.rows[coord.y][coord.x];
    }

    fn valid(self: *const Self, coord: Coord) bool {
        return coord.x < self.width() and coord.y < self.height();
    }

    fn neighbors(self: *const Self, coord: Coord) [4]?Coord {
        var coords = [_]?Coord{null} ** 4;
        if (coord.x > 0) coords[@intFromEnum(Dir.left)] =
            Coord{ .x = coord.x - 1, .y = coord.y };
        if (coord.y > 0) coords[@intFromEnum(Dir.up)] =
            Coord{ .x = coord.x, .y = coord.y - 1 };
        if (coord.x < self.width() - 1) coords[@intFromEnum(Dir.right)] =
            Coord{ .x = coord.x + 1, .y = coord.y };
        if (coord.y < self.height() - 1) coords[@intFromEnum(Dir.down)] =
            Coord{ .x = coord.x, .y = coord.y + 1 };
        return coords;
    }

    const To = struct { Coord, usize };
    fn getNodes(
        self: Self,
        nodes: *std.AutoArrayHashMap(Coord, std.ArrayList(To)),
    ) !void {
        const State = struct {
            origin: Coord,
            previous: Coord,
            current: Coord,
            length: usize,
        };
        var visited = std.AutoArrayHashMap([2]Coord, void).init(nodes.allocator);
        defer visited.deinit();
        var queue = std.ArrayList(State).init(nodes.allocator);
        defer queue.deinit();
        try queue.append(State{
            .origin = self.start,
            .previous = self.start,
            .current = self.start,
            .length = 0,
        });
        while (queue.popOrNull()) |state| {
            if (state.current.eql(self.end)) {
                var targets = try nodes.getOrPutValue(
                    state.origin,
                    std.ArrayList(To).init(nodes.allocator),
                );
                try targets.value_ptr.append(.{ state.current, state.length });
                continue;
            }
            var count: usize = 0;
            var other: [4]?Coord = [_]?Coord{null} ** 4;
            for (self.neighbors(state.current)) |opt| if (opt) |coord| {
                if (self.tile(coord) == '#') continue;
                if (coord.eql(state.previous)) continue;
                if (visited.contains(.{ state.current, coord })) continue;
                other[count] = coord;
                count += 1;
            };
            if (count > 1) {
                var targets = try nodes.getOrPutValue(
                    state.origin,
                    std.ArrayList(To).init(nodes.allocator),
                );
                try targets.value_ptr.append(.{ state.current, state.length });
                inline for (other) |opt| if (opt) |coord| {
                    try queue.append(State{
                        .origin = state.current,
                        .previous = state.current,
                        .current = coord,
                        .length = 1,
                    });
                };
            } else {
                inline for (other) |opt| if (opt) |coord| {
                    try visited.put(.{ state.current, coord }, {});
                    try queue.append(State{
                        .origin = state.origin,
                        .previous = state.current,
                        .current = coord,
                        .length = state.length + 1,
                    });
                };
            }
        }
    }

    fn hike_climb(self: *const Self, alloc: mem.Allocator) !usize {
        var nodes = std.AutoArrayHashMap(Coord, std.ArrayList(To)).init(alloc);
        defer {
            for (nodes.values()) |v| v.deinit();
            nodes.deinit();
        }
        try self.getNodes(&nodes);
        // var iter = nodes.iterator();
        // while (iter.next()) |n| {
        //     print("{} {any}\n", .{ n.key_ptr.*, n.value_ptr.items });
        // }
        const State = struct {
            path: std.ArrayList(Coord),
            length: usize,
        };
        var queue = std.ArrayList(State).init(alloc);
        defer queue.deinit();
        var init = std.ArrayList(Coord).init(alloc);
        try init.append(self.start);
        try queue.append(State{
            .path = init,
            .length = 0,
        });
        var max: usize = 0;
        while (queue.popOrNull()) |state| {
            defer @constCast(&state.path).deinit();
            const current = state.path.getLast();
            if (current.eql(self.end)) {
                // print("{any}\n", .{state.path.items});
                max = @max(max, state.length);
                continue;
            }
            if (nodes.get(current)) |targets| {
                next: for (targets.items) |pair| {
                    const node = pair[0];
                    for (state.path.items) |prev| if (prev.eql(node)) continue :next;
                    var new_path = try state.path.clone();
                    try new_path.append(node);
                    try queue.append(State{
                        .path = new_path,
                        .length = state.length + pair[1],
                    });
                }
            }
        }
        return max;
    }

    fn hike_slippery(self: *const Self, alloc: mem.Allocator) !usize {
        const State = struct {
            path: std.ArrayList(Coord),
            current: Coord,
        };
        var queue = std.ArrayList(State).init(alloc);
        defer queue.deinit();
        try queue.append(State{
            .path = std.ArrayList(Coord).init(alloc),
            .current = self.start,
        });
        var max: usize = 0;
        while (queue.popOrNull()) |state| {
            defer @constCast(&state.path).deinit();
            if (state.current.eql(self.end)) {
                max = @max(max, state.path.items.len);
                continue;
            }
            next: for (self.neighbors(state.current), 0..) |opt, dir| if (opt) |coord| {
                const neighbor = self.tile(coord);
                switch (neighbor) {
                    '.' => {},
                    '#' => continue,
                    '^' => if (dir == @intFromEnum(Dir.down)) continue,
                    'v' => if (dir == @intFromEnum(Dir.up)) continue,
                    '<' => if (dir == @intFromEnum(Dir.right)) continue,
                    '>' => if (dir == @intFromEnum(Dir.left)) continue,
                    else => @panic("unknown last tile"),
                }
                for (state.path.items) |prev| if (prev.eql(coord)) continue :next;
                var path = try state.path.clone();
                try path.append(state.current);
                try queue.append(State{
                    .path = path,
                    .current = coord,
                });
            };
        }
        return max;
    }
};

const Dir = enum(u2) {
    up,
    down,
    left,
    right,
};

test "test" {
    const t = std.testing;
    const input =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("94", out_1);
    try t.expectEqualStrings("154", out_2);
}
