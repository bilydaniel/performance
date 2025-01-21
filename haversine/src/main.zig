const std = @import("std");
const zson = @import("zson.zig");

const print = std.debug.print;

pub fn main() !void {
    const start_time = std.time.milliTimestamp();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer std.debug.print("LEAKS: {}\n", .{gpa.deinit()});
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("gen/pairs.json", .{});
    const meta = try file.metadata();
    const file_size = meta.size();
    defer file.close();

    const content = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(content);
    //std.debug.print("{s}\n", .{content});

    const data = try zson.mock();

    const mid_time = std.time.milliTimestamp();

    const sum: f64 = 0;
    const count: i64 = 0;

    for (data.pairs) |pair| {
        print("{d} {d} {d} {d}\n", pair);
    }

    print("{}\n", .{sum});
    print("{}\n", .{count});
    print("{d}\n", .{start_time});
    print("{d}\n", .{start_time - mid_time});
}
