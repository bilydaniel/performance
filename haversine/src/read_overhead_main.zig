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
        .name = "cashe_bandwidth",
        .function = ReadTest.casheBandwidth,
    },

    // .{
    //     .name = "read_4x2",
    //     .function = ReadTest.read_4x2,
    // },
    // .{
    //     .name = "read_8x2",
    //     .function = ReadTest.read_8x2,
    // },
    // .{
    //     .name = "read_16x2",
    //     .function = ReadTest.read_16x2,
    // },
    // .{
    //     .name = "read_16x3",
    //     .function = ReadTest.read_16x3,
    // },
    // .{
    //     .name = "read_32x2",
    //     .function = ReadTest.read_32x2,
    // },
    // .{
    //     .name = "read_64x2",
    //     .function = ReadTest.read_64x2,
    // },

    // .{
    //     .name = "read_x1",
    //     .function = ReadTest.read_x1,
    // },
    // .{
    //     .name = "read_x2",
    //     .function = ReadTest.read_x2,
    // },
    // .{
    //     .name = "read_x3",
    //     .function = ReadTest.read_x3,
    // },
    // .{
    //     .name = "read_x4",
    //     .function = ReadTest.read_x4,
    // },

    // .{
    //     .name = "NOP3x1AllBytes", // not actual reading
    //     .function = ReadTest.nop3x1AllBytes,
    // },
    // .{
    //     .name = "NOP1x3AllBytes",
    //     .function = ReadTest.nop1x3AllBytes,
    // },
    // .{
    //     .name = "NOP1x9AllBytes",
    //     .function = ReadTest.nop1x9AllBytes,
    // },
    // .{
    //     .name = "writeToAll", // not actual reading
    //     .function = ReadTest.writeToAll,
    // },
    // .{
    //     .name = "MOVAllBytes",
    //     .function = ReadTest.MOVAllBytes,
    // },
    // .{
    //     .name = "NOPAllBytes",
    //     .function = ReadTest.NOPAllBytes,
    // },
    // .{
    //     .name = "CMPAllBytes",
    //     .function = ReadTest.CMPAllBytes,
    // },
    // .{
    //     .name = "DECAllBytes", // not actual reading
    //     .function = ReadTest.DECAllBytes,
    // },
    // .{
    //     .name = "writeToAllBackwards", // not actual reading
    //     .function = ReadTest.writeToAll,
    // },
    // .{
    //     .name = "readViaReadAll",
    //     .function = ReadTest.readViaReadAll,
    // },
    // .{
    //     .name = "readViaReadSliceAllTinyBuffer",
    //     .function = ReadTest.readViaReadSliceAllTinyBuffer,
    // },
    // .{
    //     .name = "readViaReadSliceAll16K",
    //     .function = ReadTest.readViaReadSliceAll16K,
    // },
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
    var fileSize = stat.size;

    std.debug.print("cpu: {d}\n", .{cpuFreq});

    const KB = 1024;
    const MB = KB * KB;
    const GB = MB * KB;

    fileSize = 1 * GB;

    const testingAlignment = true;
    if (testingAlignment) {
        fileSize = 2 * GB;
    }

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

    var readParameters: ReadTest.ReadParameters = .{
        .dest = destination,
        .fileName = fileName,
        .allocType = .none,
    };

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
