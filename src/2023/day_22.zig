const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const math = std.math;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Vec3i = lib.Vec3(isize);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var pile = Pile.init(alloc);
    defer pile.deinit();
    try pile.parse(input);
    while (try pile.stack()) {}
    const out = try pile.disintegrateable();
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var pile = Pile.init(alloc);
    defer pile.deinit();
    try pile.parse(input);
    while (try pile.stack()) {}
    const out = try pile.fallable();
    return lib.intToString(alloc, out);
}

const Pile = struct {
    bricks: std.ArrayList(Brick),

    const Self = @This();

    fn init(alloc: mem.Allocator) Self {
        return .{ .bricks = std.ArrayList(Brick).init(alloc) };
    }

    fn deinit(self: Self) void {
        self.bricks.deinit();
    }

    fn parse(self: *Self, text: []const u8) !void {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const brick = try Brick.parse(line);
            try self.bricks.append(brick);
        }
    }

    fn stack(self: *Self) !bool {
        mem.sort(Brick, self.bricks.items, {}, Brick.lessThan);

        var moved = false;
        for (0..self.bricks.items.len) |idx| {
            var brick = &self.bricks.items[idx];
            const before = brick.*;

            var max: isize = 0;
            for (self.bricks.items[0..idx]) |other| {
                if (brick.collides_xy(other)) max = @max(max, other.end.z);
            }
            brick.move(Vec3i.new(0, 0, max + 1 - brick.start.z));

            if (!brick.eql(before)) {
                // print("{} -> {}\n", .{ before, brick.* });
                moved = true;
            }
        }
        // for (0..self.bricks.items.len) |i| {
        //     for (i + 1..self.bricks.items.len) |j| {
        //         if (self.bricks.items[i].collides(self.bricks.items[j])) @panic("overlap");
        //     }
        // }
        return moved;
    }

    fn disintegrateable(self: *const Self) !usize {
        var heights = try Heights.init(self);
        defer heights.deinit();

        var conns = try Connections.init(self, heights);
        defer conns.deinit();

        var dis = BrickSet.init(self.bricks.allocator);
        defer dis.deinit();

        for (self.bricks.items) |brick| {
            if (conns.above.getPtr(brick)) |aboves| {
                if (aboves.count() == 0) {
                    // print("free: {}\n", .{brick});
                    try dis.put(brick, {});
                }
                for (aboves.keys()) |above| {
                    const supporter = conns.under.getPtr(above).?;
                    if (supporter.count() < 2) break;
                } else {
                    // print("ok: {}\n", .{brick});
                    try dis.put(brick, {});
                }
            }
        }

        // for (dis.keys()) |i| print("{}\n", .{i});
        return dis.count();
    }

    fn fallable(self: *const Self) !usize {
        var heights = try Heights.init(self);
        defer heights.deinit();

        var conns = try Connections.init(self, heights);
        defer conns.deinit();

        var hang = std.AutoArrayHashMap(Brick, usize).init(self.bricks.allocator);
        defer hang.deinit();

        var searcher = Searcher{ .conns = &conns, .hang = &hang };

        var sum: usize = 0;
        for (self.bricks.items) |brick| {
            const out = try searcher.search(brick);
            sum += out;
            // print("{} = {}\n", .{ brick, out });
        }
        return sum;
    }
};

const HeightSet = std.AutoArrayHashMap(isize, std.ArrayList(Brick));
const Heights = struct {
    starts: HeightSet,
    ends: HeightSet,

    const Self = @This();

    fn init(pile: *const Pile) !Self {
        var self = .{
            .starts = HeightSet.init(pile.bricks.allocator),
            .ends = HeightSet.init(pile.bricks.allocator),
        };
        for (pile.bricks.items) |brick| {
            try putToHeightSet(&self.starts, brick.start.z, brick);
            try putToHeightSet(&self.ends, brick.end.z, brick);
        }
        return self;
    }

    fn deinit(self: *Self) void {
        for (self.starts.values()) |*v| v.deinit();
        self.starts.deinit();
        for (self.ends.values()) |*v| v.deinit();
        self.ends.deinit();
    }

    fn putToHeightSet(hs: *HeightSet, z: isize, brick: Brick) !void {
        var entry = try hs.getOrPutValue(z, std.ArrayList(Brick).init(hs.allocator));
        try entry.value_ptr.append(brick);
    }
};

