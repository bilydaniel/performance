const std = @import("std");

pub fn main() !void {
    const debug: bool = true;
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

    if (args.len != 2) {
        std.log.err("Wrong number of arguments\n", .{});
        printArgs(args);
        return error.wrongNumberOfArguments;
    }

    const cwd = std.fs.cwd();
    const fileName = args[1];

    const MB = 1024 * 1024;
    instructions = try cwd.readFileAlloc(arenaAllocator, fileName, 1 * MB);

    //var buffer: [32]u8 = undefined;
    var buffer = std.ArrayList(u8).empty;
    //var writer = std.Io.Writer.fixed(&buffer);
    var aw: std.Io.Writer.Allocating = .fromArrayList(arenaAllocator, &buffer);
    _ = try aw.writer.write("bits 16 \n");
    _ = try aw.writer.write("\n");

    while (true) {
        const byte1 = getNext() orelse break;
        var instruction = Instruction.init(byte1);
        if (debug) {
            var buf: [20]u8 = undefined;
            const op = try std.fmt.bufPrint(&buf, "op: {b}\n", .{byte1});

            _ = try aw.writer.write(op);
        }

        //std.debug.print("{s}", .{buffer[0..writer.end]});
        buffer = aw.toArrayList();
        std.debug.print("{s}", .{buffer.items});
    }
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

const registerTable = [2][8][]const u8{
    // w = 0 (8-bit registers)
    .{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" },
    // w = 1 (16-bit registers)
    .{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" },
};
pub fn getRegister(allocator: std.mem.Allocator, reg: usize, w: u8) ![]u8 {
    //allocation not necesery, just want to get used to arenas
    const register = registerTable[w][reg];
    const result = try std.fmt.allocPrint(allocator, "{s}", .{register});
    return result;
}

pub fn printArgs(args: [][:0]u8) void {
    for (args) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
}

const calcTable = [8][]const u8{ "bx + si", "bx + di", "bp + si", "bp + di", "si", "di", "bp", "bx" };
pub fn getAddressCalc(allocator: std.mem.Allocator, rm: usize) ![]u8 {
    //allocation not necesery, just want to get used to arenas
    const calc = calcTable[rm];
    const result = try std.fmt.allocPrint(allocator, "{s}", .{calc});
    return result;
}

pub fn getData(w: u8) u16 {
    var imm: u16 = 0;
    if (w == 0) {
        const data1 = getNext() orelse undefined;
        imm = data1;
    } else {
        const data1 = getNext() orelse undefined;
        const data2: u16 = getNext() orelse undefined;
        const data = (data1) | (data2 << 8);
        imm = data;
    }

    return imm;
}

const Op = enum { mov };
const OpType = enum { rmtorm };
const Instruction = struct {
    op: Op,
    opType: OpType,

    pub fn init(byte1: u8) !Instruction {
        //TODO: @finish
        if ((byte1 & 0b11111100) == 0b10001000) {
            //mov rm to/from rm
            _ = try aw.writer.write("mov ");

            const d = (byte1 & 0b00000010) >> 1; // 0 = reg is source 1 = reg is dest
            const w = byte1 & 0b00000001; // 0 = 8  1 = 16

            const byte2 = getNext() orelse undefined;
            // 00 = memory, 01 memory 8 displace, 10 memory 16 displace, 11 register
            const mod = byte2 & 0b11000000;
            const reg = byte2 & 0b00111000;
            const rm = byte2 & 0b00000111;

            const regValue = reg >> 3;
            const regLabel = getRegister(arenaAllocator, regValue, w) catch undefined;
            if (mod == 0b11000000) {
                //registers
                const rmLabel = getRegister(arenaAllocator, rm, w) catch undefined;
                if (d == 0) {
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(rmLabel);
                }

                _ = try aw.writer.write("\n");
            } else if (mod == 0b00000000) {
                //TODO:dont forget the 110 rm
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            } else if (mod == 0b01000000) {
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
                const disp = getData(0);

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            } else if (mod == 0b10000000) {
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
                const disp = getData(1);

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            }
        } else if ((byte1 & 0b11111110) == 0b11000110) {
            //mov imm to rm
            //TODO: @finish
            _ = try aw.writer.write("mov UNDEFINED\n");
            const w = byte1 & 0b00000001; // 0 = 8  1 = 16

            const byte2 = getNext() orelse undefined;

            const mod = byte2 & 0b11000000;
            const rm = byte2 & 0b00000111;

            if (mod == 0b11000000) {
                //registers
                const rmLabel = getRegister(arenaAllocator, rm, w) catch undefined;
                _ = try aw.writer.write(rmLabel);
                _ = try aw.writer.write(", ");

                _ = try aw.writer.write("\n");
            }

            var imm: u16 = 0;

            if (w == 0) {
                const immByte1 = getNext() orelse undefined;
                imm = @intCast(immByte1);
            } else {
                const immByte1 = getNext() orelse undefined;
                imm = @intCast(immByte1);
            }
        } else if ((byte1 & 0b11110000) == 0b10110000) {
            //mov imm to r
            _ = try aw.writer.write("mov ");
            const w = (byte1 & 0b00001000) >> 3;
            const reg = (byte1 & 0b00000111);

            const regLabel = try getRegister(arenaAllocator, reg, w);

            var imm: u16 = 0;
            imm = getData(w);
            var immBuff: [20]u8 = undefined;
            const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{imm});

            _ = try aw.writer.write(regLabel);
            _ = try aw.writer.write(", ");
            _ = try aw.writer.write(immString);
            _ = try aw.writer.write("\n");
        } else if ((byte1 & 0b11111100) == 0b00000000) {
            //add rm + rm
            _ = try aw.writer.write("add ");

            const d = (byte1 & 0b00000010) >> 1;
            const w = byte1 & 0b00000001;

            const byte2 = getNext() orelse undefined;

            const mod = byte2 & 0b11000000;
            const reg = byte2 & 0b00111000;
            const rm = byte2 & 0b00000111;

            const regValue = reg >> 3;
            const regLabel = getRegister(arenaAllocator, regValue, w) catch undefined;
            if (mod == 0b11000000) {
                //registers
                const rmLabel = getRegister(arenaAllocator, rm, w) catch undefined;
                if (d == 0) {
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(rmLabel);
                }

                _ = try aw.writer.write("\n");
            } else if (mod == 0b00000000) {
                //TODO:dont forget the 110 rm
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            } else if (mod == 0b01000000) {
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
                const disp = getData(0);

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            } else if (mod == 0b10000000) {
                const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
                const disp = getData(1);

                if (d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            }
        } else if ((byte1 & 0b11111100) == 0b00000000) {
            //add imm + rm

        } else if ((byte1 & 0b11111100) == 0b00000000) {
            //add imm + accumulator
        }
    }
};
