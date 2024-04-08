const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("../lib.zig");

pub fn part_1(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var table = Table.init(alloc);
    defer table.deinit();
    try table.parse(input);
    table.sort();
    var sum: u64 = 0;
    for (table.data.items, 1..) |entry, rank| {
        sum += entry.bid * rank;
    }
    return lib.intToString(alloc, sum);
}

pub fn part_2(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var table = Table.init(alloc);
    defer table.deinit();
    try table.parseJoker(input);
    table.sort();
    var sum: u64 = 0;
    for (table.data.items, 1..) |entry, rank| {
        sum += entry.bid * rank;
    }
    return lib.intToString(alloc, sum);
}

const Table = struct {
    data: std.ArrayList(Entry),

    fn init(alloc: mem.Allocator) Table {
        return .{ .data = std.ArrayList(Entry).init(alloc) };
    }

    fn deinit(self: Table) void {
        self.data.deinit();
    }

    fn append(self: *Table, hand: Hand, bid: u32) !void {
        try self.data.append(.{ .hand = hand, .bid = bid });
    }

    fn parse(self: *Table, text: []const u8) !void {
        var lines = mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            var parts = mem.tokenizeAny(u8, line, " ");
            const hand_text = parts.next().?;
            const bid_text = parts.next().?;
            const hand = Hand.parse(hand_text);
            const bid = try fmt.parseUnsigned(u32, bid_text, 10);
            try self.append(hand, bid);
        }
    }

    fn parseJoker(self: *Table, text: []const u8) !void {
        try self.parse(text);
        for (self.data.items) |*entry| {
            for (&entry.hand.cards) |*card| {
                if (card.value == 11) {
                    card.value = 1;
                }
            }
        }
    }

    fn sort(self: *Table) void {
        mem.sort(Entry, self.data.items, {}, Entry.asc);
    }

    pub fn format(
        self: Table,
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        for (self.data.items) |item| {
            try writer.print("{any}\n", .{item});
        }
    }
};

const Entry = struct {
    hand: Hand,
    bid: u32,

    pub fn format(
        self: Entry,
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{any} {d}", .{ self.hand, self.bid });
    }

    pub fn asc(_: void, a: Entry, b: Entry) bool {
        return a.hand.lessThan(b.hand);
    }
};

const Strength = enum(u8) {
    high_card,
    one_pair,
    two_pair,
    three_of_a_kind,
    full_house,
    four_of_a_kind,
    five_of_a_kind,
};

const Hand = struct {
    cards: [5]Card = undefined,

    fn parse(text: []const u8) Hand {
        var self = Hand{};
        for (text, 0..) |byte, index| {
            self.cards[index] = Card.parse(byte);
        }
        return self;
    }

    fn strength(self: Hand, alloc: mem.Allocator) Strength {
        var counts = std.AutoArrayHashMap(Card, u8).init(alloc);
        defer counts.deinit();

        for (self.cards) |card| {
            const result = counts.getOrPutValue(card, 1) catch unreachable;
            if (result.found_existing) {
                result.value_ptr.* += 1;
            }
        }

        var jokers: u8 = 0;
        if (counts.getPtr(Card{ .value = 1 })) |j| {
            jokers = j.*;
            j.* = 0;
        }

        var best = Strength.high_card;
        var iter = counts.iterator();
        while (iter.next()) |entry| {
            const count = entry.value_ptr.*;
            if (count == 5) {
                return Strength.five_of_a_kind;
            } else if (count == 4) {
                best = Strength.four_of_a_kind;
            } else if (count == 3) {
                if (best == Strength.one_pair) {
                    return Strength.full_house;
                } else {
                    best = Strength.three_of_a_kind;
                }
            } else if (count == 2) {
                if (best == Strength.three_of_a_kind) {
                    return Strength.full_house;
                } else if (best == Strength.one_pair) {
                    best = Strength.two_pair;
                } else {
                    best = Strength.one_pair;
                }
            }
        }

        if (jokers == 0) {
            return best;
        }

        switch (best) {
            .four_of_a_kind => if (jokers == 1) {
                return Strength.five_of_a_kind;
            } else {
                @panic("JOKERS");
            },
            .three_of_a_kind => if (jokers == 1) {
                return Strength.four_of_a_kind;
            } else if (jokers == 2) {
                return Strength.five_of_a_kind;
            } else {
                @panic("JOKERS");
            },
            .two_pair => if (jokers == 1) {
                return Strength.full_house;
            } else {
                @panic("JOKERS");
            },
            .one_pair => if (jokers == 1) {
                return Strength.three_of_a_kind;
            } else if (jokers == 2) {
                return Strength.four_of_a_kind;
            } else if (jokers == 3) {
                return Strength.five_of_a_kind;
            } else {
                @panic("JOKERS");
            },
            .high_card => if (jokers == 1) {
                return Strength.one_pair;
            } else if (jokers == 2) {
                return Strength.three_of_a_kind;
            } else if (jokers == 3) {
                return Strength.four_of_a_kind;
            } else if (jokers >= 4) {
                return Strength.five_of_a_kind;
            } else {
                @panic("JOKERS");
            },
            else => {
                @panic("JOKERS END");
            },
        }

        return best;
    }

    fn hasBetterCardThan(self: Hand, other: Hand) bool {
        for (self.cards, 0..) |this_card, index| {
            const other_card = other.cards[index];
            if (other_card.value < this_card.value) {
                return true;
            } else if (other_card.value > this_card.value) {
                return false;
            }
        }
        return false;
    }

    pub fn lessThan(self: Hand, other: Hand) bool {
        const a = self.strength(lib.allocator());
        const b = other.strength(lib.allocator());
        if (a == b) {
            return other.hasBetterCardThan(self);
        } else {
            return @intFromEnum(a) < @intFromEnum(b);
        }
    }

    pub fn format(
        self: Hand,
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        for (self.cards) |card| {
            try writer.print("{}", .{card});
        }
    }
};

const Card = struct {
    value: u8,

    fn parse(byte: u8) Card {
        return switch (byte) {
            'X' => Card{ .value = 1 }, // Joker
            '0' + 2...'0' + 9 => |n| Card{ .value = n - '0' },
            'T' => Card{ .value = 10 },
            'J' => Card{ .value = 11 },
            'Q' => Card{ .value = 12 },
            'K' => Card{ .value = 13 },
            'A' => Card{ .value = 14 },
            else => std.debug.panic("invalid character: {c}", .{byte}),
        };
    }

    fn display(self: Card) u8 {
        return switch (self.value) {
            1 => 'X', // Joker
            2...9 => |n| '0' + n,
            10 => 'T',
            11 => 'J',
            12 => 'Q',
            13 => 'K',
            14 => 'A',
            else => std.debug.panic("invalid value: {d}", .{self.value}),
        };
    }

    pub fn format(
        self: Card,
        comptime _fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = _fmt;
        _ = options;
        try writer.print("{c}", .{self.display()});
    }
};

test "test" {
    const t = std.testing;
    const input =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
        \\
    ;
    const out_1 = try part_1(t.allocator, input);
    const out_2 = try part_2(t.allocator, input);
    defer t.allocator.free(out_1);
    defer t.allocator.free(out_2);
    try t.expectEqualStrings("6440", out_1);
    try t.expectEqualStrings("5905", out_2);
}
