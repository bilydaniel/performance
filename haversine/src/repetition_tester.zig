const std = @import("std");
const Profiling = @import("profiling.zig");

const TestMode = enum {
    uninitialized,
    testing,
    completed,
    err,
};

const ValueType = enum {
    test_count,
    cpu_time,
    page_faults,
    byte_count,
};

const valueTypeLen = @typeInfo(ValueType).@"enum".fields.len;

const Value = struct {
    e: [valueTypeLen]u64,

    pub fn init() @This() {
        return .{
            .e = [_]u64{0} ** valueTypeLen,
        };
    }

    pub fn get(this: @This(), comptime field: ValueType) u64 {
        return this.e[@intFromEnum(field)];
    }

    pub fn set(this: *@This(), comptime field: ValueType, value: u64) void {
        this.e[@intFromEnum(field)] = value;
    }

    pub fn add(this: *@This(), comptime field: ValueType, value: u64) void {
        this.e[@intFromEnum(field)] +%= value;
    }

    pub fn sub(this: *@This(), comptime field: ValueType, value: u64) void {
        this.e[@intFromEnum(field)] -%= value;
    }

    pub fn print(this: @This(), cpuFreq: u64, label: []const u8) void {
        const testCount = this.get(.test_count); //[@intFromEnum(.test_count)];

        var divisor: u64 = 1;
        if (testCount > 0) {
            divisor = testCount;
        }

        var e: [valueTypeLen]f64 = undefined;
        for (e, 0..) |_, i| {
            e[i] = @as(f64, @floatFromInt(this.e[i])) / @as(f64, @floatFromInt(divisor));
        }

        std.debug.print("{s}: {d:.1}", .{ label, e[@intFromEnum(ValueType.cpu_time)] });
        if (cpuFreq > 0) {
            const seconds = secondsFromCpuTime(e[@intFromEnum(ValueType.cpu_time)], cpuFreq);
            std.debug.print(" ({d:.4}ms)", .{1000 * seconds});

            if (e[@intFromEnum(ValueType.byte_count)] > 0) {
                const gb = 1024 * 1024 * 1024;
                const bestBandwith = e[@intFromEnum(ValueType.byte_count)] / (gb * seconds);
                std.debug.print(" {d:.4}gb/s", .{bestBandwith});
            }
        }

        if (e[@intFromEnum(ValueType.page_faults)] > 0) {
            std.debug.print(" PF: {d:.4} ({d:.4}k/fault)", .{ e[@intFromEnum(ValueType.page_faults)], e[@intFromEnum(ValueType.byte_count)] / e[@intFromEnum(ValueType.page_faults)] * 1024.0 });
        }
    }
};

const RepetitionTestResults = struct {
    total: Value,
    min: Value,
    max: Value,

    pub fn init() @This() {
        return .{
            .total = Value.init(),
            .min = Value.init(),
            .max = Value.init(),
        };
    }

    pub fn print(this: *@This(), cpuFreq: u64) void {
        this.min.print(cpuFreq, "Min");
        std.debug.print("\n", .{});

        this.max.print(cpuFreq, "Max");
        std.debug.print("\n", .{});

        this.total.print(cpuFreq, "Avg");
        std.debug.print("\n", .{});
    }
};

