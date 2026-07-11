const std = @import("std");
const zson = @import("zson.zig");
const profiling = @import("profiling.zig");
const Profiler = @import("profiler.zig");

const math = std.math;

const EARTH_RADIUS = 6372.8; // KM

pub const ComputeFunc = *const fn (setup: HaversineSetup) f64;
pub const VerifyFunc = *const fn (setup: HaversineSetup) u64;

pub const HaversineSetup = struct {
    jsonBuffer: []u8 = &.{},
    answersBuffer: []u8 = &.{},
    answers: []f64 = &.{},
    parsedPairs: []zson.Pair = &.{},

    parsedByteCount: u64 = 0,
    sumAnswer: f64 = 0.0,
    valid: bool = false,

    pub fn isValid(this: *@This()) bool {
        return this.valid;
    }
};

fn dgrToRad(dgr: f64) f64 {
    return (dgr * (std.math.pi / 180.0));
}

pub fn approxEqual(x: f64, y: f64) bool {
    const epsilon = 0.00000001;
    const diff = x - y;
    const result = (diff > -epsilon and diff < epsilon);
    return result;
}

const Range = struct {
    min: f64 = math.floatMax(f64),
    max: f64 = math.floatMin(f64),
};
pub const RangeType = enum {
    cos, // -1.56 => 1.56
    sin, // -3 => 3
    asin, // 0 => 1
    sqrt, // 0 => 1
};

const rangeTypeLen = @typeInfo(RangeType).@"enum".fields.len;
pub var ranges: [rangeTypeLen]Range = [_]Range{.{}} ** rangeTypeLen;

pub fn checkRange(rangeType: RangeType, x: f64) void {
    const typeIndex = @intFromEnum(rangeType);
    const min = ranges[typeIndex].min;
    const max = ranges[typeIndex].max;

    if (x < min) {
        ranges[typeIndex].min = x;
    } else if (x > max) {
        ranges[typeIndex].max = x;
    }
}

pub fn square(x: f64) f64 {
    return x * x;
}

pub fn cos(x: f64) f64 {
    const input = x;
    checkRange(.cos, x);

    const output = math.cos(x);
    std.debug.print("cos({}) = {}\n", .{ input, output });
    return output;
}

pub fn sin(x: f64) f64 {
    checkRange(.sin, x);

    return math.sin(x);
}

pub fn asin(x: f64) f64 {
    checkRange(.asin, x);

    return math.asin(x);
}

pub fn sqrt(x: f64) f64 {
    checkRange(.sqrt, x);

    return math.sqrt(x);
}

pub fn referenceHaversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    //@setFloatMode(.optimized);

    const dy = dgrToRad(y1 - y0);
    const dx = dgrToRad(x1 - x0);
    const y0_rad = dgrToRad(y0);
    const y1_rad = dgrToRad(y1);

    //const rootTerm = (math.pow(f64, math.sin(dy / 2), 2)) + math.cos(y0_rad) * math.cos(y1_rad) * (math.pow(f64, math.sin(dx / 2), 2));

    const sin_dy_2 = sin(dy / 2.0);
    const sin_dx_2 = sin(dx / 2.0);

    const term_a = square(sin_dy_2);
    const term_b = cos(y0_rad) * cos(y1_rad) * square(sin_dx_2);

    const rootTerm = term_a + term_b;

    const result = 2 * radius * asin(
        sqrt(rootTerm),
    );
    return result;
}

// pub fn referenceHaversine(x0: f64, y0: f64, x1: f64, y1: f64, earth_radius: f64) f64 {
//     var lat1 = y0;
//     var lat2 = y1;
//     const lon1 = x0;
//     const lon2 = x1;
//
//     const d_lat = radiansFromDegrees(lat2 - lat1);
//     const d_lon = radiansFromDegrees(lon2 - lon1);
//     lat1 = radiansFromDegrees(lat1);
//     lat2 = radiansFromDegrees(lat2);
//
//     const a = square(std.math.sin(d_lat / 2.0)) + std.math.cos(lat1) * std.math.cos(lat2) * square(std.math.sin(d_lon / 2.0));
//     const c = 2.0 * std.math.asin(std.math.sqrt(a));
//
//     return earth_radius * c;
// }

pub fn referenceHaversineSum(setup: HaversineSetup) f64 {
    var sum: f64 = 0;
    const sumCoeff = 1 / @as(f64, @floatFromInt(setup.parsedPairs.len));
    for (setup.parsedPairs) |pair| {
        const dist = referenceHaversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        sum += sumCoeff * dist;
    }
    return sum;
}

pub fn referenceVerifyHaversine(setup: HaversineSetup) u64 {
    var errorCount: u64 = 0;
    for (setup.parsedPairs, 0..) |pair, i| {
        const dist = referenceHaversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        if (!approxEqual(dist, setup.answers[i])) {
            errorCount += 1;
        }
    }
    return errorCount;
}

pub fn readEntireFile(allocator: std.mem.Allocator, name: []u8) []u8 {
    var file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    const stat = try file.stat();
    const fileSize = stat.size;

    const buffer = try allocator.alloc(u8, fileSize);
    _ = try file.readAll(buffer);
}

pub fn setupHaversine(allocator: std.mem.Allocator) HaversineSetup {
    var result: HaversineSetup = .{};

    const jsonBuffer = std.fs.cwd().readFileAlloc(allocator, "pairs.json", std.math.maxInt(usize)) catch return result;
    errdefer allocator.free(jsonBuffer);

    const answersBuffer = std.fs.cwd().readFileAlloc(allocator, "answers.f64", std.math.maxInt(usize)) catch return result;
    errdefer allocator.free(answersBuffer);
    const answers: []f64 = std.mem.bytesAsSlice(f64, @as([]align(8) u8, @alignCast(answersBuffer)));

    var pairs = std.ArrayList(zson.Pair).empty;
    _ = zson.parseHaversinePairs(allocator, jsonBuffer, &pairs) catch return result;
    errdefer pairs.deinit(allocator);

    if (answers.len == pairs.items.len + 1) {
        //TODO: deinit buffers
        result.jsonBuffer = jsonBuffer;
        result.answersBuffer = answersBuffer;
        result.answers = answers[0 .. answers.len - 1];
        result.parsedPairs = pairs.items;
        result.sumAnswer = answers[answers.len - 1];
        result.parsedByteCount = @sizeOf(zson.Pair) * pairs.items.len;
        result.valid = true;

        const megabyte = 1024 * 1024;

        std.debug.print("Source JSON: {d}mb\n", .{result.jsonBuffer.len / megabyte});
        std.debug.print("Parsed: {d}mb ({d} pairs)\n", .{ result.parsedByteCount / megabyte, result.parsedPairs.len });

        result.valid = (result.parsedPairs.len != 0);
    }

    return result;
}
