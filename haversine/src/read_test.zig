const std = @import("std");
const RepetitionTester = @import("repetition_tester.zig");

pub const ReadParameters = struct {
    dest: []u8,
    fileName: []const u8,
    allocType: AllocType,
};

pub const AllocType = enum {
    none,
    //alloc,
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

        var buffer: [10]u8 = undefined; // the bigger buffer the faster it seems to be
        var reader = file.reader(&buffer);

        tester.beginTime();
        reader.interface.readSliceAll(fileBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(fileBuffer.len);
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

        var buffer: [1024 * 16]u8 = undefined; // the bigger buffer the faster it seems to be
        var reader = file.reader(&buffer);

        tester.beginTime();
        reader.interface.readSliceAll(fileBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(fileBuffer.len);
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

        tester.beginTime();
        _ = file.readAll(fileBuffer) catch {
            tester.endTime();
            tester.err("error reading file\n");
            return;
        };
        tester.endTime();

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
    }
}

pub noinline fn writeToAll(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        var i: usize = 0;
        while (i < fileBuffer.len) : (i += 1) {
            fileBuffer[i] = @truncate(i);
        }
        // for (0..fileBuffer.len) |i| {
        //     fileBuffer[i] = @truncate(i);
        // }

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

extern fn MOVAllBytesASM(count: u64, data: [*]u8) void;
extern fn NOPAllBytesASM(count: u64) void;
extern fn CMPAllBytesASM(count: u64) void;
extern fn DECAllBytesASM(count: u64) void;

pub noinline fn MOVAllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        MOVAllBytesASM(fileBuffer.len, fileBuffer.ptr);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

pub noinline fn NOPAllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        NOPAllBytesASM(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

pub noinline fn CMPAllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        CMPAllBytesASM(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

pub noinline fn DECAllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        DECAllBytesASM(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

pub fn writeToAllBackwards(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        for (0..fileBuffer.len) |i| {
            fileBuffer[i - 1 - i] = @truncate(i);
        }

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}

extern fn NOP3x1AllBytes(count: u64) void;
extern fn NOP1x3AllBytes(count: u64) void;
extern fn NOP1x9AllBytes(count: u64) void;

pub noinline fn nop3x1AllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        NOP3x1AllBytes(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}
pub noinline fn nop1x3AllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        NOP1x3AllBytes(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}
pub noinline fn nop1x9AllBytes(tester: *RepetitionTester.RepetitionTester, readParams: *ReadParameters) void {
    while (tester.isTesting()) {
        var fileBuffer = readParams.dest;
        tester.beginTime();
        handleAlloc(readParams, &fileBuffer);

        NOP1x9AllBytes(fileBuffer.len);

        tester.countBytes(fileBuffer.len);
        handleDealloc(readParams, &fileBuffer);
        tester.endTime();
    }
}
