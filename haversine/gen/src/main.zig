const std = @import("std");

const print = std.debug.print;
pub fn main() !void {
    var args = std.process.args();

    //skip first argument
    _ = args.next();

    const argMap = try take_args(&args);

    var it = argMap.iterator();
    while (it.next()) |x| {
        print("key:{s}\nvalue:{s}\n", .{ x.key_ptr.*, x.value_ptr.* });
    }

    const uniformMap: []const u8 = argMap.get("uniform") orelse "false";
    var uniform: bool = false;

    if (std.mem.eql(u8, uniformMap, "true")) {
        uniform = true;
    }

    const seedMap: []const u8 = argMap.get("seed");
    var seed: ?i64 = null;
    if (seedMap != null) {
        seed = std.fmt.parseInt(i64, seedMap, 10);
    }

    const pairsMap: []const u8 = argMap.get("pairs");
    var pairs: i32 = 10;
    if (pairsMap != null) {
        pairs = std.fmt.parseInt(i64, pairsMap, 10);
    }

    const batchMap: []const u8 = argMap.get("batch");
    var batch: i32 = 10;
    if (batch != null) {
        batch = std.fmt.parseInt(i64, batchMap, 10);
    }

    const clusterMap: []const u8 = argMap.get("cluster");
    var cluster: ?i32 = null;
    if (!uniform) {
        cluster = 10;
    }
    if (cluster != null) {
        cluster = std.fmt.parseInt(i64, clusterMap, 10);
    }

    //TODO: make a random generator
}

fn take_args(args: *std.process.ArgIterator) !std.StringHashMap([]const u8) {
    var argMap = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.indexOf(u8, arg, "=") != null) {
                var split = std.mem.splitAny(u8, arg, "=");

                const key = split.next() orelse return error.InvalidArgument;

                const value = split.next() orelse return error.InvalidArgument;

                try argMap.put(key[2..], value);
            }
        }
    }
    return argMap;
}
