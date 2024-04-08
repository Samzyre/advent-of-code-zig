const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var circuit = Circuit.init(alloc);
    defer circuit.deinit();
    try circuit.parse(input);
    var pulses: struct { usize, usize } = .{ 0, 0 };
    for (0..1000) |_| {
        const out = try circuit.process();
        pulses[0] += out[0];
        pulses[1] += out[1];
    }
    const out = pulses[0] * pulses[1];
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var circuit = Circuit.init(alloc);
    defer circuit.deinit();
    try circuit.parse(input);
    const out = try circuit.until("rx");
    return lib.intToString(alloc, out);
}

const Circuit = struct {
    alloc: mem.Allocator,
    connections: std.StringArrayHashMap(std.ArrayList([]const u8)),
    modules: std.ArrayList(Module),
    queue: std.ArrayList(State),

    const State = struct { from: []const u8, to: []const u8, pulse: bool };

    fn init(alloc: mem.Allocator) @This() {
        return .{
            .alloc = alloc,
            .connections = std.StringArrayHashMap(std.ArrayList([]const u8)).init(alloc),
            .modules = std.ArrayList(Module).init(alloc),
            .queue = std.ArrayList(State).init(alloc),
        };
    }

    fn deinit(self: *@This()) void {
        for (self.modules.items) |*item| item.deinit();
        for (self.connections.values()) |*item| item.deinit();
        self.modules.deinit();
        self.connections.deinit();
        self.queue.deinit();
    }

    fn parse(self: *@This(), text: []const u8) !void {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            var tokens = mem.tokenizeSequence(u8, line, " -> ");

            const tagged = tokens.next().?;
            const mod = Module.parse(self.alloc, tagged);
            try self.modules.append(mod);

            const outputs = tokens.next().?;
            var targets = mem.tokenizeAny(u8, outputs, ", ");
            while (targets.next()) |target| {
                const list = try self.connections.getOrPutValue(
                    mod.name,
                    std.ArrayList([]const u8).init(self.alloc),
                );
                try list.value_ptr.append(target);
            }
        }

        for (self.modules.items) |*mod| {
            if (mod.kind != .conjunction) continue;
            var iter = self.connections.iterator();
            while (iter.next()) |con| {
                for (con.value_ptr.items) |output| {
                    if (mem.eql(u8, mod.name, output)) {
                        try mod.kind.conjunction.memory.put(con.key_ptr.*, false);
                    }
                }
            }
        }
    }

    fn getModule(self: *@This(), name: []const u8) ?*Module {
        for (self.modules.items) |*mod| {
            if (mem.eql(u8, mod.name, name)) return mod;
        }
        return null;
    }

    fn signal(self: *@This(), input: []const u8, target: []const u8, high: bool) !void {
        if (self.connections.get(target)) |outputs| {
            var this = self.getModule(target).?;
            const result = this.kind.process(input, high);
            if (result) |pulse| {
                for (outputs.items) |to| {
                    // print("{s} -> {} -> {s}\n", .{ target, pulse, to });
                    try self.queue.insert(0, .{ .from = this.name, .to = to, .pulse = pulse });
                }
            }
        }
    }

    fn process(self: *@This()) !struct { usize, usize } {
        var pulses: struct { usize, usize } = .{ 1, 0 };
        try self.signal("button", "broadcaster", false);
        while (self.queue.popOrNull()) |step| {
            if (step.pulse) pulses[1] += 1 else pulses[0] += 1;
            try self.signal(step.from, step.to, step.pulse);
        }
        return pulses;
    }

    fn until(self: *@This(), target: []const u8) !usize {
        var visited = std.StringArrayHashMap(usize).init(self.alloc);
        defer visited.deinit();
        var counts = std.StringArrayHashMap(usize).init(self.alloc);
        defer counts.deinit();
        const intermediate = blk: {
            var inputs = self.inputIterator(target);
            break :blk inputs.next().?;
        };
        var inputs = self.inputIterator(intermediate);
        while (inputs.next()) |input| try visited.put(input, 0);
        var presses: usize = 0;
        while (true) {
            presses += 1;
            try self.signal("button", "broadcaster", false);
            while (self.queue.popOrNull()) |step| {
                if (mem.eql(u8, step.to, intermediate)) blk: {
                    if (!step.pulse) break :blk;
                    const res = try visited.getOrPutValue(step.from, 0);
                    res.value_ptr.* += 1;
                    try counts.put(step.from, presses);
                    for (visited.values()) |v| if (v == 0) break :blk;
                    var product: usize = 1;
                    for (counts.values()) |count| product = lcm(product, count);
                    return product;
                }
                try self.signal(step.from, step.to, step.pulse);
            }
        }
        return presses;
    }

    const InputIter = struct {
        iter: std.StringArrayHashMap(std.ArrayList([]const u8)).Iterator,
        target: []const u8,

        fn next(self: *@This()) ?[]const u8 {
            while (self.iter.next()) |entry| {
                for (entry.value_ptr.items) |out| {
                    if (mem.eql(u8, out, self.target)) return entry.key_ptr.*;
                }
            }
            return null;
        }
    };

    fn inputIterator(self: *@This(), target: []const u8) InputIter {
        return InputIter{
            .iter = self.connections.iterator(),
            .target = target,
        };
    }
};

