const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const almanac = try Almanac.parse(alloc, input);
    defer almanac.deinit();
    return lib.intToString(alloc, almanac.minLocation());
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    const almanac = try Almanac.parse(alloc, input);
    defer almanac.deinit();
    return lib.intToString(alloc, almanac.minLocationRanges());
}

const Almanac = struct {
    seeds: std.ArrayList(i64),
    layers: std.ArrayList(Layer),

    fn init(alloc: mem.Allocator) !Almanac {
        return .{
            .seeds = try std.ArrayList(i64).initCapacity(alloc, 20),
            .layers = try std.ArrayList(Layer).initCapacity(alloc, 7),
        };
    }

    fn deinit(self: @This()) void {
        for (self.layers.items) |item| {
            item.deinit();
        }
        self.seeds.deinit();
        self.layers.deinit();
    }

    fn parse(alloc: mem.Allocator, text: []const u8) !Almanac {
        var self = try Almanac.init(alloc);
        var sections = mem.tokenizeSequence(u8, text, "\n\n");

        const seeds_line = sections.next().?;
        var seed_tokens = mem.tokenizeAny(u8, seeds_line, "seeds: ");
        while (seed_tokens.next()) |token| {
            const seed = try fmt.parseUnsigned(i64, token, 10);
            try self.seeds.append(seed);
        }

        while (sections.next()) |section| {
            const layer = try Layer.parseAlloc(alloc, section);
            try self.layers.append(layer);
        }

        // print("{}\n", .{self});
        return self;
    }

    fn process(self: @This(), value: i64) i64 {
        var temp = value;
        for (self.layers.items) |layer| {
            temp = layer.process(temp);
        }
        return temp;
    }

    fn minLocation(self: @This()) i64 {
        var min: i64 = std.math.maxInt(i64);
        for (self.seeds.items) |seed| {
            min = @min(min, self.process(seed));
        }
        return min;
    }

    fn minLocationRanges(self: @This()) i64 {
        var min: i64 = std.math.maxInt(i64);
        var iter = mem.window(i64, self.seeds.items, 2, 2);
        while (iter.next()) |pair| {
            const range = Range{ .src = pair[0], .len = pair[1] };
            var seed = range.src;
            while (range.contains(seed)) {
                min = @min(min, self.process(seed));
                seed = self.nextCritical(seed);
            }
        }
        return min;
    }

    fn nextCritical(self: @This(), current: i64) i64 {
        var min: i64 = std.math.maxInt(i64);
        var temp = current;
        for (self.layers.items) |layer| {
            if (layer.nextCriticalOffset(temp)) |critical| {
                min = @min(min, critical);
            }
            temp = layer.process(temp);
        }
        return current + min;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{any}\n", .{self.seeds.items});
        for (self.layers.items) |layer| {
            try writer.print("\n{}", .{layer});
        }
    }
};

const Layer = struct {
    src: []const u8,
    dst: []const u8,
    mappings: std.ArrayList(Range),

    fn init(alloc: mem.Allocator) !Layer {
        return .{
            .src = undefined,
            .dst = undefined,
            .mappings = try std.ArrayList(Range).initCapacity(alloc, 40),
        };
    }

    fn deinit(self: @This()) void {
        self.mappings.deinit();
    }

    fn parseAlloc(alloc: mem.Allocator, text: []const u8) !Layer {
        var self = try Layer.init(alloc);
        var lines = mem.tokenizeAny(u8, text, "\n");
        var name = lines.next().?;
        name = mem.trimRight(u8, name, " map:");
        var targets = mem.tokenizeSequence(u8, name, "-to-");
        self.src = targets.next().?;
        self.dst = targets.next().?;
        while (lines.next()) |line| {
            const range = try Range.parse(line);
            try self.mappings.append(range);
        }
        return self;
    }

    fn process(self: @This(), value: i64) i64 {
        for (self.mappings.items) |range| {
            if (range.process(value)) |new| {
                return new;
            }
        }
        return value;
    }

    fn nextCriticalOffset(self: @This(), current: i64) ?i64 {
        var min: ?i64 = null;
        for (self.mappings.items) |range| {
            if (current < range.src) {
                min = @min(min orelse std.math.maxInt(i64), range.src - current);
            } else if (current < range.end()) {
                min = @min(min orelse std.math.maxInt(i64), range.end() - current);
            }
        }
        return min;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{s} -> {s}\n", .{ self.src, self.dst });
        for (self.mappings.items) |mapping| {
            try writer.print("\t{}\n", .{mapping});
        }
    }
};

const Range = struct {
    src: i64,
    offset: i64 = 0,
    len: i64 = 0,

    fn parse(text: []const u8) !Range {
        var numbers = mem.tokenizeAny(u8, text, " ");
        const dst = try fmt.parseUnsigned(i64, numbers.next().?, 10);
        const src = try fmt.parseUnsigned(i64, numbers.next().?, 10);
        const len = try fmt.parseUnsigned(i64, numbers.next().?, 10);
        return .{
            .src = src,
            .offset = dst - src,
            .len = len,
        };
    }

    fn end(self: @This()) i64 {
        return self.src + self.len;
    }

    fn process(self: @This(), value: i64) ?i64 {
        if (self.contains(value)) {
            return value + self.offset;
        }
        return null;
    }

    fn contains(self: @This(), value: i64) bool {
        return value >= self.src and value < self.end();
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("src: {d}, offset: {d}, len: {d}", .{
            self.src,
            self.offset,
            self.len,
        });
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("35", out_1);
    try t.expectEqualStrings("46", out_2);
}
