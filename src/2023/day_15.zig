const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const lib = @import("../lib.zig");

const _input =
    \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
    \\
;

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var tokens = mem.tokenizeAny(u8, input, ",\r\n");
    var sum: u32 = 0;
    while (tokens.next()) |token| {
        sum += hash(token);
    }
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var hm = HashMap{};
    var tokens = mem.tokenizeAny(u8, input, ",\r\n");
    while (tokens.next()) |token| {
        var split = mem.splitScalar(u8, token, '=');
        var key = split.next().?;
        if (split.next()) |value| {
            const num = try std.fmt.parseInt(u8, value, 10);
            hm.put(.{ .label = key, .value = num });
        } else {
            key = mem.trim(u8, key, "-");
            hm.remove(key);
        }
    }

    var sum: usize = 0;
    for (hm.boxes, 1..) |box, box_number| {
        const lenses = box.slice();
        for (lenses, 1..) |lens, lens_number| {
            sum += box_number * lens_number * lens.?.value;
        }
    }
    return lib.intToString(alloc, sum);
}

fn hash(text: []const u8) u8 {
    var current: u16 = 0;
    for (text) |byte| {
        current += byte;
        current *= 17;
        current %= 256;
    }
    return @intCast(current);
}

const HashMap = struct {
    const Self = @This();
    boxes: [256]Box = mem.zeroes([256]Box),

    fn put(self: *Self, item: Lens) void {
        var box = &self.boxes[hash(item.label)];
        if (box.replace(item) == null) {
            box.append(item);
        }
    }

    fn remove(self: *Self, label: []const u8) void {
        var box = &self.boxes[hash(label)];
        box.remove(label);
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{any}", .{self.boxes});
    }
};

const Box = struct {
    const Self = @This();
    lenses: [10]?Lens = [_]?Lens{null} ** 10,
    len: usize = 0,

    fn slice(self: *const Self) []const ?Lens {
        return self.lenses[0..self.len];
    }

    fn find(self: *const Self, label: []const u8) ?u8 {
        for (self.slice(), 0..) |entry, index| {
            if (entry) |lens| {
                if (mem.eql(u8, lens.label, label)) return @intCast(index);
            }
        }
        return null;
    }

    fn append(self: *Self, item: Lens) void {
        self.lenses[self.len] = item;
        self.len += 1;
    }

    fn remove(self: *Self, label: []const u8) void {
        if (self.find(label)) |index| {
            for (self.lenses[index .. self.len - 1], index + 1..) |*entry, next| {
                entry.* = self.lenses[next];
            }
            self.lenses[self.len] = null;
            self.len -= 1;
        }
    }

    fn replace(self: *Self, item: Lens) ?u8 {
        if (self.find(item.label)) |index| {
            self.lenses[index] = item;
            return index;
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
        try writer.print("{any}", .{self.slice()});
    }
};

const Lens = struct {
    label: []const u8,
    value: u8,

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{s} = {d}", .{ self.label, self.value });
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("1320", out_1);
    try t.expectEqualStrings("145", out_2);
}
