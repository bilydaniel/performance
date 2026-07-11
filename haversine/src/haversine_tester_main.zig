const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");
const ReferenceHaversine = @import("reference_haversine.zig");
const Profiling = @import("profiling.zig");

const testFunction = struct {
    name: []const u8,
    compute: ReferenceHaversine.ComputeFunc,
    verify: ReferenceHaversine.VerifyFunc,
};

const testFunctions = [_]testFunction{
    .{
        .name = "ReferenceHaversine",
        .compute = ReferenceHaversine.referenceHaversineSum,
        .verify = ReferenceHaversine.referenceVerifyHaversine,
    },
};

pub fn main() !void {
    const cpuFreq = Profiling.estimateCPUTimerFreq();
    std.debug.print("cpu: {d}\n", .{cpuFreq});

    const allocator = std.heap.page_allocator;

    const setup = ReferenceHaversine.setupHaversine(allocator);
    if (!setup.valid) {
        return;
    }

    var series = try RepetitionTester.TestSeries.init(allocator, testFunctions.len, 1);
    //TODO: err

    while (true) {
        for (testFunctions) |testFunc| {
            series.setColumnLabel("func: {s}", .{testFunc.name});

            var tester = RepetitionTester.RepetitionTester{};
            tester.newTestWave(setup.parsedByteCount, cpuFreq, 10);

            const individualErrorCount = testFunc.verify(setup);
            var sumErrorCount: u64 = 0;

            while (tester.isTesting()) {
                tester.beginTime();
                const check = testFunc.compute(setup);
                tester.countBytes(setup.parsedByteCount);
                tester.endTime();

                if (!ReferenceHaversine.approxEqual(check, setup.sumAnswer)) {
                    sumErrorCount += 1;
                }
            }

            if (sumErrorCount > 0 or individualErrorCount > 0) {
                std.debug.print("haversines are wrong, sum: {}, individual: {} \n", .{ sumErrorCount, individualErrorCount });
            }
        }
        var stdout_file_writer = std.fs.File.stdout().writer(&.{});
        const stdout = &stdout_file_writer.interface;
        try series.printCSVForValue(.gb_per_second, stdout, 1.0);

        for (std.enums.values(ReferenceHaversine.RangeType)) |rangeType| {
            const value = ReferenceHaversine.ranges[@intFromEnum(rangeType)];
            std.debug.print("{}: {any}\n", .{ rangeType, value });
        }
        std.debug.print("\n", .{});
    }
}
