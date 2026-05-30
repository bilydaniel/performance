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
        .name = "readViaReadSliceAll16K",
        .function = ReadTest.readViaReadSliceAll16K,
    },
};

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    //
    // defer _ = gpa.deinit();

    const cpuFreq = Profiling.estimateCPUTimerFreq();
    const fileName: []const u8 = "pairs.json";

    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const stat = try file.stat();
    const fileSize = stat.size;

    std.debug.print("fileSize: {d}\n", .{fileSize});

    const destination = try std.heap.page_allocator.alloc(u8, fileSize);
    //defer std.heap.page_allocator.free(destination);
    //const destination = try allocator.alloc(u8, fileSize);

    var readParameters: ReadTest.ReadParameters = .{
        .dest = destination,
        .fileName = fileName,
        .allocType = .none,
    };

    // const types = std.meta.fields(ReadTest.AllocType);
    // const testers = [_][types.len]RepetitionTester.RepetitionTester{.{}} ** testFunctions.len;

    const types = std.meta.fields(ReadTest.AllocType);
    const tester_row = [1]RepetitionTester.RepetitionTester{.{}} ** types.len;
    const testers = [1][types.len]RepetitionTester.RepetitionTester{tester_row} ** testFunctions.len;

    while (true) {
        for (testFunctions, 0..) |testFunc, i| {
            const allocTypes = std.meta.fields(ReadTest.AllocType);
            inline for (allocTypes, 0..) |allocType, j| {
                readParameters.allocType = @enumFromInt(allocType.value);
                var tester = testers[i][j];
                std.debug.print("\n--- {s} ---\n", .{testFunc.name});
                std.debug.print("{s}\n", .{allocType.name});
                tester.newTestWave(readParameters.dest.len, cpuFreq, 10);
                testFunc.function(&tester, &readParameters);
            }
        }
    }
}
