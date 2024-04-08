const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const print = std.debug.print;
const lib = @import("lib.zig");

const modules = [_]type{
    @import("2023/day_0.zig"),
    // @import("2023/day_1.zig"),
    // @import("2023/day_2.zig"),
    // @import("2023/day_3.zig"),
    // @import("2023/day_4.zig"),
    // @import("2023/day_5.zig"),
    // @import("2023/day_6.zig"),
    // @import("2023/day_7.zig"),
    // @import("2023/day_8.zig"),
    // @import("2023/day_9.zig"),
    // @import("2023/day_10.zig"),
    // @import("2023/day_11.zig"),
    // @import("2023/day_12.zig"),
    // @import("2023/day_13.zig"),
    // @import("2023/day_14.zig"),
    // @import("2023/day_15.zig"),
    // @import("2023/day_16.zig"),
    // @import("2023/day_17.zig"),
    // @import("2023/day_18.zig"),
    // @import("2023/day_19.zig"),
    // @import("2023/day_20.zig"),
    // @import("2023/day_21.zig"),
    // @import("2023/day_22.zig"),
    // @import("2023/day_23.zig"),
    // @import("2023/day_24.zig"),
    // @import("2023/day_25.zig"),
};

const days: [26][]const u8 = blk: {
    var array: [26][]const u8 = undefined;
    for (0..26) |i| {
        var buf: [2]u8 = mem.zeroes([2]u8);
        const num = std.fmt.bufPrint(&buf, "{d}", .{i}) catch @panic("invalid number");
        array[i] = "day_" ++ num;
    }
    break :blk array;
};

pub fn main() !void {
    var input_dir = try fs.cwd().makeOpenPath("input", fs.Dir.OpenDirOptions{});
    defer input_dir.close();

    var gpa = heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("memory leak", .{});
    }
    const alloc = gpa.allocator();
    lib.setAllocator(alloc);

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip();
    while (args.next()) |arg| {
        const n = try fmt.parseUnsigned(usize, arg, 10);
        inline for (modules, 0..) |module, index| {
            if (n == index) try runDay(alloc, n, input_dir, module);
        }
        break;
    } else {
        print("Please provide a number of the day to run.\n\n", .{});
        inline for (modules, 0..) |module, index| {
            if (index > 0) try runDay(alloc, index, input_dir, module);
            print("\n", .{});
        }
    }
}

fn runDay(alloc: mem.Allocator, n: usize, input_dir: fs.Dir, module: type) !void {
    const day_filename = try mem.join(alloc, "", &.{ days[n], ".txt" });
    // print("{s}\n", .{day_filename});
    defer alloc.free(day_filename);
    const input_text = input_dir.readFileAlloc(alloc, day_filename, 1 << 20) catch {
        print("Missing 'input/{s}'\n", .{day_filename});
        std.process.exit(1);
    };
    defer alloc.free(input_text);
    const out_1 = try module.part_1(alloc, input_text);
    defer alloc.free(out_1);
    const out_2 = try module.part_2(alloc, input_text);
    defer alloc.free(out_2);
    print("{s}:\n{s}\n{s}\n", .{ days[n], out_1, out_2 });
}

// Include tests
test {
    lib.setAllocator(std.testing.allocator);
    inline for (modules) |module| _ = module;
}
