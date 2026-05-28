const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");
const ReadTest = @import("read_test.zig");
const Profiling = @import("profiling.zig");

const testFunction = struct {
    name: []const u8,
    function: *const fn (repetitionTester: *RepetitionTester.RepetitionTester, readParameters: *ReadTest.ReadParameters) void,
};

const testFunctions = [_]testFunction{
    .{
        .name = "readViaReadAll",
        .function = ReadTest.readViaReadAll,
    },
    .{
        .name = "readViaReadSliceAllTinyBuffer",
        .function = ReadTest.readViaReadSliceAllTinyBuffer,
    },
    .{
        .name = "readViaReadSliceAll1K",
        .function = ReadTest.readViaReadSliceAll1K,
    },
    .{
        .name = "readViaReadSliceAll16K",
        .function = ReadTest.readViaReadSliceAll16K,
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const cpuFreq = Profiling.estimateCPUTimerFreq();
    const fileName: []const u8 = "pairs.json";

    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const stat = try file.stat();
    const fileSize = stat.size;

    std.debug.print("fileSize: {d}\n", .{fileSize});

    const inputJSON = try allocator.alloc(u8, fileSize);
    defer allocator.free(inputJSON);

    const destination = try allocator.alloc(u8, fileSize);

    var readParameters: ReadTest.ReadParameters = .{
        .dest = destination,
        .fileName = fileName,
    };

    const testers = [_]RepetitionTester.RepetitionTester{.{}} ** testFunctions.len;

    while (true) {
        for (testFunctions, 0..) |testFunc, i| {
            var tester = testers[i];
            std.debug.print("\n--- {s} ---\n", .{testFunc.name});
            tester.newTestWave(readParameters.dest.len, cpuFreq, 10);
            testFunc.function(&tester, &readParameters);
        }
    }
}