pub const RepetitionTester = struct {
    targetProcessedByteCount: u64 = 0,
    cpuFreq: u64 = 0,
    tryForTime: u64 = 0,
    testsStartedAt: u64 = 0,

    testMode: TestMode = .uninitialized,
    printNewMinimums: bool = false,
    openBlockCount: u32 = 0,
    closedBlockCount: u32 = 0,

    thisTest: Value = Value.init(),
    results: RepetitionTestResults = RepetitionTestResults.init(),

    pub fn init() @This() {
        return @This();
    }

    pub fn err(this: *@This(), msg: []const u8) void {
        this.testMode = .err;
        std.debug.print("ERROR: {s}\n", .{msg});
    }

    pub fn newTestWave(this: *@This(), targetProcessedByteCount: u64, cpuFreq: u64, secondsToTry: u32) void {
        if (this.testMode == .uninitialized) {
            this.testMode = .testing;
            this.targetProcessedByteCount = targetProcessedByteCount;
            this.cpuFreq = cpuFreq;
            this.printNewMinimums = true;
            this.results.min.set(.cpu_time, std.math.maxInt(u64));
        } else if (this.testMode == .completed) {
            this.testMode = .testing;

            if (this.targetProcessedByteCount != targetProcessedByteCount) {
                this.err("targetProcessedByteCount has changed"); //if it changed between calls
            }

            if (this.cpuFreq != cpuFreq) {
                this.err("targetProcessedByteCount has changed"); //if it changed between calls
            }
        }

        this.tryForTime = secondsToTry * cpuFreq;
        this.testsStartedAt = Profiling.readCPUTimer();
    }

    pub fn beginTime(this: *@This()) void {
        this.openBlockCount += 1;

        const pageFaults = Profiling.readOSPageFaultCount();
        //std.debug.print("begin: {}\n", .{pageFaults});
        const cpuTime = Profiling.readCPUTimer();

        this.thisTest.sub(.page_faults, pageFaults);
        this.thisTest.sub(.cpu_time, cpuTime);
    }

    pub fn endTime(this: *@This()) void {
        this.closedBlockCount += 1;

        const pageFaults = Profiling.readOSPageFaultCount();
        //std.debug.print("end: {}\n", .{pageFaults});
        const cpuTime = Profiling.readCPUTimer();
        //const oldFaults = this.thisTest.get(.page_faults);

        this.thisTest.add(.page_faults, pageFaults);
        this.thisTest.add(.cpu_time, cpuTime);

        //std.debug.print("result: {}\n", .{pageFaults -% oldFaults});
    }

    pub fn countBytes(this: *@This(), byteCount: u64) void {
        this.thisTest.add(.byte_count, byteCount);
    }

    pub fn isTesting(this: *@This()) bool {
        if (this.testMode == .testing) {
            const currTime = Profiling.readCPUTimer();
            var acumulator = this.thisTest;

            if (this.openBlockCount > 0) {
                if (this.openBlockCount != this.closedBlockCount) {
                    this.err("wrong block counts");
                }

                if (acumulator.get(.byte_count) != this.targetProcessedByteCount) {
                    this.err("wrong bytes counts");
                }

                if (this.testMode == .testing) {
                    //TODO: does this work?
                    var results = &this.results;

                    acumulator.set(.test_count, 1);
                    for (0..valueTypeLen) |i| {
                        results.total.e[i] += acumulator.e[i];
                    }

                    if (results.max.get(.cpu_time) < acumulator.get(.cpu_time)) {
                        results.max = acumulator;
                    }

                    if (results.min.get(.cpu_time) > acumulator.get(.cpu_time)) {
                        results.min = acumulator;

                        this.testsStartedAt = currTime;

                        if (this.printNewMinimums) {
                            this.results.min.print(this.cpuFreq, "Min");
                            std.debug.print("                                   \r", .{});
                        }
                    }

                    this.openBlockCount = 0;
                    this.closedBlockCount = 0;
                    this.thisTest = Value.init();
                }
            }

            if ((currTime - this.testsStartedAt) > this.tryForTime) {
                this.testMode = .completed;
                std.debug.print("                                                          \r", .{});
                this.results.print(this.cpuFreq);
            }
        }

        return this.testMode == .testing;
    }
};

fn secondsFromCpuTime(cpuTime: f64, cpuFreq: u64) f64 {
    if (cpuFreq == 0) {
        return 0;
    }

    return cpuTime / @as(f64, @floatFromInt(cpuFreq));
}

//TODO: casey has a second version with cpuTime: u64
fn printTime(label: []const u8, cpuTime: f64, cpuFreq: u64, byteCount: u64) void {
    std.debug.print("{s}: {d:.1}", .{ label, cpuTime });

    if (cpuFreq > 0) {
        const seconds = secondsFromCpuTime(cpuTime, cpuFreq);
        std.debug.print(" ({d:.6}ms)", .{1000 * seconds});

        if (byteCount > 0) {
            const gb = 1024 * 1024 * 1024;
            const bestBandwith = @as(f64, @floatFromInt(byteCount)) / (gb * seconds);
            std.debug.print(" {d:.6}gb/s", .{bestBandwith});
        }
    }
}
