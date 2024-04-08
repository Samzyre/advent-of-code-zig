const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var sum: u64 = 0;
    var first: ?u8 = null;
    var last: ?u8 = null;
    for (input) |byte| {
        if (ascii.isControl(byte)) {
            sum += (first orelse 0) * 10 + (last orelse 0);
            first = null;
            last = null;
        } else if (ascii.isDigit(byte)) {
            const number = byte - '0';
            if (first == null) {
                first = number;
                last = number;
            } else {
                last = number;
            }
        }
    }
    return lib.intToString(alloc, sum);
}

const words: []const []const u8 = &[_][]const u8{
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
};

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var split = mem.splitAny(u8, input, "\r\n");
    var sum: u64 = 0;

    while (split.next()) |line| {
        const Variant = union(enum) {
            literal: []const u8,
            value: u8,
        };

        const Pair = struct { index: usize, number: Variant };

        var min: ?Pair = null;
        var max: ?Pair = null;

        for (words) |word| {
            const first = mem.indexOf(u8, line, word);
            const last = mem.lastIndexOf(u8, line, word);

            if (first) |index| {
                if (min) |pair| {
                    if (pair.index > index) {
                        min = .{ .index = index, .number = .{ .literal = word } };
                    }
                } else {
                    min = .{ .index = index, .number = .{ .literal = word } };
                }
            }
            if (last) |index| {
                if (max) |pair| {
                    if (pair.index < index) {
                        max = .{ .index = index, .number = .{ .literal = word } };
                    }
                } else {
                    max = .{ .index = index, .number = .{ .literal = word } };
                }
            }
        }
        var index: u32 = 0;
        for (line) |byte| {
            if (ascii.isDigit(byte)) {
                const number = byte - '0';
                if (min) |pair| {
                    if (pair.index > index) {
                        min = .{ .index = index, .number = .{ .value = number } };
                    }
                } else {
                    min = .{ .index = index, .number = .{ .value = number } };
                }
                if (max) |pair| {
                    if (pair.index < index) {
                        max = .{ .index = index, .number = .{ .value = number } };
                    }
                } else {
                    max = .{ .index = index, .number = .{ .value = number } };
                }
            }
            index += 1;
        }

        var final_min: u8 = 0;
        var final_max: u8 = 0;

        min = min orelse .{ .index = 0, .number = .{ .value = 0 } };
        max = max orelse .{ .index = 0, .number = .{ .value = 0 } };

        switch (min.?.number) {
            .literal => |bytes| {
                var idx: u8 = 0;
                final_min = while (idx < words.len) : (idx += 1) {
                    if (mem.eql(u8, words[idx], bytes)) {
                        break idx;
                    }
                } else 0;
            },
            .value => |number| final_min = number,
        }
        switch (max.?.number) {
            .literal => |bytes| {
                var idx: u8 = 0;
                final_max = while (idx < words.len) : (idx += 1) {
                    if (mem.eql(u8, words[idx], bytes)) {
                        break idx;
                    }
                } else 0;
            },
            .value => |number| final_max = number,
        }

        sum += final_min * 10 + final_max;
    }
    return lib.intToString(alloc, sum);
}

test "test" {
    const t = std.testing;
    const input_1 =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
        \\
    ;
    const input_2 =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
        \\
    ;
    const out_1 = try part_1(t.allocator, input_1);
    const out_2 = try part_2(t.allocator, input_2);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("142", out_1);
    try t.expectEqualStrings("281", out_2);
}
