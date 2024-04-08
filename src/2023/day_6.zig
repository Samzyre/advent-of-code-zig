const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const pairs = try Pairs.parseAlloc(alloc, input);
    defer pairs.deinit();

    var out: u64 = 1;
    var pairs_iter = pairs.iter();
    while (pairs_iter.next()) |pair| {
        // print("{any}\n", .{pair});
        const count = simulate(pair[0], pair[1]);
        out *= count;
    }

    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const pairs = try Pairs.parseSingleAlloc(alloc, input);
    defer pairs.deinit();

    var out: u64 = 1;
    var pairs_iter = pairs.iter();
    while (pairs_iter.next()) |pair| {
        // print("{any}\n", .{pair});
        const count = simulate(pair[0], pair[1]);
        out *= count;
    }

    return lib.intToString(alloc, out);
}

fn simulate(time: u64, dist: u64) u64 {
    var charge: u64 = 1;
    var count: u64 = 0;
    while (charge < time) : (charge += 1) {
        const out = (time - charge) * charge;
        if (out > dist) {
            count += 1;
        }
    }
    return count;
}

const Pair = struct { u64, u64 };

const Pairs = struct {
    times: std.ArrayList(u64),
    records: std.ArrayList(u64),

    const headers = &[_][]const u8{
        "Time: ",
        "Distance: ",
    };

    fn initCapacity(alloc: mem.Allocator, size: usize) !Pairs {
        return Pairs{
            .times = try std.ArrayList(u64).initCapacity(alloc, size),
            .records = try std.ArrayList(u64).initCapacity(alloc, size),
        };
    }

    fn parseSingleAlloc(alloc: mem.Allocator, input: []const u8) !Pairs {
        var self = try Pairs.initCapacity(alloc, 1);
        var lines = mem.tokenizeAny(u8, input, "\r\n");
        for (0..2) |idx| {
            const line = lines.next().?;
            const trim = mem.trimLeft(u8, line, headers[idx]);
            var tokens = mem.tokenizeAny(u8, trim, " ");
            var buf = try std.ArrayList(u8).initCapacity(alloc, 16);
            defer buf.deinit();
            while (tokens.next()) |token| {
                try buf.appendSlice(token);
            }
            const value = try std.fmt.parseUnsigned(u64, buf.items, 10);
            if (idx == 0) try self.times.append(value) else try self.records.append(value);
        }
        return self;
    }

    fn parseAlloc(alloc: mem.Allocator, input: []const u8) !Pairs {
        var self = try Pairs.initCapacity(alloc, 4);
        var lines = mem.tokenizeAny(u8, input, "\r\n");
        for (0..2) |idx| {
            const line = lines.next().?;
            const trim = mem.trimLeft(u8, line, headers[idx]);
            var tokens = mem.tokenizeAny(u8, trim, " ");
            while (tokens.next()) |token| {
                const value = try std.fmt.parseUnsigned(u64, token, 10);
                if (idx == 0) try self.times.append(value) else try self.records.append(value);
            }
        }
        return self;
    }

    fn deinit(self: Pairs) void {
        self.times.deinit();
        self.records.deinit();
    }

    pub fn format(
        self: Pairs,
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("Times: {any}\nRecords: {any}", .{ self.times.items, self.records.items });
    }

    pub fn iter(self: *const Pairs) PairsIter {
        return .{
            .pairs = self,
            .index = 0,
        };
    }
};

const PairsIter = struct {
    pairs: *const Pairs,
    index: usize = 0,

    pub fn next(self: *PairsIter) ?Pair {
        if (self.index >= @min(self.pairs.times.items.len, self.pairs.records.items.len)) {
            return null;
        }
        const ret = .{ self.pairs.times.items[self.index], self.pairs.records.items[self.index] };
        self.index += 1;
        return ret;
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\Time:      7  15   30
        \\Distance:  9  40  200
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("288", out_1);
    try t.expectEqualStrings("71503", out_2);
}