const Module = struct {
    name: []const u8,
    kind: Kind,

    fn deinit(self: *@This()) void {
        switch (self.kind) {
            .conjunction => |*c| c.memory.deinit(),
            else => {},
        }
    }

    fn parse(alloc: mem.Allocator, name: []const u8) @This() {
        if (mem.startsWith(u8, name, "%")) {
            return Module{
                .name = name[1..],
                .kind = Kind{ .flipflop = .{} },
            };
        } else if (mem.startsWith(u8, name, "&")) {
            return Module{
                .name = name[1..],
                .kind = Kind{ .conjunction = .{
                    .memory = std.StringArrayHashMap(bool).init(alloc),
                } },
            };
        } else {
            return Module{
                .name = name,
                .kind = Kind{ .broadcaster = .{} },
            };
        }
    }
};

const Kind = union(enum) {
    broadcaster: struct {
        fn process(_: *@This(), _: []const u8, high: bool) ?bool {
            return high;
        }
    },
    flipflop: struct {
        state: bool = false,
        fn process(self: *@This(), _: []const u8, high: bool) ?bool {
            if (high) return null;
            self.state = !self.state;
            return self.state;
        }
    },
    conjunction: struct {
        memory: std.StringArrayHashMap(bool),
        fn process(self: *@This(), input: []const u8, high: bool) ?bool {
            self.memory.put(input, high) catch unreachable;
            var iter = self.memory.iterator();
            while (iter.next()) |item| if (!item.value_ptr.*) return true;
            return false;
        }
    },
    fn process(self: *@This(), input: []const u8, high: bool) ?bool {
        return switch (self.*) {
            .broadcaster => |*obj| obj.process(input, high),
            .flipflop => |*obj| obj.process(input, high),
            .conjunction => |*obj| obj.process(input, high),
        };
    }
};

fn lcm(a: anytype, b: anytype) @TypeOf(a, b) {
    return a * b / std.math.gcd(a, b);
}

test "test" {
    const t = std.testing;
    const input_1 =
        \\broadcaster -> a, b, c
        \\%a -> b
        \\%b -> c
        \\%c -> inv
        \\&inv -> a
        \\
    ;
    const input_2 =
        \\broadcaster -> a
        \\%a -> inv, con
        \\&inv -> b
        \\%b -> con
        \\&con -> output
        \\
    ;
    const out_1 = try part_1(t.allocator, input_1);
    const out_2 = try part_1(t.allocator, input_2);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("32000000", out_1);
    try t.expectEqualStrings("11687500", out_2);
}
