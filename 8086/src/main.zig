const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //TODO: use page for arena later, debugging now
    const pageAllocator = std.heap.page_allocator;
    _ = pageAllocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    defer _ = arena.reset(.retain_capacity);

    const arenaAllocator = arena.allocator();

    const args = try std.process.argsAlloc(arenaAllocator);
    printArgs(args);

    if (args.len != 2) {
        std.log.err("Wrong number of arguments\n", .{});
        return error.wrongNumberOfArguments;
    }
}

pub fn printArgs(args: [][:0]u8) void {
    for (args) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
}
