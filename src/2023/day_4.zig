const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var sum: u32 = 0;

    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var parts = mem.tokenizeAny(u8, line, ":|");
        _ = parts.next().?;

        const win = parts.next().?;
        var win_tokens = mem.tokenizeAny(u8, win, " ");

        var winning = std.ArrayList(u32).init(alloc);
        defer winning.deinit();

        while (win_tokens.next()) |token| {
            const value = try fmt.parseUnsigned(u32, token, 10);
            try winning.append(value);
        }

        const your = parts.next().?;
        var your_tokens = mem.tokenizeAny(u8, your, " ");

        var numbers = std.ArrayList(u32).init(alloc);
        defer numbers.deinit();

        while (your_tokens.next()) |token| {
            const value = try fmt.parseUnsigned(u32, token, 10);
            try numbers.append(value);
        }

        var score: u32 = 0;
        for (winning.items) |w| {
            if (mem.containsAtLeast(u32, numbers.items, 1, &[_]u32{w})) {
                score += 1;
            }
        }

        sum += std.math.pow(u32, 2, score) / 2;
    }

    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const length = mem.count(u8, input, "\n");
    var table = try std.ArrayList(u32).initCapacity(alloc, 300);
    defer table.deinit();

    for (0..length) |_| {
        try table.append(1);
    }

    var lines = mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var parts = mem.tokenizeAny(u8, line, ":|");

        var card_token = parts.next().?;
        card_token = mem.trimLeft(u8, card_token, "Card ");
        const card = try fmt.parseUnsigned(u32, card_token, 10);

        const win = parts.next().?;
        var win_tokens = mem.tokenizeAny(u8, win, " ");

        var winning = std.ArrayList(u32).init(alloc);
        defer winning.deinit();

        while (win_tokens.next()) |token| {
            const value = try fmt.parseUnsigned(u32, token, 10);
            try winning.append(value);
        }

        const your = parts.next().?;
        var your_tokens = mem.tokenizeAny(u8, your, " ");

        var numbers = std.ArrayList(u32).init(alloc);
        defer numbers.deinit();

        while (your_tokens.next()) |token| {
            const value = try fmt.parseUnsigned(u32, token, 10);
            try numbers.append(value);
        }

        var score: u32 = 0;
        for (winning.items) |w| {
            if (mem.containsAtLeast(u32, numbers.items, 1, &[_]u32{w})) {
                table.items[card + score] += table.items[card - 1];
                score += 1;
            }
        }
    }

    var sum: u32 = 0;
    for (table.items) |item| {
        sum += item;
    }

    return lib.intToString(alloc, sum);
}

test "test" {
    const t = std.testing;
    const input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("13", out_1);
    try t.expectEqualStrings("30", out_2);
}
