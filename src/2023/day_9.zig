const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var rows = std.ArrayList(std.ArrayList(i64)).init(alloc);
    defer {
        for (rows.items) |row| {
            row.deinit();
        }
        rows.deinit();
    }

    try parse(alloc, input, &rows);

    var sum: i64 = 0;
    for (rows.items) |row| {
        sum += try extrapolate(alloc, row.items, Direction.forward);
    }

    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var rows = std.ArrayList(std.ArrayList(i64)).init(alloc);
    defer {
        for (rows.items) |row| {
            row.deinit();
        }
        rows.deinit();
    }

    try parse(alloc, input, &rows);

    var sum: i64 = 0;
    for (rows.items) |row| {
        sum += try extrapolate(alloc, row.items, Direction.backward);
    }

    return lib.intToString(alloc, sum);
}

fn parse(
    alloc: mem.Allocator,
    text: []const u8,
    rows: *std.ArrayList(std.ArrayList(i64)),
) !void {
    var lines = mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        var numbers = std.ArrayList(i64).init(alloc);
        var tokens = mem.tokenizeAny(u8, line, " ");
        while (tokens.next()) |token| {
            const number = try std.fmt.parseInt(i64, token, 10);
            try numbers.append(number);
        }
        try rows.append(numbers);
    }
}

fn allZero(buf: []const i64) bool {
    for (buf) |num| {
        if (num != 0) {
            return false;
        }
    }
    return true;
}

fn extrapolate(alloc: mem.Allocator, row: []const i64, dir: Direction) !i64 {
    if (allZero(row)) {
        return 0;
    } else {
        var out: i64 = 0;
        var next = std.ArrayList(i64).init(alloc);
        defer next.deinit();
        var last: i64 = row[0];
        for (row[1..]) |item| {
            const diff = item - last;
            last = item;
            try next.append(diff);
        }
        out = try extrapolate(alloc, next.items, dir);

        switch (dir) {
            .forward => return row[row.len - 1] + out,
            .backward => return row[0] - out,
        }
    }
}

const Direction = enum {
    forward,
    backward,
};

test "test" {
    const t = std.testing;
    const input =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("114", out_1);
    try t.expectEqualStrings("2", out_2);
}
