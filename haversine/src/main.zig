const std = @import("std");
const zson = @import("zson.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("LEAKS: {}\n", .{gpa.deinit()});
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("gen/pairs.json", .{});
    const meta = try file.metadata();
    const file_size = meta.size();
    defer file.close();

    const content = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(content);
    std.debug.print("{s}\n", .{content});

    std.debug.print("{s}\n", .{parser});
}
