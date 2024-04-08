const std = @import("std");
const mem = std.mem;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    _ = input;
    return try lib.intToString(alloc, 0);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    _ = input;
    return try lib.intToString(alloc, 0);
}

test "test" {
    const t = std.testing;
    const input =
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("0", out_1);
    try t.expectEqualStrings("0", out_2);
}
