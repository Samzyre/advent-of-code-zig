const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var table = Table.init(alloc);
    defer table.deinit();
    try table.parse(input);
    // print("{}", .{table});

    var count: u32 = 0;
    var current = table.find("AAA").?;
    while (!mem.eql(u8, current.name, "ZZZ")) {
        // print("{}\n", .{table.instructions});
        const dir = table.instructions.next();
        if (dir == 'L') {
            current = table.find(current.left).?;
        } else {
            current = table.find(current.right).?;
        }
        count += 1;
    }

    return lib.intToString(alloc, count);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var table = Table.init(alloc);
    defer table.deinit();
    try table.parse(input);
    // print("{}", .{table});

    var queue = std.ArrayList(Node).init(alloc);
    defer queue.deinit();

    for (table.nodes.items) |item| {
        if (item.name[item.name.len - 1] == 'A') {
            try queue.append(item);
        }
    }

    var multiple: u64 = 1;
    for (queue.items) |item| {
        table.instructions.index = 0;
        var current = item;
        var count: u64 = 0;
        while (current.name[current.name.len - 1] != 'Z') {
            // print("{}\n", .{table.instructions});
            const dir = table.instructions.next();
            if (dir == 'L') {
                current = table.find(current.left).?;
            } else {
                current = table.find(current.right).?;
            }
            count += 1;
        }
        multiple = lcm(multiple, count);
    }

    return lib.intToString(alloc, multiple);
}

fn lcm(a: anytype, b: anytype) @TypeOf(a, b) {
    return a * b / std.math.gcd(a, b);
}

const Table = struct {
    instructions: Cycle,
    nodes: std.ArrayList(Node),

    fn init(alloc: mem.Allocator) Table {
        return .{
            .instructions = undefined,
            .nodes = std.ArrayList(Node).init(alloc),
        };
    }

    fn deinit(self: Table) void {
        self.nodes.deinit();
    }

    fn parse(self: *Table, text: []const u8) !void {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        self.instructions = Cycle{ .buf = lines.next().? };
        // print("{}\n", .{self.instructions});
        while (lines.next()) |line| {
            var tokens = mem.tokenizeAny(u8, line, " =(),");
            const node = Node{
                .name = tokens.next().?,
                .left = tokens.next().?,
                .right = tokens.next().?,
            };
            // print("{}\n", .{node});
            try self.nodes.append(node);
        }
    }

    fn find(self: *const Table, name: []const u8) ?Node {
        for (self.nodes.items) |node| {
            if (mem.eql(u8, node.name, name)) {
                return node;
            }
        }
        return null;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{}\n", .{self.instructions});
        for (self.nodes.items) |item| {
            try writer.print("{}\n", .{item});
        }
    }
};

const Cycle = struct {
    buf: []const u8,
    index: usize = 0,

    pub fn next(self: *Cycle) u8 {
        if (self.index >= self.buf.len) {
            self.index = 0;
        }
        const ret = self.buf[self.index];
        self.index += 1;
        return ret;
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{s} [{d}]", .{ self.buf, self.index });
    }
};

const Node = struct {
    name: []const u8,
    left: []const u8,
    right: []const u8,

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{s} = ({s}, {s})", .{ self.name, self.left, self.right });
    }
};

test "test" {
    const t = std.testing;
    const input_1 =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
        \\
    ;
    const input_2 =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
        \\
    ;
    const input_3 =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
        \\
    ;
    const out_1 = try part_1(t.allocator, input_1);
    const out_2 = try part_1(t.allocator, input_2);
    const out_3 = try part_2(t.allocator, input_3);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    defer t.allocator.free(out_3);
    try t.expectEqualStrings("2", out_1);
    try t.expectEqualStrings("6", out_2);
    try t.expectEqualStrings("6", out_3);
}
