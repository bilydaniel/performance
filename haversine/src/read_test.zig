const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");

pub const ReadParameters = struct {
    dest: []u8,
    fileName: []const u8,
};

pub fn readViaReadSliceAllTinyBuffer(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();

        const destBuffer = readParams.dest;

        var buffer: [10]u8 = undefined; // the bigger buffer the faster it seems to be
        var reader = file.reader(&buffer);

        tester.beginTime();
        reader.interface.readSliceAll(destBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(destBuffer.len);
    }
}

pub fn readViaReadSliceAll1K(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();

        const destBuffer = readParams.dest;

        var buffer: [1024]u8 = undefined; // the bigger buffer the faster it seems to be
        var reader = file.reader(&buffer);

        tester.beginTime();
        reader.interface.readSliceAll(destBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(destBuffer.len);
    }
}

pub fn readViaReadSliceAll16K(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();

        const destBuffer = readParams.dest;

        var buffer: [1024 * 16]u8 = undefined; // the bigger buffer the faster it seems to be
        var reader = file.reader(&buffer);

        tester.beginTime();
        reader.interface.readSliceAll(destBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(destBuffer.len);
    }
}

pub fn readViaReadAll(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();

        const destBuffer = readParams.dest;

        tester.beginTime();
        _ = file.readAll(destBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(destBuffer.len);
    }
}
