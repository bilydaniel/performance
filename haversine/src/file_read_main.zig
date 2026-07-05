const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");
const FileReadTest = @import("file_read_test.zig");
const Profiling = @import("profiling.zig");

const testFunction = struct {
    name: []const u8,
    function: *const fn (repetitionTester: *RepetitionTester.RepetitionTester, readParameters: *FileReadTest.ReadParameters) void,
};

const testFunctions = [_]testFunction{
    .{
        .name = "cashe_bandwidth",
        .function = FileReadTest.casheBandwidth,
    },
};

pub fn main() !void {
    const cpuFreq = Profiling.estimateCPUTimerFreq();
    const fileName: []const u8 = "pairs.json";

    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const stat = try file.stat();
    var fileSize = stat.size;

    std.debug.print("cpu: {d}\n", .{cpuFreq});

    const KB = 1024;
    const MB = KB * KB;
    const GB = MB * KB;

    fileSize = 1 * GB;

    const testingAlignment = true;
    const allocatedBuffer = try std.heap.page_allocator.alloc(u8, fileSize);
    var destination: []u8 = undefined;

    if (testingAlignment) {
        const offset = 1;
        destination = allocatedBuffer[offset .. 1 * GB + offset];
    } else {
        destination = allocatedBuffer;
    }

    //defer std.heap.page_allocator.free(destination);
    //const destination = try allocator.alloc(u8, fileSize);

    var readParameters: FileReadTest.ReadParameters = .{
        .dest = destination,
        .fileName = fileName,
        .allocType = .none,
    };

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
