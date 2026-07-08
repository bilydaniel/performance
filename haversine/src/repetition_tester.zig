const Profiling = @import("profiling.zig");
const std = @import("std");

pub const TestMode = enum(u32) {
    uninitialized,
    testing,
    completed,
    test_error,
};

pub const ValueType = enum(usize) {
    test_count,

    cpu_time,
    mem_page_faults,
    byte_count,

    seconds,
    gb_per_second,
    kb_per_page_fault,

    count,
};

const valueTypeLen = @intFromEnum(ValueType.count);

pub const Value = struct {
    e: [valueTypeLen]u64 = [_]u64{0} ** valueTypeLen,
    per_count: [valueTypeLen]f64 = [_]f64{0.0} ** valueTypeLen,

    pub fn init() Value {
        return .{};
    }

    pub fn get(self: *const Value, v_type: ValueType) u64 {
        return self.e[@intFromEnum(v_type)];
    }

    pub fn computeDerivedValues(self: *Value, cpuFreq: u64) void {
        const testCount = self.e[@intFromEnum(ValueType.test_count)];
        const divisor: f64 = if (testCount > 0) @floatFromInt(testCount) else 1.0;

        for (&self.per_count, 0..) |*perCount, i| {
            perCount.* = @as(f64, @floatFromInt(self.e[i])) / divisor;
        }

        if (cpuFreq > 0) {
            const seconds = secondsFromCpuTime(self.per_count[@intFromEnum(ValueType.cpu_time)], cpuFreq);
            self.per_count[@intFromEnum(ValueType.seconds)] = seconds;

            if (self.per_count[@intFromEnum(ValueType.byte_count)] > 0.0) {
                const gigabyte: f64 = 1024.0 * 1024.0 * 1024.0;
                self.per_count[@intFromEnum(ValueType.gb_per_second)] = self.per_count[@intFromEnum(ValueType.byte_count)] / (gigabyte * seconds);
            }
        }

        if (self.per_count[@intFromEnum(ValueType.mem_page_faults)] > 0.0) {
            self.per_count[@intFromEnum(ValueType.kb_per_page_fault)] = self.per_count[@intFromEnum(ValueType.byte_count)] / (self.per_count[@intFromEnum(ValueType.mem_page_faults)] * 1024.0);
        }
    }

    pub fn print(self: *const Value, label: []const u8) void {
        std.debug.print("{s}: {d:.0}", .{ label, self.per_count[@intFromEnum(ValueType.cpu_time)] });
        std.debug.print(" ({d:.4}ms)", .{1000.0 * self.per_count[@intFromEnum(ValueType.seconds)]});

        if (self.per_count[@intFromEnum(ValueType.byte_count)] > 0.0) {
            std.debug.print(" {d:.4}gb/s", .{self.per_count[@intFromEnum(ValueType.gb_per_second)]});
        }

        if (self.per_count[@intFromEnum(ValueType.kb_per_page_fault)] > 0.0) {
            std.debug.print(" PF: {d:.4} ({d:.4}k/fault)", .{
                self.per_count[@intFromEnum(ValueType.mem_page_faults)],
                self.per_count[@intFromEnum(ValueType.kb_per_page_fault)],
            });
        }
    }
};

