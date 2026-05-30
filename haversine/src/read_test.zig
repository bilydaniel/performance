const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");

pub const ReadParameters = struct {
    dest: []u8,
    fileName: []const u8,
    allocType: AllocType,
};

pub const AllocType = enum {
    none,
    alloc,
};

pub fn handleAlloc(readParams: *ReadParameters, buffer: *[]u8) void {
    if (readParams.allocType == .none) {
        return;
    } else if (readParams.allocType == .alloc) {
        const buf = buffer;
        buf.* = std.heap.page_allocator.alloc(u8, readParams.dest.len) catch {
            std.debug.print("allocation error\n", .{});
            return;
        };
    }
}

pub fn handleDealloc(readParams: *ReadParameters, buffer: *[]u8) void {
    if (readParams.allocType == .none) {
        return;
    } else if (readParams.allocType == .alloc) {
        std.heap.page_allocator.free(buffer.*);
    }
}

pub fn readViaReadSliceAllTinyBuffer(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();
        var fileBuffer = readParams.dest;
        handleAlloc(readParams, &fileBuffer);

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
        handleDealloc(readParams, &fileBuffer);
    }
}

pub fn readViaReadSliceAll16K(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();
        var fileBuffer = readParams.dest;
        handleAlloc(readParams, &fileBuffer);

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
        handleDealloc(readParams, &fileBuffer);
    }
}

pub fn readViaReadAll(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        const file = std.fs.cwd().openFile(readParams.fileName, .{}) catch {
            tester.err("error opening file\n");
            return;
        };
        defer file.close();

        var fileBuffer = readParams.dest;
        handleAlloc(readParams, &fileBuffer);

        const destBuffer = readParams.dest;

        tester.beginTime();
        _ = file.readAll(destBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(destBuffer.len);
        handleDealloc(readParams, &fileBuffer);
    }
}
