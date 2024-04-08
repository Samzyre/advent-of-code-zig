const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var patterns = Patterns.init(alloc);
    defer patterns.deinit();
    try patterns.parse(input);
    const out = try patterns.summarize(0);
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var patterns = Patterns.init(alloc);
    defer patterns.deinit();
    try patterns.parse(input);
    const out = try patterns.summarize(1);
    return lib.intToString(alloc, out);
}

const Patterns = struct {
    patterns: std.ArrayList(Pattern),

    fn init(alloc: mem.Allocator) Patterns {
        return .{ .patterns = std.ArrayList(Pattern).init(alloc) };
    }

    fn deinit(self: @This()) void {
        self.patterns.deinit();
    }

    fn parse(self: *@This(), text: []const u8) !void {
        var lines = mem.splitAny(u8, text, "\r\n");
        var pattern: ?Pattern = null;
        while (lines.next()) |line| {
            if (line.len == 0) {
                try self.patterns.append(pattern.?);
                pattern = null;
                continue;
            } else {
                if (pattern == null) {
                    pattern = Pattern{ .width = line.len };
                }
                pattern.?.push(line);
            }
        }
        // for (self.patterns.items) |p|
        //     print("R\n{}\n", .{PatternPrinter{ .pattern = p.rows(), .width = p.width }});
    }

    fn summarize(self: *const @This(), diff: usize) !usize {
        var sum: usize = 0;
        for (self.patterns.items) |pattern| {
            sum += (pattern.horizontalMirror(diff) orelse 0) * 100;
            sum += pattern.verticalMirror(diff) orelse 0;
        }
        return sum;
    }
};

const Field = std.bit_set.IntegerBitSet(32);
const Pattern = struct {
    const A = [32]Field;
    array: A = undefined,
    height: usize = 0,
    width: usize,

    fn push(self: *@This(), str: []const u8) void {
        var field = Field.initEmpty();
        for (str, 0..) |b, i| {
            switch (b) {
                '.' => {},
                '#' => field.set(i),
                else => std.debug.panic("unknown character: '{c}'\n", .{b}),
            }
        }
        self.array[self.height] = field;
        self.height += 1;
    }

    fn rows(self: *const @This()) []const Field {
        return self.array[0..self.height];
    }

    fn horizontalMirror(self: *const @This(), diff: usize) ?usize {
        for (1..self.height) |i| {
            if (horizontalMirrorDiff(self.rows(), i) == diff) return i;
        }
        return null;
    }

    fn verticalMirror(self: *const @This(), diff: usize) ?usize {
        for (1..self.width) |i| {
            if (verticalMirrorDiff(self.rows(), self.width, i) == diff) return i;
        }
        return null;
    }
};

fn horizontalMirrorDiff(rows: []const Field, center: usize) usize {
    var diff: usize = 0;
    for (0..@min(center, rows.len - center)) |y| {
        diff += rows[center - y - 1].xorWith(rows[center + y]).count();
    }
    return diff;
}

fn verticalMirrorDiff(rows: []const Field, width: usize, center: usize) usize {
    var diff: usize = 0;
    for (rows) |r| {
        for (0..@min(center, width - center)) |x| {
            const a = r.isSet(center - x - 1);
            const b = r.isSet(center + x);
            if ((a and !b) or (b and !a)) diff += 1;
        }
    }
    return diff;
}

// const PatternPrinter = struct {
//     pattern: []const Field,
//     width: usize,

//     pub fn format(
//         self: @This(),
//         comptime _fmt: []const u8,
//         options: std.fmt.FormatOptions,
//         writer: anytype,
//     ) !void {
//         _ = _fmt;
//         _ = options;
//         for (self.pattern) |f| {
//             try writer.print("{}\n", .{FieldPrinter{ .field = f, .len = self.width }});
//         }
//     }
// };

// const FieldPrinter = struct {
//     field: Field,
//     len: usize,

//     pub fn format(
//         self: @This(),
//         comptime _fmt: []const u8,
//         options: std.fmt.FormatOptions,
//         writer: anytype,
//     ) !void {
//         _ = _fmt;
//         _ = options;
//         for (0..self.len) |i| {
//             if (self.field.isSet(i)) {
//                 try writer.writeByte('1');
//             } else {
//                 try writer.writeByte('0');
//             }
//         }
//     }
// };

test "test" {
    const t = std.testing;
    const input =
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("405", out_1);
    try t.expectEqualStrings("400", out_2);
}