pub const TestResults = struct {
    total: Value = Value.init(),
    min: Value = Value.init(),
    max: Value = Value.init(),

    pub fn print(self: *const TestResults) void {
        self.min.print("Min");
        std.debug.print("\n", .{});
        self.max.print("Max");
        std.debug.print("\n", .{});
        self.total.print("Avg");
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
    results: TestResults = .{},

    pub fn errorMode(self: *RepetitionTester, message: []const u8) void {
        self.testMode = .test_error;
        std.debug.print("ERROR: {s}\n", .{message});
    }

    pub fn newTestWave(self: *RepetitionTester, targetProcessedByteCount: u64, cpuFreq: u64, secondsToTry: u32) void {
        if (self.testMode == .uninitialized) {
            self.testMode = .testing;
            self.targetProcessedByteCount = targetProcessedByteCount;
            self.cpuFreq = cpuFreq;
            self.printNewMinimums = true;
            self.results.min.e[@intFromEnum(ValueType.cpu_time)] = std.math.maxInt(u64);
        } else if (self.testMode == .completed) {
            self.testMode = .testing;

            if (self.targetProcessedByteCount != targetProcessedByteCount) {
                self.errorMode("TargetProcessedByteCount changed");
            }

            if (self.cpuFreq != cpuFreq) {
                self.errorMode("CPU frequency changed");
            }
        }

        self.tryForTime = @as(u64, secondsToTry) * cpuFreq;
        self.testsStartedAt = Profiling.readCPUTimer();
    }

    pub fn beginTime(self: *RepetitionTester) void {
        self.openBlockCount += 1;
        self.thisTest.e[@intFromEnum(ValueType.mem_page_faults)] -%= Profiling.readOSPageFaultCount();
        self.thisTest.e[@intFromEnum(ValueType.cpu_time)] -%= Profiling.readCPUTimer();
    }

    pub fn endTime(self: *RepetitionTester) void {
        self.thisTest.e[@intFromEnum(ValueType.cpu_time)] +%= Profiling.readCPUTimer();
        self.thisTest.e[@intFromEnum(ValueType.mem_page_faults)] +%= Profiling.readOSPageFaultCount();
        self.closedBlockCount += 1;
    }

    pub fn countBytes(self: *RepetitionTester, byteCount: u64) void {
        self.thisTest.e[@intFromEnum(ValueType.byte_count)] += byteCount;
    }

    pub fn isTesting(self: *RepetitionTester) bool {
        if (self.testMode == .testing) {
            var accumulator = self.thisTest;
            const currTime = Profiling.readCPUTimer();

            if (self.openBlockCount > 0) {
                if (self.openBlockCount != self.closedBlockCount) {
                    self.errorMode("Unbalanced beginTime/endTime");
                }

                if (accumulator.e[@intFromEnum(ValueType.byte_count)] != self.targetProcessedByteCount) {
                    self.errorMode("Processed byte count mismatch");
                }

                if (self.testMode == .testing) {
                    const results = &self.results;

                    accumulator.e[@intFromEnum(ValueType.test_count)] = 1;

                    for (0..valueTypeLen) |i| {
                        results.total.e[i] += accumulator.e[i];
                    }

                    if (results.max.get(ValueType.cpu_time) < accumulator.get(ValueType.cpu_time)) {
                        results.max = accumulator;
                    }

                    if (results.min.get(ValueType.cpu_time) > accumulator.get(ValueType.cpu_time)) {
                        results.min = accumulator;
                        self.testsStartedAt = currTime;

                        if (self.printNewMinimums) {
                            self.results.min.computeDerivedValues(self.cpuFreq);
                            self.results.min.print("Min");
                            std.debug.print("                                   \r", .{});
                        }
                    }

                    self.openBlockCount = 0;
                    self.closedBlockCount = 0;
                    self.thisTest = Value.init();
                }
            }

            if ((currTime - self.testsStartedAt) > self.tryForTime) {
                self.testMode = .completed;

                self.results.total.computeDerivedValues(self.cpuFreq);
                self.results.min.computeDerivedValues(self.cpuFreq);
                self.results.max.computeDerivedValues(self.cpuFreq);

                std.debug.print("                                                          \r", .{});
                self.results.print();
            }
        }

        return self.testMode == .testing;
    }
};

fn secondsFromCpuTime(cpuTime: f64, cpuFreq: u64) f64 {
    if (cpuFreq == 0) return 0;
    return cpuTime / @as(f64, @floatFromInt(cpuFreq));
}

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

pub const SeriesLabel = struct {
    chars: [64]u8 = [_]u8{0} ** 64,
    len: usize = 0,

    pub fn set(self: *SeriesLabel, comptime fmt: []const u8, args: anytype) void {
        const formatted = std.fmt.bufPrint(&self.chars, fmt, args) catch return;
        self.len = formatted.len;
    }

    pub fn get(self: *const SeriesLabel) []const u8 {
        return self.chars[0..self.len];
    }
};

pub const TestSeries = struct {
    allocator: std.mem.Allocator,

    maxRowCount: u32 = 0,
    columnCount: u32 = 0,
    rowIndex: u32 = 0,
    columnIndex: u32 = 0,

    testResults: []TestResults,
    rowLabels: []SeriesLabel,
    columnLabels: []SeriesLabel,
    rowLabelLabel: SeriesLabel = .{},

    pub fn init(allocator: std.mem.Allocator, columnCount: u32, maxRowCount: u32) !TestSeries {
        return TestSeries{
            .allocator = allocator,
            .maxRowCount = maxRowCount,
            .columnCount = columnCount,
            .testResults = try allocator.alloc(TestResults, columnCount * maxRowCount),
            .rowLabels = try allocator.alloc(SeriesLabel, maxRowCount),
            .columnLabels = try allocator.alloc(SeriesLabel, columnCount),
        };
    }

    pub fn deinit(self: *TestSeries) void {
        self.allocator.free(self.testResults);
        self.allocator.free(self.rowLabels);
        self.allocator.free(self.columnLabels);
        self.* = undefined;
    }

    pub fn isInBounds(self: *const TestSeries) bool {
        return (self.columnIndex < self.columnCount) and (self.rowIndex < self.maxRowCount);
    }

    pub fn setRowLabelLabel(self: *TestSeries, comptime fmt: []const u8, args: anytype) void {
        self.rowLabelLabel.set(fmt, args);
    }

    pub fn setRowLabel(self: *TestSeries, comptime fmt: []const u8, args: anytype) void {
        if (self.isInBounds()) {
            self.rowLabels[self.rowIndex].set(fmt, args);
        }
    }

    pub fn setColumnLabel(self: *TestSeries, comptime fmt: []const u8, args: anytype) void {
        if (self.isInBounds()) {
            self.columnLabels[self.columnIndex].set(fmt, args);
        }
    }

    pub fn newTestWave(self: *TestSeries, tester: *RepetitionTester, targetProcessedByteCount: u64, cpuFreq: u64, secondsToTry: u32) void {
        if (self.isInBounds()) {
            std.debug.print("\n--- {s} {s} ---\n", .{
                self.columnLabels[self.columnIndex].get(),
                self.rowLabels[self.rowIndex].get(),
            });
        }
        tester.newTestWave(targetProcessedByteCount, cpuFreq, secondsToTry);
    }

    pub fn getTestResults(self: *TestSeries, columnIndex: u32, rowIndex: u32) ?*TestResults {
        if (columnIndex < self.columnCount and rowIndex < self.maxRowCount) {
            return &self.testResults[rowIndex * self.columnCount + columnIndex];
        }
        return null;
    }

    pub fn isTesting(self: *TestSeries, tester: *RepetitionTester) bool {
        const result = tester.isTesting();

        if (!result) {
            if (self.isInBounds()) {
                if (self.getTestResults(self.columnIndex, self.rowIndex)) |res| {
                    res.* = tester.results;
                }

                self.columnIndex += 1;
                if (self.columnIndex >= self.columnCount) {
                    self.columnIndex = 0;
                    self.rowIndex += 1;
                }
            }
        }
        return result;
    }

    pub fn printCSVForValue(self: *TestSeries, valueType: ValueType, writer: anytype, coefficient: f64) !void {
        try writer.print("{s}", .{self.rowLabelLabel.get()});

        var colIndex: u32 = 0;
        while (colIndex < self.columnCount) : (colIndex += 1) {
            try writer.print(",{s}", .{self.columnLabels[colIndex].get()});
        }
        try writer.print("\n", .{});

        var rIndex: u32 = 0;
        while (rIndex < self.rowIndex) : (rIndex += 1) {
            try writer.print("{s}", .{self.rowLabels[rIndex].get()});

            var cIndex: u32 = 0;
            while (cIndex < self.columnCount) : (cIndex += 1) {
                if (self.getTestResults(cIndex, rIndex)) |testResults| {
                    const v = coefficient * testResults.min.per_count[@intFromEnum(valueType)];
                    try writer.print(",{d}", .{v});
                }
            }
            try writer.print("\n", .{});
        }
    }
};
