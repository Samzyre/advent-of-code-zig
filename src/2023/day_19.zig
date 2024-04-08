const std = @import("std");
const mem = std.mem;
const math = std.math;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var parsed = try parse(alloc, input);
    defer parsed.deinit();
    var sum: usize = 0;
    for (parsed.parts.items) |part| {
        const out = process(parsed.wfs.items, part);
        if (mem.eql(u8, out, "A")) {
            sum += part.x + part.m + part.a + part.s;
        }
    }
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var parsed = try parse(alloc, input);
    defer parsed.deinit();
    const out = try combinations(alloc, parsed.wfs.items);
    return lib.intToString(alloc, out);
}

fn parse(alloc: mem.Allocator, text: []const u8) !List {
    var workflows = std.ArrayList(Workflow).init(alloc);
    var parts = std.ArrayList(Part).init(alloc);
    var sections = mem.tokenizeSequence(u8, text, "\n\n");
    var w_lines = mem.tokenizeAny(u8, sections.next().?, "\r\n");
    while (w_lines.next()) |line| {
        var cases = std.ArrayList(Case).init(alloc);
        var tokens = mem.tokenizeAny(u8, line, "{},");
        const name = tokens.next().?;
        while (tokens.next()) |token| {
            if (mem.indexOfAny(u8, token, "<>")) |cmp_idx| {
                const out_idx = mem.indexOfScalar(u8, token, ':').?;
                const number = try std.fmt.parseUnsigned(u16, token[cmp_idx + 1 .. out_idx], 10);
                try cases.append(Case{
                    .condition = Expression{
                        .op = switch (token[cmp_idx]) {
                            '>' => math.CompareOperator.gt,
                            else => math.CompareOperator.lt,
                        },
                        .variable = token[0],
                        .constant = number,
                    },
                    .output = token[out_idx + 1 ..],
                });
            } else {
                try cases.append(Case{
                    .condition = null,
                    .output = token,
                });
            }
        }
        try workflows.append(Workflow{
            .name = name,
            .cases = cases,
        });
    }

    var p_lines = mem.tokenizeAny(u8, sections.next().?, "\r\n");
    while (p_lines.next()) |line| {
        var attrs = mem.tokenizeAny(u8, line, "{},=xmas");
        try parts.append(Part{
            .x = try std.fmt.parseUnsigned(u16, attrs.next().?, 10),
            .m = try std.fmt.parseUnsigned(u16, attrs.next().?, 10),
            .a = try std.fmt.parseUnsigned(u16, attrs.next().?, 10),
            .s = try std.fmt.parseUnsigned(u16, attrs.next().?, 10),
        });
    }

    return .{ .wfs = workflows, .parts = parts };
}

fn process(wfs: []const Workflow, part: Part) []const u8 {
    var out: []const u8 = "in";
    while (!mem.eql(u8, out, "A") and !mem.eql(u8, out, "R")) {
        const wf = find(wfs, out).?;
        for (wf.cases.items) |case| {
            if (case.validate(part)) |ok| {
                out = ok;
                break;
            }
        }
    }
    return out;
}

fn find(wfs: []const Workflow, name: []const u8) ?Workflow {
    for (wfs) |wf| if (mem.eql(u8, wf.name, name)) return wf;
    return null;
}

fn combinations(alloc: mem.Allocator, wfs: []const Workflow) !usize {
    const State = struct {
        label: []const u8,
        min: Part,
        max: Part,

        fn compute(self: @This()) usize {
            var sum: usize = 1;
            inline for (.{ 'x', 'm', 'a', 's' }) |v| {
                sum *= self.max.get(v) - self.min.get(v) + 1;
            }
            return sum;
        }
    };

    var queue = std.ArrayList(State).init(alloc);
    defer queue.deinit();

    const min = Part.new(1, 1, 1, 1);
    const max = Part.new(4000, 4000, 4000, 4000);
    try queue.append(State{ .label = "in", .min = min, .max = max });

    var sum: usize = 0;

    while (queue.popOrNull()) |state| {
        const wf = find(wfs, state.label).?;
        var wip_state = state;
        for (wf.cases.items) |case| {
            wip_state.label = case.output;
            if (case.condition) |cond| {
                if (cond.op == .lt) {
                    var temp_state = wip_state;
                    temp_state.max.set(cond.variable, cond.constant - 1);
                    if (case.accepted()) {
                        sum += temp_state.compute();
                    } else if (!case.rejected()) {
                        try queue.append(temp_state);
                    }
                    wip_state.min.set(cond.variable, cond.constant);
                } else {
                    var temp_state = wip_state;
                    temp_state.min.set(cond.variable, cond.constant + 1);
                    if (case.accepted()) {
                        sum += temp_state.compute();
                    } else if (!case.rejected()) {
                        try queue.append(temp_state);
                    }
                    wip_state.max.set(cond.variable, cond.constant);
                }
            } else if (case.rejected()) {
                continue;
            } else if (case.accepted()) {
                sum += wip_state.compute();
            } else {
                try queue.append(wip_state);
            }
        }
    }

    return sum;
}

const List = struct {
    wfs: std.ArrayList(Workflow),
    parts: std.ArrayList(Part),

    fn deinit(self: *@This()) void {
        for (self.wfs.items) |wf| wf.cases.deinit();
        self.wfs.deinit();
        self.parts.deinit();
    }
};

const Workflow = struct {
    name: []const u8,
    cases: std.ArrayList(Case),
};

const Case = struct {
    condition: ?Expression,
    output: []const u8,

    fn validate(self: @This(), part: Part) ?[]const u8 {
        if (self.condition) |expr| {
            if (expr.validate(part)) return self.output else return null;
        } else {
            return self.output;
        }
    }

    fn accepted(self: @This()) bool {
        return mem.eql(u8, self.output, "A");
    }

    fn rejected(self: @This()) bool {
        return mem.eql(u8, self.output, "R");
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{?} -> {s}", .{ self.condition, self.output });
    }
};

const Expression = struct {
    op: math.CompareOperator,
    variable: u8,
    constant: u16,

    fn validate(self: @This(), part: Part) bool {
        return math.compare(part.get(self.variable), self.op, self.constant);
    }

    pub fn format(
        self: @This(),
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        const op = switch (self.op) {
            .gt => ">",
            .lt => "<",
            else => @panic("unimplemented"),
        };
        try writer.print("{c} {s} {}", .{ self.variable, op, self.constant });
    }
};

const Part = struct {
    x: u16,
    m: u16,
    a: u16,
    s: u16,

    fn new(x: u16, m: u16, a: u16, s: u16) Part {
        return .{ .x = x, .m = m, .a = a, .s = s };
    }

    fn get(self: @This(), variable: u8) u16 {
        return switch (variable) {
            'x' => self.x,
            'm' => self.m,
            'a' => self.a,
            's' => self.s,
            else => @panic("unknown variable"),
        };
    }

    fn set(self: *@This(), variable: u8, value: u16) void {
        return switch (variable) {
            'x' => self.x = value,
            'm' => self.m = value,
            'a' => self.a = value,
            's' => self.s = value,
            else => @panic("unknown variable"),
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
        try writer.print("{{ {}, {}, {}, {} }}", .{ self.x, self.m, self.a, self.s });
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("19114", out_1);
    try t.expectEqualStrings("167409079868000", out_2);
}
