const std = @import("std");
const mem = std.mem;
const math = std.math;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var nodeset = NodeSet.init(alloc);
    defer nodeset.deinit();
    try nodeset.parse(input);
    const keys = nodeset.keys();
    var out: usize = 0;
    blk: for (keys, 1..) |s, i| {
        for (keys[i..]) |t| {
            if (try nodeset.minCut(s, t, 3)) |cut| {
                out = cut * (nodeset.nodes.count() - cut);
                break :blk;
            }
        }
    }
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    _ = input;
    return lib.intToString(alloc, 0);
}

fn StringMap(comptime T: type) type {
    return std.StringArrayHashMap(T);
}
const StringSet = StringMap(void);

const NodeSet = struct {
    nodes: StringMap(Node),

    const Self = @This();

    fn init(alloc: mem.Allocator) Self {
        return .{ .nodes = StringMap(Node).init(alloc) };
    }

    fn deinit(self: *Self) void {
        for (self.nodes.values()) |*node| node.deinit();
        self.nodes.deinit();
    }

    fn parse(self: *Self, text: []const u8) !void {
        const alloc = self.nodes.allocator;
        var after = std.ArrayList([2][]const u8).init(alloc);
        defer after.deinit();
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            var nodes = mem.tokenizeAny(u8, line, ": ");
            const this = nodes.next().?;
            var node = try Node.initFrom(alloc, this);
            while (nodes.next()) |adj| {
                try node.addEdge(adj);
                try after.append(.{ adj, this });
            }
            try self.put(node);
        }
        // Backwards connections
        for (after.items) |pair| {
            // We don't need to check for duplicates here,
            // because every connection is represented only once.
            var entry = try self.nodes.getOrPut(pair[0]);
            if (entry.found_existing) {
                try entry.value_ptr.addEdge(pair[1]);
            } else {
                var node = try Node.initFrom(alloc, pair[0]);
                try node.addEdge(pair[1]);
                entry.value_ptr.* = node;
            }
        }
    }

    fn clone(self: Self) !Self {
        var new = Self{ .nodes = try self.nodes.clone() };
        var iter = new.nodes.iterator();
        while (iter.next()) |entry| {
            new.getMut(entry.key_ptr.*).?.* = try entry.value_ptr.clone();
        }
        return new;
    }

    fn keys(self: Self) [][]const u8 {
        return self.nodes.keys();
    }

    fn values(self: Self) []Node {
        return self.nodes.values();
    }

    fn get(self: *const Self, name: []const u8) ?*const Node {
        return self.nodes.getPtr(name);
    }

    fn getMut(self: *Self, name: []const u8) ?*Node {
        return self.nodes.getPtr(name);
    }

    fn put(self: *Self, node: Node) !void {
        try self.nodes.put(node.name, node);
    }

    fn bfs(self: *const Self, s: []const u8, t: []const u8, parent: *StringMap([]const u8)) !bool {
        const alloc = self.nodes.allocator;
        var visited = StringSet.init(alloc);
        defer visited.deinit();

        var queue = Queue([]const u8).init(alloc);
        defer queue.deinit();
        try queue.push(s);
        try visited.put(s, {});

        while (queue.pop()) |this| {
            const node = self.get(this).?;
            var iter = node.adjacent.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.* <= 0) continue;
                const adj = entry.key_ptr.*;
                if (visited.contains(adj)) continue;
                try queue.push(adj);
                try visited.put(adj, {});
                try parent.put(adj, this);
            }
        }
        return visited.contains(t);
    }

    fn dfs(self: *const Self, s: []const u8, visited: *StringSet) !void {
        try visited.put(s, {});
        const node = self.get(s).?;
        var iter = node.adjacent.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* <= 0) continue;
            const adj = entry.key_ptr.*;
            if (visited.contains(adj)) continue;
            try self.dfs(adj, visited);
        }
    }

    fn minCut(self: Self, s: []const u8, t: []const u8, expect: usize) !?usize {
        const alloc = self.nodes.allocator;
        var parent = StringMap([]const u8).init(alloc);
        defer parent.deinit();
        var graph = try self.clone();
        defer graph.deinit();

        while (try graph.bfs(s, t, &parent)) {
            var flow: isize = std.math.maxInt(isize);
            var n = t;
            while (!strEql(n, s)) {
                const p = parent.get(n).?;
                flow = @min(flow, graph.get(p).?.adjacent.get(n).?);
                n = p;
            }
            n = t;
            while (!strEql(n, s)) {
                const p = parent.get(n).?;
                graph.getMut(p).?.adjacent.getPtr(n).?.* -= flow;
                graph.getMut(n).?.adjacent.getPtr(p).?.* += flow;
                n = p;
            }
        }

        var visited = StringSet.init(alloc);
        defer visited.deinit();
        try graph.dfs(s, &visited);

        var count: usize = 0;
        for (graph.values()) |node| {
            if (!visited.contains(node.name)) continue;
            var iter = node.adjacent.iterator();
            while (iter.next()) |entry| {
                const adj = entry.key_ptr.*;
                if (!visited.contains(adj)) {
                    // print("{s} {s}\n", .{ node.name, adj });
                    count += 1;
                    if (count > expect) {
                        return null;
                    } else if (count == expect) {
                        return visited.count();
                    }
                }
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
        for (self.nodes.values()) |n| {
            try writer.print("{}\n", .{n});
        }
    }
};

const Node = struct {
    name: []const u8,
    count: usize,
    adjacent: StringMap(isize),

    const Self = @This();

    fn deinit(self: *Self) void {
        self.adjacent.deinit();
    }

    fn initFrom(alloc: mem.Allocator, node: []const u8) !Self {
        return .{
            .name = node,
            .count = 1,
            .adjacent = StringMap(isize).init(alloc),
        };
    }

    fn clone(self: Self) !Self {
        var new = self;
        new.adjacent = try self.adjacent.clone();
        return new;
    }

    fn addEdge(self: *Self, name: []const u8) !void {
        try self.adjacent.put(name, 1);
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{s}: {d} = ", .{ self.name, self.count });
        var iter = self.adjacent.iterator();
        while (iter.next()) |entry| {
            try writer.print("{s}: {d}, ", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

fn Queue(comptime T: type) type {
    return struct {
        alloc: mem.Allocator,
        slice: []T,
        head: usize,
        tail: usize,
        len: usize,

        const Self = @This();

        fn init(alloc: mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .slice = &.{},
                .head = 0,
                .tail = 0,
                .len = 0,
            };
        }

        fn deinit(self: Self) void {
            self.alloc.free(self.slice);
        }

        fn capacity(self: Self) usize {
            return self.slice.len;
        }

        fn push(self: *Self, data: T) !void {
            if (self.len == self.capacity()) {
                self.arrange();
                self.slice = try self.alloc.realloc(
                    self.slice,
                    self.capacity() + (self.capacity() + 64) / 2,
                );
            }
            self.slice[self.tail] = data;
            self.tail = (self.tail + 1) % self.capacity();
            self.len += 1;
        }

        fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            const ret = self.slice[self.head];
            self.head = (self.head + 1) % self.capacity();
            self.len -= 1;
            return ret;
        }

        fn arrange(self: *Self) void {
            mem.rotate(T, self.slice, self.head);
            self.tail = self.len;
            self.head = 0;
        }

        pub fn format(
            self: @This(),
            comptime _fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = _fmt;
            _ = options;
            var slice = try self.alloc.dupe(T, self.slice);
            mem.rotate(T, slice, self.head);
            try writer.print("{{ head: {}, tail: {}, len: {}, array: {s}", .{
                self.head,
                self.tail,
                self.len,
                slice[0..self.len],
            });
        }
    };
}

fn strEql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

test "test" {
    const t = std.testing;
    const input =
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("54", out_1);
    try t.expectEqualStrings("0", out_2);
}
