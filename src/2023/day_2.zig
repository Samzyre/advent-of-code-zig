const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("../lib.zig");

const reds = 12;
const greens = 13;
const blues = 14;

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var games: [100]Game = undefined;
    var split = mem.splitAny(u8, input, "\r\n");
    var count: u32 = 0;
    while (split.next()) |line| {
        if (line.len == 0) continue;
        const game = Game.parse(line);
        games[game.id - 1] = game;
        count += 1;
    }
    var sum: u32 = 0;
    for (0..count) |idx| {
        var ok = true;
        const sets = games[idx].getSets();
        for (sets) |set| {
            if ((set.red > reds) or (set.green > greens) or (set.blue > blues)) {
                ok = false;
            }
        }
        if (ok) {
            sum += games[idx].id;
        }
    }
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var games: [100]Game = undefined;
    var split = mem.splitAny(u8, input, "\r\n");
    var count: u64 = 0;
    while (split.next()) |line| {
        if (line.len == 0) continue;
        const game = Game.parse(line);
        games[game.id - 1] = game;
        count += 1;
    }
    var sum: u32 = 0;
    for (0..count) |idx| {
        var max = Set{ .red = 0, .green = 0, .blue = 0 };
        const sets = games[idx].getSets();
        for (sets) |set| {
            max.red = @max(max.red, set.red);
            max.green = @max(max.green, set.green);
            max.blue = @max(max.blue, set.blue);
        }
        sum += max.red * max.green * max.blue;
    }
    return lib.intToString(alloc, sum);
}

const Game = struct {
    id: u32,
    sets: [10]Set,
    len: u32,

    fn parse(line: []const u8) Game {
        const colon = mem.indexOfScalar(u8, line, ':') orelse 0;
        const id = fmt.parseInt(u32, line[5..colon], 10) catch unreachable;
        const rest = line[8..];

        var tokens = mem.tokenizeAny(u8, rest, ", ");
        var index: u32 = 0;
        var sets: [10]Set = mem.zeroes([10]Set);
        var cur_set = Set{
            .red = 0,
            .green = 0,
            .blue = 0,
        };
        var cur_num: u32 = 0;

        while (tokens.next()) |token| {
            const number = fmt.parseInt(u32, token, 10) catch null;
            if (number) |num| {
                cur_num = num;
            } else {
                var name = token;
                var end = false;
                if (name[name.len - 1] == ';') {
                    name = name[0..(name.len - 1)];
                    end = true;
                }
                if (mem.eql(u8, name, "red")) {
                    cur_set.red = cur_num;
                } else if (mem.eql(u8, name, "green")) {
                    cur_set.green = cur_num;
                } else {
                    cur_set.blue = cur_num;
                }
                cur_num = 0;
                if (end) {
                    sets[index] = cur_set;
                    index += 1;
                    cur_set.red = 0;
                    cur_set.green = 0;
                    cur_set.blue = 0;
                }
            }
        }
        sets[index] = cur_set;
        return .{ .id = id, .sets = sets, .len = index + 1 };
    }

    fn getSets(self: *const Game) []const Set {
        return self.sets[0..self.len];
    }
};

const Set = struct {
    red: u32,
    green: u32,
    blue: u32,
};

test "test" {
    const t = std.testing;
    const input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("8", out_1);
    try t.expectEqualStrings("2286", out_2);
}
