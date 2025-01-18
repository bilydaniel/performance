const std = @import("std");

const print = std.debug.print;

//{
//  "pairs": [
//      {"x0": 3, "y0": 6}
//  ]
//}

const Center = struct {
    x: f64,
    y: f64,

    pub fn New(rng: std.rand.DefaultPrng) Center {
        return Center{.x0};
    }
};

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

    const seedMap: ?[]const u8 = argMap.get("seed");
    var seed: ?u64 = null;
    if (seedMap) |value| {
        seed = try std.fmt.parseInt(u64, value, 10);
    }

    const pairsMap: ?[]const u8 = argMap.get("pairs");
    var pairs: usize = 10;
    if (pairsMap) |value| {
        pairs = try std.fmt.parseInt(usize, value, 10);
    }

    const batchMap: ?[]const u8 = argMap.get("batch");
    var batch: i64 = 10;
    if (batchMap) |value| {
        batch = try std.fmt.parseInt(i64, value, 10);
    }

    const clusterMap: ?[]const u8 = argMap.get("cluster");
    var cluster: ?i64 = null;
    if (!uniform) {
        cluster = 10;
    }
    if (clusterMap) |value| {
        cluster = try std.fmt.parseInt(i64, value, 10);
    }

    //TODO: make a random generator
    if (seed == null) {
        const microtimestamp = @abs(std.time.microTimestamp());
        print("{}\n", .{microtimestamp});
        seed = microtimestamp;
    }

    var rng: std.rand.DefaultPrng = std.rand.DefaultPrng.init(seed orelse undefined);
    print("{}\n", .{rng.next()});

    var file = try std.fs.cwd().createFile("pairs.json", .{});
    defer file.close();

    _ = try file.write("{\n\"pairs\": [\n");

    center = Center.New(rng);
    for (0..pairs) |i| {
        if (uniform) {
            pair_data = randomPair(rng);
        } else {
            pair_data = randomPairCenter(rng, center);
        }

        print("{}", .{i});
    }
    _ = try file.write("]\n}");
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
