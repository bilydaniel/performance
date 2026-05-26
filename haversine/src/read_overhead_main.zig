const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");
const ReadTest = @import("read_test.zig");
const Profiling = @import("profiling.zig");

const testFunction = struct {
    name: []u8,
    function: *const fn (repetitionTester: *RepetitionTester.Tester, readParameters: *ReadTest.ReadParameters) void,
};

const testFunctions = [_]testFunction{.{
    .name = "asd",
    .function = main, //TODO:
}};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const cpuFreq = Profiling.estimateCPUTimerFreq();

    var file = try std.fs.cwd().openFile("pairs.json", .{});
    defer file.close();

    const stat = try file.stat();
    const fileSize = stat.size;

    const inputJSON = try allocator.alloc(u8, fileSize);
    var buffer: [4096 * 4]u8 = undefined; // the bigger buffer the faster it seems to be
    var reader = file.reader(&buffer);

    //const inputJSON = try reader.interface.readAlloc(allocator, fileSize);
    try reader.interface.readSliceAll(inputJSON);

    defer allocator.free(inputJSON);
    //TODO: @continue
}
