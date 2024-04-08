const std = @import("std");
const mem = std.mem;
const math = std.math;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    var sum: usize = 0;
    while (lines.next()) |line| {
        var record = Record.init(alloc);
        defer record.deinit();
        try record.parse(line, 1);
        sum += try record.arrangements();
    }
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var lines = mem.tokenizeAny(u8, input, "\r\n");
    var sum: usize = 0;
    while (lines.next()) |line| {
        var record = Record.init(alloc);
        defer record.deinit();
        try record.parse(line, 5);
        sum += try record.arrangements();
    }
    return lib.intToString(alloc, sum);
}

const Record = struct {
    pattern: std.ArrayList(u8),
    groups: std.ArrayList(u8),

    fn init(alloc: mem.Allocator) Record {
        return .{
            .pattern = std.ArrayList(u8).init(alloc),
            .groups = std.ArrayList(u8).init(alloc),
        };
    }

    fn deinit(self: @This()) void {
        self.pattern.deinit();
        self.groups.deinit();
    }

    fn parse(self: *@This(), line: []const u8, fold: u8) !void {
        var parts = mem.tokenizeAny(u8, line, " ");
        const pattern = parts.next().?;
        var groups = mem.tokenizeAny(u8, parts.next().?, ",");
        for (0..fold) |i| {
            try self.pattern.appendSlice(pattern);
            while (groups.next()) |g| {
                const n = try std.fmt.parseUnsigned(u8, g, 10);
                try self.groups.append(n);
            }
            if (i != fold - 1) {
                try self.pattern.append('?');
                groups.reset();
            }
        }
    }

    const State = struct { usize, usize, u8 };

    const Search = struct {
        mask: Mask,
        groups: []u8,
        seen: std.AutoArrayHashMap(State, usize),
        fn init(alloc: mem.Allocator, mask: Mask, groups: []u8) @This() {
            return .{
                .mask = mask,
                .groups = groups,
                .seen = std.AutoArrayHashMap(State, usize).init(alloc),
            };
        }

        fn deinit(self: *@This()) void {
            self.seen.deinit();
        }

        fn search(self: *@This(), bit_index: usize, group_index: usize, streak: u8) !usize {
            const state = State{ bit_index, group_index, streak };
            if (self.seen.contains(state)) return self.seen.get(state).?;

            if (bit_index >= self.mask.len) {
                if (group_index >= self.groups.len and streak == 0 or
                    group_index == self.groups.len - 1 and streak == self.groups[group_index])
                {
                    return 1;
                } else {
                    return 0;
                }
            }

            var count: usize = 0;
            const set = self.mask.known.isSet(bit_index);
            const unknown = self.mask.unknown.isSet(bit_index);
            if (!set or unknown) {
                if (streak == 0) {
                    count += try self.search(bit_index + 1, group_index, 0);
                } else if (group_index < self.groups.len and streak == self.groups[group_index]) {
                    count += try self.search(bit_index + 1, group_index + 1, 0);
                }
            }
            if (set or unknown) {
                count += try self.search(bit_index + 1, group_index, streak + 1);
            }

            try self.seen.put(state, count);
            return count;
        }
    };

    fn arrangements(self: @This()) !usize {
        const mask = self.toMask();
        var s = Search.init(self.groups.allocator, mask, self.groups.items);
        defer s.deinit();
        const out = try s.search(0, 0, 0);
        // print("{}\n", .{mask.len});
        // print("{any}\n", .{self.groups.items});
        // print("{}\n", .{mask});
        // print("out: {}\n\n", .{out});
        return out;
    }

    fn toMask(self: @This()) Mask {
        var mask = Mask{};
        for (self.pattern.items) |c| {
            switch (c) {
                '.' => mask.push(false),
                '#' => mask.push(true),
                '?' => mask.push(null),
                else => @panic("unknown character"),
            }
        }
        return mask;
    }
};

const Field = std.bit_set.IntegerBitSet(128);

const Mask = struct {
    known: Field = Field.initEmpty(),
    unknown: Field = Field.initEmpty(),
    len: usize = 0,

    fn push(self: *@This(), value: ?bool) void {
        if (value) |v| {
            self.known.setValue(self.len, v);
        } else {
            self.unknown.set(self.len);
        }
        self.len += 1;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        var f = FieldPrinter{ .field = self.known, .len = self.len };
        try writer.print("{}\n", .{f});
        f.field = self.unknown;
        try writer.print("{}", .{f});
    }
};

const FieldPrinter = struct {
    field: Field,
    len: usize,

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        for (0..self.len) |i| {
            if (self.field.isSet(i)) {
                try writer.writeByte('1');
            } else {
                try writer.writeByte('0');
            }
        }
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("21", out_1);
    try t.expectEqualStrings("525152", out_2);
}