const BrickSet = std.AutoArrayHashMap(Brick, void);
const BrickBrickSet = std.AutoArrayHashMap(Brick, BrickSet);
const Connections = struct {
    above: BrickBrickSet,
    under: BrickBrickSet,

    const Self = @This();

    fn init(pile: *const Pile, heights: Heights) !Self {
        var self = .{
            .above = BrickBrickSet.init(pile.bricks.allocator),
            .under = BrickBrickSet.init(pile.bricks.allocator),
        };
        for (pile.bricks.items) |brick| {
            try collisions(&self.above, brick, &heights.starts, brick.end.z + 1);
            try collisions(&self.under, brick, &heights.ends, brick.start.z - 1);
        }
        return self;
    }

    fn deinit(self: *Self) void {
        for (self.above.values()) |*v| v.deinit();
        self.above.deinit();
        for (self.under.values()) |*v| v.deinit();
        self.under.deinit();
    }

    fn collisions(bbs: *BrickBrickSet, brick: Brick, hs: *const HeightSet, z: isize) !void {
        var set = try bbs.getOrPutValue(brick, BrickSet.init(bbs.allocator));
        if (hs.getPtr(z)) |bs| {
            for (bs.items) |b| {
                if (brick.collides_xy(b)) try set.value_ptr.put(b, {});
            }
        }
    }
};

const Searcher = struct {
    conns: *const Connections,
    hang: *std.AutoArrayHashMap(Brick, usize),

    const Self = @This();

    fn search(self: *Self, brick: Brick) !usize {
        self.hang.clearRetainingCapacity();
        return self.searchInner(brick);
    }

    fn searchInner(self: *Self, brick: Brick) !usize {
        for (self.above(brick)) |a| {
            const entry = try self.hang.getOrPutValue(a, 0);
            entry.value_ptr.* += 1;
        }
        var temp = std.ArrayList(Brick).init(self.hang.allocator);
        defer temp.deinit();
        var iter = self.hang.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* == self.under(entry.key_ptr.*).len) {
                try temp.append(entry.key_ptr.*);
            }
        }
        for (temp.items) |key| _ = self.hang.swapRemove(key);
        var sum: usize = 0;
        for (temp.items) |key| sum += try self.searchInner(key) + 1;
        return sum;
    }

    fn under(self: *const Self, brick: Brick) []Brick {
        return self.conns.under.getPtr(brick).?.keys();
    }

    fn above(self: *const Self, brick: Brick) []Brick {
        return self.conns.above.getPtr(brick).?.keys();
    }
};

const Brick = struct {
    start: Vec3i,
    end: Vec3i,

    const Self = @This();

    fn parse(text: []const u8) !Self {
        var ends = mem.tokenizeAny(u8, text, "~");
        return .{
            .start = try parseVec3i(ends.next().?),
            .end = try parseVec3i(ends.next().?),
        };
    }

    fn move(self: *Self, vec: Vec3i) void {
        self.start = self.start.add(vec);
        self.end = self.end.add(vec);
    }

    fn collides_xy(self: Self, other: Self) bool {
        return self.start.x <= other.end.x and
            other.start.x <= self.end.x and
            self.start.y <= other.end.y and
            other.start.y <= self.end.y;
    }

    fn collides(self: Self, other: Self) bool {
        return self.start.x <= other.end.x and
            other.start.x <= self.end.x and
            self.start.y <= other.end.y and
            other.start.y <= self.end.y and
            self.start.z <= other.end.z and
            other.start.z <= self.end.z;
    }

    fn eql(self: Self, other: Self) bool {
        return self.start.eql(other.start) and self.end.eql(other.end);
    }

    fn order(_: void, a: Self, b: Self) math.Order {
        if (a.start.z != b.start.z) return math.order(a.start.z, b.start.z);
        if (a.start.y != b.start.y) return math.order(a.start.y, b.start.y);
        return math.order(a.start.x, b.start.x);
    }

    fn lessThan(_: void, a: Self, b: Self) bool {
        if (a.start.z != b.start.z) return a.start.z < b.start.z;
        if (a.start.y != b.start.y) return a.start.y < b.start.y;
        return a.start.x < b.start.x;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{} ~ {}", .{ self.start, self.end });
    }
};

fn parseVec3i(text: []const u8) !Vec3i {
    var tokens = mem.tokenizeAny(u8, text, ",");
    return Vec3i{
        .x = try fmt.parseUnsigned(isize, tokens.next().?, 10),
        .y = try fmt.parseUnsigned(isize, tokens.next().?, 10),
        .z = try fmt.parseUnsigned(isize, tokens.next().?, 10),
    };
}

test "test" {
    const t = std.testing;
    const input =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("5", out_1);
    try t.expectEqualStrings("7", out_2);
}
