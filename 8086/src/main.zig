const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //TODO: use page for arena later, debugging now
    const pageAllocator = std.heap.page_allocator;
    _ = pageAllocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    defer _ = arena.reset(.retain_capacity);

    const arenaAllocator = arena.allocator();

    const args = try std.process.argsAlloc(arenaAllocator);
    printArgs(args);

    if (args.len != 2) {
        std.log.err("Wrong number of arguments\n", .{});
        return error.wrongNumberOfArguments;
    }

    const cwd = std.fs.cwd();
    const fileName = args[1];

    const MB = 1024 * 1024;
    instructions = try cwd.readFileAlloc(arenaAllocator, fileName, 1 * MB);

    var buffer: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    while (true) {
        writer.end = 0;
        const byte1 = getNext() orelse break;
        std.debug.print("{b}\n", .{byte1});

        const d = byte1 & 0b00000010; // 0 = reg is source 1 = reg is dest
        const w = byte1 & 0b00000001; // 0 = 8  1 = 16
        _ = d;
        _ = w;
        if ((byte1 & 0b11111100) == 0b10001000) {
            //mov
            try writer.writeAll("MOV ");

            const byte2 = getNext() orelse undefined;
            // 00 = memory, 01 memory 8 displace, 10 memory 16 displace, 11 register
            const mod = byte2 & 0b11000000;
            if (mod == 0b11000000) {
                //registers

            }

            const reg = byte2 & 0b00111000;
            const rm = byte2 & 0b00000111;
        }

        std.debug.print("write: {s}", .{buffer[0..writer.end]});
    }

    //const value: u8 = @intCast(file[0]);
}

var instructions: []u8 = undefined;
var instructionIndex: usize = 0;
pub fn getNext() ?u8 {
    if (instructionIndex >= instructions.len) {
        return null;
    }
    const instruction = instructions[instructionIndex];
    instructionIndex += 1;
    return instruction;
}

//TODO: @finish
//pub fn getRegister(){}

pub fn printArgs(args: [][:0]u8) void {
    for (args) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
}
