const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var entries = try parse(alloc, input);
    defer entries.deinit();
    var x: isize = 0;
    var y: isize = 0;
    var area: isize = 0;
    for (entries.items) |entry| {
        const cx = x;
        const cy = y;
        switch (entry.instruction) {
            'U' => y -= entry.count,
            'D' => y += entry.count,
            'L' => x -= entry.count,
            'R' => x += entry.count,
            else => @panic("unknown direction"),
        }
        // print("{any} x {any} = {any}\n", .{ .{ cx, cy }, .{ x, y }, cx * y - cy * x });
        area += cx * y - cy * x + entry.count;
    }
    return lib.intToString(alloc, @divExact(area, 2) + 1);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var entries = try parse(alloc, input);
    defer entries.deinit();
    var x: isize = 0;
    var y: isize = 0;
    var area: isize = 0;
    for (entries.items) |entry| {
        const cx = x;
        const cy = y;
        switch (entry.color_instruction) {
            0 => x += entry.color_count,
            1 => y += entry.color_count,
            2 => x -= entry.color_count,
            3 => y -= entry.color_count,
            else => @panic("unknown direction"),
        }
        area += cx * y - cy * x + entry.color_count;
    }
    return lib.intToString(alloc, @divExact(area, 2) + 1);
}

fn parse(alloc: mem.Allocator, text: []const u8) !std.ArrayList(Entry) {
    var list = std.ArrayList(Entry).init(alloc);
    var lines = mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        var tokens = mem.tokenizeAny(u8, line, " (#)");
        const inst = tokens.next().?;
        const number = tokens.next().?;
        const color = tokens.next().?;
        try list.append(Entry{
            .instruction = inst[0],
            .count = try std.fmt.parseUnsigned(u8, number, 10),
            .color_instruction = color[5] - '0',
            .color_count = try std.fmt.parseUnsigned(isize, color[0..5], 16),
        });
    }
    return list;
}

const Entry = struct {
    instruction: u8,
    count: u8,
    color_instruction: u8,
    color_count: isize,
};

test "test" {
    const t = std.testing;
    const input =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("62", out_1);
    try t.expectEqualStrings("952408144115", out_2);
}
