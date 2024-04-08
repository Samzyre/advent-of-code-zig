const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const width = mem.indexOf(u8, input, "\n").?;
    const height = mem.count(u8, input, "\n");

    var spans = std.ArrayList(Span).init(alloc);
    defer spans.deinit();

    var cur_span: ?Span = null;

    for (input, 0..) |byte, index| {
        if (byte == '\n' or byte == '.') {
            if (cur_span) |span| {
                try spans.append(span);
                cur_span = null;
            }
        } else if (std.ascii.isDigit(byte)) {
            if (cur_span) |*span| {
                if (span.end() == index) {
                    span.len += 1;
                }
            } else {
                cur_span = Span.new(index, 1);
            }
        } else {
            if (cur_span) |span| {
                try spans.append(span);
                cur_span = null;
            }
        }
    }

    // const t = struct {
    //     fn assert(slice: []const u8) void {
    //         for (slice) |byte| {
    //             if (std.ascii.isDigit(byte)) {
    //                 @panic("number in slice");
    //             }
    //             if (std.ascii.isControl(byte)) {
    //                 @panic("control in slice");
    //             }
    //         }
    //     }
    // };

    var sum: u64 = 0;

    for (spans.items) |span| {
        const value = try fmt.parseUnsigned(u32, input[span.index..span.end()], 10);

        var parts: [8][]const u8 = mem.zeroes([8][]const u8);
        const w = width + 1;
        const column_start = span.index % w;
        const column_end = span.end() % w;
        const row = span.index / w;

        // 0.5.1
        // 4...6
        // 2.7.3
        if (column_start > 0 and row > 0) {
            parts[0] = input[span.index - w - 1 .. span.index - w];
        }
        if (column_end < w - 1 and row > 0) {
            parts[1] = input[span.end() - w .. span.end() - w + 1];
        }
        if (column_start > 0 and row < height - 1) {
            parts[2] = input[span.index + w - 1 .. span.index + w];
        }
        if (column_end < w - 1 and row < height - 1) {
            parts[3] = input[span.end() + w .. span.end() + w + 1];
        }
        if (column_start > 0) {
            parts[4] = input[span.index - 1 .. span.index];
        }
        if (row > 0) {
            parts[5] = input[span.index - w .. span.end() - w];
        }
        if (column_end < w - 1) {
            parts[6] = input[span.end() .. span.end() + 1];
        }
        if (row < height - 1) {
            parts[7] = input[span.index + w .. span.end() + w];
        }
        // t.assert(parts[0]);
        // t.assert(parts[1]);
        // t.assert(parts[2]);
        // t.assert(parts[3]);
        // t.assert(parts[4]);
        // t.assert(parts[5]);
        // t.assert(parts[6]);
        // t.assert(parts[7]);

        const neighbors = try mem.concat(alloc, u8, &parts);
        defer alloc.free(neighbors);
        var skip = false;
        for (neighbors) |byte| {
            if (byte == '.') {
                skip = true;
                continue;
            }
            skip = false;
            sum += value;
            break;
        }
    }

    return lib.intToString(alloc, sum);
}

const SymbolsMap = std.AutoArrayHashMap(usize, struct { usize, [2]u32 });

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const width = mem.indexOf(u8, input, "\n").?;
    const height = mem.count(u8, input, "\n");

    var spans = std.ArrayList(Span).init(alloc);
    defer spans.deinit();
    var symbols = SymbolsMap.init(alloc);
    defer symbols.deinit();

    var cur_span: ?Span = null;

    for (input, 0..) |byte, index| {
        if (byte == '\n' or byte == '.') {
            if (cur_span) |span| {
                try spans.append(span);
                cur_span = null;
            }
        } else if (std.ascii.isDigit(byte)) {
            if (cur_span) |*span| {
                if (span.end() == index) {
                    span.len += 1;
                }
            } else {
                cur_span = Span.new(index, 1);
            }
        } else {
            if (byte == '*') {
                try symbols.put(index, .{ 0, .{ 0, 0 } });
            }
            if (cur_span) |span| {
                try spans.append(span);
                cur_span = null;
            }
        }
    }

    var locations = std.AutoArrayHashMap(usize, usize).init(alloc);
    defer locations.deinit();

    for (spans.items) |span| {
        const value = try fmt.parseUnsigned(u32, input[span.index..span.end()], 10);
        const w = width + 1;
        const column_start = span.index % w;
        const column_end = span.end() % w;
        const row = span.index / w;

        // 0.5.1
        // 4...6
        // 2.7.3
        if (column_start > 0 and row > 0) {
            const s = input[span.index - w - 1 .. span.index - w];
            incSymbolCount(value, span.index - w - 1, s, symbols);
        }
        if (column_end < w - 1 and row > 0) {
            const s = input[span.end() - w .. span.end() - w + 1];
            incSymbolCount(value, span.end() - w, s, symbols);
        }
        if (column_start > 0 and row < height - 1) {
            const s = input[span.index + w - 1 .. span.index + w];
            incSymbolCount(value, span.index + w - 1, s, symbols);
        }
        if (column_end < w - 1 and row < height - 1) {
            const s = input[span.end() + w .. span.end() + w + 1];
            incSymbolCount(value, span.end() + w, s, symbols);
        }
        if (column_start > 0) {
            const s = input[span.index - 1 .. span.index];
            incSymbolCount(value, span.index - 1, s, symbols);
        }
        if (row > 0) {
            const s = input[span.index - w .. span.end() - w];
            incSymbolCount(value, span.index - w, s, symbols);
        }
        if (column_end < w - 1) {
            const s = input[span.end() .. span.end() + 1];
            incSymbolCount(value, span.end(), s, symbols);
        }
        if (row < height - 1) {
            const s = input[span.index + w .. span.end() + w];
            incSymbolCount(value, span.index + w, s, symbols);
        }
    }

    var sum: u64 = 0;
    var iter = symbols.iterator();
    while (iter.next()) |entry| {
        const v = entry.value_ptr.*;
        if (v[0] == 2) {
            sum += v[1][0] * v[1][1];
        }
    }

    return lib.intToString(alloc, sum);
}

fn incSymbolCount(value: u32, base: usize, slice: []const u8, syms: SymbolsMap) void {
    for (slice, 0..) |byte, offset| {
        if (byte == '*') {
            if (syms.getPtr(base + offset)) |ptr| {
                if (ptr[0] < 2) {
                    ptr[1][ptr[0]] = value;
                }
                ptr[0] += 1;
            }
        }
    }
}

const Span = struct {
    index: usize = 0,
    len: usize = 0,

    fn new(index: usize, len: usize) Span {
        return .{ .index = index, .len = len };
    }

    fn end(self: *const Span) usize {
        return self.index + self.len;
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("4361", out_1);
    try t.expectEqualStrings("467835", out_2);
}
