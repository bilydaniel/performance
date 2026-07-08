const std = @import("std");
const math = std.math;

const EARTH_RADIUS = 6372.8; // KM
const Point = struct {
    x: f64,
    y: f64,
};

fn randomInRange(min: f64, max: f64) f64 {
    const value = std.crypto.random.float(f64);
    return (min + (value * (max - min)));
}

fn generateValueCenter(center: f64, radius: f64, max: f64) f64 {
    const min = -max;

    var minValue = center - radius;
    if (minValue < min) {
        minValue = min;
    }

    var maxValue = center + radius;
    if (maxValue > max) {
        maxValue = max;
    }

    const result = randomInRange(min, max);
    return result;
}

fn haversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    const dy = dgrToRad(y1 - y0);
    const dx = dgrToRad(x1 - x0);
    const y0_rad = dgrToRad(y0);
    const y1_rad = dgrToRad(y1);

    const rootTerm = (math.pow(f64, math.sin(dy / 2), 2)) + math.cos(y0_rad) * math.cos(y1_rad) * (math.pow(f64, math.sin(dx / 2), 2));
    const result = 2 * radius * math.asin(math.sqrt(rootTerm));
    return result;
}

fn dgrToRad(dgr: f64) f64 {
    return (dgr * (std.math.pi / 180.0));
}

const Arguments = struct {
    uniform: bool = false,
    seed: u64 = 0,
    numberOfPairs: usize = 100,
    clusterSize: usize = 25,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const arguments = try parseArgs(args);

    var file = try std.fs.cwd().createFile("pairs.json", .{});
    var fileAnswers = try std.fs.cwd().createFile("answers.f64", .{});

    defer file.close();
    defer fileAnswers.close();

    var buffer: [4096]u8 = undefined;
    var fileWriter = file.writer(&buffer);
    var writer = &fileWriter.interface;
    _ = try writer.write("{\n\"pairs\": [\n");

    var center: Point = undefined;
    var radiusx: f64 = undefined;
    var radiusy: f64 = undefined;
    if (!arguments.uniform) {
        center.x = randomInRange(-180, 180);
        center.y = randomInRange(-90, 90);
        radiusx = randomInRange(0, 180);
        radiusy = randomInRange(0, 90);
    }

    var point0: Point = undefined;
    var point1: Point = undefined;
    var haversine_sum: f64 = 0;
    for (0..arguments.numberOfPairs) |i| {
        if (arguments.uniform) {
            point0.x = randomInRange(-180, 180);
            point0.y = randomInRange(-90, 90);
            point1.x = randomInRange(-180, 180);
            point1.y = randomInRange(-90, 90);
        } else {
            point0.x = generateValueCenter(180, center.x, radiusx);
            point0.y = generateValueCenter(90, center.y, radiusy);
            point1.x = generateValueCenter(180, center.x, radiusx);
            point1.y = generateValueCenter(90, center.y, radiusy);
        }

        const haversine_value = haversine(point0.x, point0.y, point1.x, point1.y, EARTH_RADIUS);
        //TODO: @finish saving results of every pair into a binary file
        try fileAnswers.writeAll(std.mem.asBytes(&haversine_value));
        haversine_sum += haversine_value;

        if (i == arguments.numberOfPairs - 1) {
            try writer.print("\t\t{{\"x0\": {d:.16},\"y0\":{d:.16},\"x1\":{d:.16},\"y1\":{d:.16} }}\n", .{ point0.x, point0.y, point1.x, point1.y });
        } else {
            try writer.print("\t\t{{\"x0\": {d:.16},\"y0\":{d:.16},\"x1\":{d:.16},\"y1\":{d:.16} }},\n", .{ point0.x, point0.y, point1.x, point1.y });
        }

        if (!arguments.uniform and @mod(i, arguments.clusterSize) == 0) {
            center.x = randomInRange(-180, 180);
            center.y = randomInRange(-90, 90);
            radiusx = randomInRange(0, 180);
            radiusy = randomInRange(0, 90);
        }
    }

    _ = try writer.write("]\n}");
    try writer.flush();
    const haversine_avg = haversine_sum / @as(f64, @floatFromInt(arguments.numberOfPairs));
    std.debug.print("{d}\n", .{haversine_avg});
    try fileAnswers.writeAll(std.mem.asBytes(&haversine_avg));
}

fn parseArgs(args: [][:0]u8) !Arguments {
    var arguments = Arguments{};
    arguments.seed = @abs(std.time.microTimestamp());

    for (args) |arg| {
        std.debug.print("arg: {s}\n", .{arg});
        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.indexOf(u8, arg, "=") != null) {
                var split = std.mem.splitAny(u8, arg, "=");

                const key = split.next() orelse return error.InvalidArgument;
                const value = split.next() orelse return error.InvalidArgument;

                std.debug.print("key: {s}\n", .{key});
                std.debug.print("v: {s}\n", .{value});

                if (std.mem.eql(u8, key, "--uniform")) {
                    if (std.mem.eql(u8, value, "true")) {
                        arguments.uniform = true;
                    } else if (std.mem.eql(u8, value, "false")) {
                        arguments.uniform = false;
                    } else {
                        return error.wrongValue;
                    }
                } else if (std.mem.eql(u8, key, "--seed")) {
                    arguments.seed = try std.fmt.parseInt(u64, value, 10);
                } else if (std.mem.eql(u8, key, "--pairs")) {
                    arguments.numberOfPairs = try std.fmt.parseInt(usize, value, 10);
                } else if (std.mem.eql(u8, key, "--cluster")) {
                    arguments.clusterSize = try std.fmt.parseInt(usize, value, 10);
                } else {
                    return error.unknownArgument;
                }
            } else {
                return error.argumentHasNoEqual;
            }
        }
    }

    return arguments;
}
