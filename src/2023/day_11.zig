const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Coord = lib.Coord(usize);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const sum = try process(alloc, input, 2);
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const sum = try process(alloc, input, 1000000);
    return lib.intToString(alloc, sum);
}

fn process(alloc: mem.Allocator, text: []const u8, scale: usize) !u64 {
    var coords = std.ArrayList(Coord).init(alloc);
    defer coords.deinit();
    try parse(text, &coords);
    const exp = Expansion.from(coords.items, scale);
    return calculateDistances(&coords, exp);
}

fn parse(
    text: []const u8,
    coords: *std.ArrayList(Coord),
) !void {
    var parser = Parser.new(text);
    while (parser.next()) |coord| {
        try coords.append(coord);
    }
}

const Expansion = struct {
    scale: usize,
    empty_rows: [140]isize = [_]isize{1} ** 140,
    empty_cols: [140]isize = [_]isize{1} ** 140,

    fn from(coords: []Coord, scale: usize) @This() {
        var self = @This(){ .scale = scale };
        for (coords) |c| {
            self.empty_rows[c.y] = 0;
            self.empty_cols[c.x] = 0;
        }
        for (1..140) |y| self.empty_rows[y] += self.empty_rows[y - 1];
        for (1..140) |x| self.empty_cols[x] += self.empty_cols[x - 1];
        return self;
    }

    fn amount(self: *const @This(), a: Coord, b: Coord) usize {
        const rows = @abs(self.empty_rows[a.y] - self.empty_rows[b.y]);
        const cols = @abs(self.empty_cols[a.x] - self.empty_cols[b.x]);
        return (rows + cols) * (self.scale - 1);
    }
};

fn calculateDistances(coords: *std.ArrayList(Coord), exp: Expansion) usize {
    var sum: usize = 0;
    while (coords.popOrNull()) |coord| {
        for (coords.items) |other| {
            const dist = coord.distance(other);
            // print("{} -> {} = {}\n", .{ coord, other, dist });
            sum += dist + exp.amount(coord, other);
        }
    }
    return sum;
}

const Parser = struct {
    text: []const u8,
    index: usize = 0,
    row: usize = 0,
    col: usize = 0,

    fn new(text: []const u8) Parser {
        return Parser{ .text = text };
    }

    fn next(self: *@This()) ?Coord {
        for (self.text[self.index..]) |byte| {
            self.index += 1;
            self.col += 1;
            switch (byte) {
                '#' => return Coord{ .x = self.col - 1, .y = self.row },
                '.' => continue,
                else => {
                    while (self.index < self.text.len and
                        std.ascii.isControl(self.text[self.index]))
                    {
                        self.index += 1;
                    }
                    self.col = 0;
                    self.row += 1;
                    continue;
                },
            }
        }
        return null;
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("374", out_1);
    try t.expectEqualStrings("82000210", out_2);
    try t.expectEqual(1030, try process(t.allocator, input, 10));
    try t.expectEqual(8410, try process(t.allocator, input, 100));
}
