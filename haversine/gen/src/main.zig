const std = @import("std");

const print = std.debug.print;
const math = std.math;

//{
//  "pairs": [
//      {"x0": 3, "y0": 6}
//  ]
//}

const EARTH_RADIUS = 6372.8; // KM

const Point = struct {
    x: f64,
    y: f64,
};

fn generateValue(rng: *std.rand.DefaultPrng, max: f64) f64 {
    const value = rng.random().float(f64);
    const min = -max;
    return (min + (value * (max - min)));
}

fn generateValueCenter(rng: *std.rand.DefaultPrng, max: f64, center: f64) f64 {
    const value = rng.random().float(f64);
    const min = -max;
    const offset = (min + (value * (max - min))) / 3;
    const result = center + offset;
    if (result > max) {
        return max;
    }
    if (result < -max) {
        return -max;
    }
    return result;
}

fn haversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    const dy = DgrToRad(y1 - y0);
    const dx = DgrToRad(x1 - x0);
    const y0_rad = DgrToRad(y0);
    const y1_rad = DgrToRad(y1);

    const rootTerm = (math.pow(f64, math.sin(dy / 2), 2)) + math.cos(y0_rad) * math.cos(y1_rad) * (math.pow(f64, math.sin(dx / 2), 2));
    const result = 2 * radius * math.asin(math.sqrt(rootTerm));
    return result;
}

fn DgrToRad(dgr: f64) f64 {
    return (dgr * (std.math.pi / 180.0));
}

pub fn main() !void {
    var args = std.process.args();

    //skip first argument
    _ = args.next();

    const argMap = try take_args(&args);

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
    var cluster: usize = pairs / 16;
    if (clusterMap) |value| {
        cluster = try std.fmt.parseInt(usize, value, 10);
    }

    //TODO: make a random generator
    if (seed == null) {
        const microtimestamp = @abs(std.time.microTimestamp());
        seed = microtimestamp;
    }

    var rng: std.rand.DefaultPrng = std.rand.DefaultPrng.init(seed orelse undefined);

    var file = try std.fs.cwd().createFile("pairs.json", .{});
    defer file.close();

    _ = try file.write("{\n\"pairs\": [\n");
    const writer = file.writer();

    var center: Point = undefined;
    if (!uniform) {
        center.x = generateValue(&rng, 180);
        center.y = generateValue(&rng, 90);
    }
    var point0: Point = undefined;
    var point1: Point = undefined;
    var haversine_sum: f64 = 0;
    for (0..pairs) |i| {
        if (uniform) {
            point0.x = generateValue(&rng, 180);
            point0.y = generateValue(&rng, 90);
            point1.x = generateValue(&rng, 180);
            point1.y = generateValue(&rng, 90);
        } else {
            point0.x = generateValueCenter(&rng, 180, center.x);
            point0.y = generateValueCenter(&rng, 90, center.y);
            point1.x = generateValueCenter(&rng, 180, center.x);
            point1.y = generateValueCenter(&rng, 90, center.y);
        }

        const haversine_value = haversine(point0.x, point0.y, point1.x, point1.y, EARTH_RADIUS);
        haversine_sum += haversine_value;

        if (i == pairs - 1) {
            //TODO: add .16 for 16 decimal places
            try writer.print("\t\t{{\"x0\": {d},\"y0\":{d},\"x1\":{d},\"y1\":{d} }}\n", .{ point0.x, point0.y, point1.x, point1.y });
        } else {
            try writer.print("\t\t{{\"x0\": {d},\"y0\":{d},\"x1\":{d},\"y1\":{d} }},\n", .{ point0.x, point0.y, point1.x, point1.y });
        }
        //print("{d}\n", .{haversine_value});
        //std.debug.print("0: \tx:{d:.2}\n\ty:{d:.2}\n", .{ point0.x, point0.y });
        //std.debug.print("1: \tx:{d:.2}\n\ty:{d:.2}\n", .{ point1.x, point1.y });
        if (!uniform and @mod(i, cluster) == 0) {
            center.x = generateValue(&rng, 180);
            center.y = generateValue(&rng, 90);
        }
    }
    _ = try file.write("]\n}");
    const haversine_avg = haversine_sum / @as(f64, @floatFromInt(pairs));
    print("{d}\n", .{haversine_avg});
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
