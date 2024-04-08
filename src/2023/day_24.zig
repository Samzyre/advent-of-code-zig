const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const math = std.math;
const print = std.debug.print;
const lib = @import("../lib.zig");

const Vec3i = lib.Vec3(isize);
const Vec3f = lib.Vec3(f64);

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var hs = std.ArrayList(Hailstone).init(alloc);
    defer hs.deinit();
    try parse(&hs, input);
    const out = intersectionsXY(hs.items, 200000000000000, 400000000000000);
    return lib.intToString(alloc, out);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var hs = std.ArrayList(Hailstone).init(alloc);
    defer hs.deinit();
    try parse(&hs, input);
    const r = lineUpPos(hs.items);
    const out = r.x + r.y + r.z;
    return lib.intToString(alloc, out);
}

fn parse(buf: *std.ArrayList(Hailstone), text: []const u8) !void {
    var lines = mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        var parts = mem.splitScalar(u8, line, '@');
        try buf.append(Hailstone{
            .pos = try parseVec3i(parts.next().?),
            .vel = try parseVec3i(parts.next().?),
        });
    }
}

fn parseVec3i(text: []const u8) !Vec3i {
    var tokens = mem.tokenizeAny(u8, text, ", ");
    return Vec3i{
        .x = try fmt.parseInt(isize, tokens.next().?, 10),
        .y = try fmt.parseInt(isize, tokens.next().?, 10),
        .z = try fmt.parseInt(isize, tokens.next().?, 10),
    };
}

fn intersectionsXY(
    hs: []const Hailstone,
    min: isize,
    max: isize,
) usize {
    const minf: f64 = @floatFromInt(min);
    const maxf: f64 = @floatFromInt(max);
    var sum: usize = 0;
    for (hs, 1..) |a, i| {
        const aa = a.toLine(max);
        for (hs[i..]) |b| {
            const bb = b.toLine(max);
            // print("{} x {}\n", .{ aa, bb });
            if (aa.intersectionXY(bb)) |p| {
                // print("{any}\n", .{p});
                if (p[1] < 0.0 or p[2] < 0.0) continue;
                if (!p[0].inBoundsXY(minf, minf, maxf, maxf)) continue;
                sum += 1;
            }
        }
    }
    return sum;
}

fn lineUpPos(hs: []const Hailstone) Vec3f {
    // (Vi - Vj) x (Pi - Pj) . P = (Vi - Vj) . (Pi x Pj)
    var a: [3]Vec3f = undefined;
    var b: [3]f64 = undefined;
    for (0..3) |idx| {
        const vi = hs[idx].vel;
        const vj = hs[(idx + 1) % 3].vel;
        const vd = vi.sub(vj).toFloat();
        const pi = hs[idx].pos.toFloat();
        const pj = hs[(idx + 1) % 3].pos.toFloat();
        a[idx] = vd.cross(pi.sub(pj));
        b[idx] = vd.dot(pi.cross(pj));
    }
    const i = invert(a);
    const r = Vec3f.new(
        i[0].x * b[0] + i[0].y * b[1] + i[0].z * b[2],
        i[1].x * b[0] + i[1].y * b[1] + i[1].z * b[2],
        i[2].x * b[0] + i[2].y * b[1] + i[2].z * b[2],
    );
    // print("{any}\n", .{a});
    // print("{any}\n", .{b});
    // print("{any}\n", .{i});
    // print("{any}\n", .{r});
    return r;
}

fn invert(m: [3]Vec3f) [3]Vec3f {
    const v = Vec3f.new;
    const det =
        m[0].x * m[1].y * m[2].z +
        m[0].y * m[1].z * m[2].x +
        m[0].z * m[1].x * m[2].y -
        m[0].z * m[1].y * m[2].x -
        m[0].y * m[1].x * m[2].z -
        m[0].x * m[1].z * m[2].y;
    const minors = .{
        v(
            m[1].y * m[2].z - m[1].z * m[2].y,
            m[1].x * m[2].z - m[1].z * m[2].x,
            m[1].x * m[2].y - m[1].y * m[2].x,
        ),
        v(
            m[0].y * m[2].z - m[0].z * m[2].y,
            m[0].x * m[2].z - m[0].z * m[2].x,
            m[0].x * m[2].y - m[0].y * m[2].x,
        ),
        v(
            m[0].y * m[1].z - m[0].z * m[1].y,
            m[0].x * m[1].z - m[0].z * m[1].x,
            m[0].x * m[1].y - m[0].y * m[1].x,
        ),
    };
    return .{
        v(minors[0].x, -minors[1].x, minors[2].x).div(det),
        v(-minors[0].y, minors[1].y, -minors[2].y).div(det),
        v(minors[0].z, -minors[1].z, minors[2].z).div(det),
    };
}

const Hailstone = struct {
    pos: Vec3i,
    vel: Vec3i,

    const Self = @This();

    fn intersection(self: Self, other: Self) void {
        _ = self;
        _ = other;
    }

    fn toLine(self: Self, max: isize) Line {
        return Line{
            .start = self.pos,
            .end = self.pos.add(
                Vec3i.new(max * self.vel.x, max * self.vel.y, max * self.vel.z),
            ),
        };
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{{ {}, {} }}", .{ self.pos, self.vel });
    }
};

const Line = struct {
    start: Vec3i,
    end: Vec3i,

    const Self = @This();

    fn intersectionXY(self: Self, other: Self) ?struct { Vec3f, f64, f64 } {
        const a = self.start.toFloat();
        const b = self.end.toFloat();
        const c = other.start.toFloat();
        const d = other.end.toFloat();
        const ab = b.sub(a);
        const cd = d.sub(c);
        const ab_cd = ab.crossXY(cd);
        if (ab_cd == 0.0) return null;
        const ac = c.sub(a);
        const t1 = ac.crossXY(cd) / ab_cd;
        const t2 = -ab.crossXY(ac) / ab_cd;
        return .{ a.add(ab.mul(t1)), t1, t2 };
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{{ {}, {} }}", .{ self.start, self.end });
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
        \\
    ;
    var hs = std.ArrayList(Hailstone).init(t.allocator);
    defer hs.deinit();
    try parse(&hs, input);
    const out_1 = intersectionsXY(hs.items, 7, 27);
    const r = lineUpPos(hs.items);
    const out_2 = r.x + r.y + r.z;
    try t.expectEqual(2, out_1);
    try t.expectEqual(47, out_2);
}
