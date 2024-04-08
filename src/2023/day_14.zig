const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var board = Board(100).parse(input);
    board.tilt(.north);
    const out = board.northWeight();
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var values = std.ArrayList(usize).init(alloc);
    defer values.deinit();
    var board = Board(100).parse(input);
    var out: usize = 0;
    for (0..1000000000) |index| {
        board.tilt(.north);
        board.tilt(.west);
        board.tilt(.south);
        board.tilt(.east);
        try values.append(board.northWeight());
        if (cycle(values.items)) |slice| {
            out = slice[(1000000000 - 2 - index) % slice.len];
            break;
        }
    }
    return lib.intToString(alloc, out);
}

fn cycle(slice: []const usize) ?[]const usize {
    if (slice.len < 10) return null;
    for (@max(1, slice.len / 3)..(slice.len / 2)) |sub| {
        const a = slice[(slice.len - sub * 2)..(slice.len - sub)];
        const b = slice[(slice.len - sub)..];
        if (mem.eql(usize, a, b)) return slice[(slice.len - sub)..];
    }
    return null;
}

fn Board(comptime S: usize) type {
    return struct {
        board: [S][S]u8,
        size: usize = 0,

        const Self = @This();

        fn parse(text: []const u8) Self {
            var self = @This(){ .board = mem.zeroes([S][S]u8) };
            var lines = mem.tokenizeAny(u8, text, "\r\n");
            var index: usize = 0;
            while (lines.next()) |line| {
                @memcpy(self.board[index][0..line.len], line);
                index += 1;
            }
            self.size = index;
            return self;
        }

        fn tilt(self: *Self, dir: Direction) void {
            var changed = true;
            while (changed) {
                changed = false;
                for (0..self.size) |y| {
                    for (0..self.size) |x| {
                        if (self.board[y][x] != 'O') continue;
                        var other: *u8 = undefined;
                        switch (dir) {
                            .north => if (y > 0 and self.board[y - 1][x] == '.') {
                                other = &self.board[y - 1][x];
                            } else continue,
                            .south => if (y < self.size - 1 and self.board[y + 1][x] == '.') {
                                other = &self.board[y + 1][x];
                            } else continue,
                            .west => if (x > 0 and self.board[y][x - 1] == '.') {
                                other = &self.board[y][x - 1];
                            } else continue,
                            .east => if (x < self.size - 1 and self.board[y][x + 1] == '.') {
                                other = &self.board[y][x + 1];
                            } else continue,
                        }
                        mem.swap(u8, &self.board[y][x], other);
                        changed = true;
                    }
                }
            }
        }

        fn northWeight(self: Self) usize {
            var sum: usize = 0;
            for (self.board, 0..) |row, y| {
                for (row) |byte| {
                    if (byte == 'O') {
                        sum += self.size - y;
                    }
                }
            }
            return sum;
        }
    };
}

const Direction = enum {
    north,
    south,
    west,
    east,
};

test "test" {
    const t = std.testing;
    const input =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("136", out_1);
    try t.expectEqualStrings("64", out_2);
}
