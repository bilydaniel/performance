const std = @import("std");

var arenaAllocator: std.mem.Allocator = undefined;
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

    arenaAllocator = arena.allocator();

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

    while (instructionIndex < instructions.len) {
        var instruction = Instruction{};
        try instruction.decodeNext();
        try instruction.string(&aw);

        //std.debug.print("{s}", .{buffer[0..writer.end]});
        buffer = aw.toArrayList();
        std.debug.print("{s}", .{buffer.items});
    }
}

var instructions: []u8 = undefined;
var instructionIndex: usize = 0;
pub fn getNext() !u8 {
    if (instructionIndex >= instructions.len) {
        return error.OutOfInstructions;
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

pub fn getData(w: u8) !u16 {
    var imm: u16 = 0;
    if (w == 0) {
        const data1 = try getNext();
        imm = data1;
    } else {
        const data1 = try getNext();
        const data2: u16 = try getNext();
        const data = (data1) | (data2 << 8);
        imm = data;
    }

    return imm;
}

const Op = enum {
    none,
    mov_rm_rm,
    mov_imm_rm,
    mov_imm_r,
    add_rm_rm,
};

const Instruction = struct {
    op: Op = .none,
    d: u1 = 0, // 0 = reg is source 1 = reg is dest
    w: u1 = 0, // 0 = 8  1 = 16
    mod: u2 = 0, // 00 = memory, 01 memory 8 displace, 10 memory 16 displace, 11 register
    reg: u3 = 0,
    rm: u3 = 0,
    imm: u16 = 0,
    disp: u16 = 0,

    pub fn decodeNext(this: *Instruction) !void {
        const byte1 = try getNext();

        if (instructionSet.mov_rm_rm.check(byte1)) {
            this.op = .mov_rm_rm;

            this.d = @intCast((byte1 & 0b00000010) >> 1);
            this.w = @intCast(byte1 & 0b00000001);

            const byte2 = try getNext();
            this.mod = @intCast((byte2 & 0b11000000) >> 6);
            this.reg = @intCast((byte2 & 0b00111000) >> 3);
            this.rm = @intCast(byte2 & 0b00000111);

            if (this.mod == 1) {
                this.disp = try getData(0);
            } else if (this.mod == 2) {
                this.disp = try getData(1);
            }
        } else if (instructionSet.mov_imm_rm.check(byte1)) {
            this.op = .mov_imm_rm;
            //mov imm to rm
            //TODO: @finish
        } else if (instructionSet.mov_imm_r.check(byte1)) {
            this.op = .mov_imm_r;
            this.w = @intCast((byte1 & 0b00001000) >> 3);
            this.reg = @intCast((byte1 & 0b00000111));

            this.imm = try getData(this.w);
        } else if (instructionSet.add_rm_rm.check(byte1)) {
            //add rm + rm
            this.op = .add_rm_rm;
            // _ = try aw.writer.write();

            // const d = (byte1 & 0b00000010) >> 1;
            // const w = byte1 & 0b00000001;
            //
            // const byte2 = getNext() orelse undefined;
            //
            // const mod = byte2 & 0b11000000;
            // const reg = byte2 & 0b00111000;
            // const rm = byte2 & 0b00000111;
            //
            // const regValue = reg >> 3;
            // const regLabel = getRegister(arenaAllocator, regValue, w) catch undefined;
            // if (mod == 0b11000000) {
            //     //registers
            //     const rmLabel = getRegister(arenaAllocator, rm, w) catch undefined;
            //     if (d == 0) {
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.write(", ");
            //         // _ = try aw.writer.write(regLabel);
            //     } else {
            //         // _ = try aw.writer.write(regLabel);
            //         // _ = try aw.writer.write(", ");
            //         // _ = try aw.writer.write(rmLabel);
            //     }
            //
            //     // _ = try aw.writer.write("\n");
            // } else if (mod == 0b00000000) {
            //     //TODO:dont forget the 110 rm
            //     const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
            //
            //     if (d == 0) {
            //         // _ = try aw.writer.write("[");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.write("], ");
            //         // _ = try aw.writer.write(regLabel);
            //     } else {
            //         // _ = try aw.writer.write(regLabel);
            //         // _ = try aw.writer.write(", [");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.write("]");
            //     }
            //     // _ = try aw.writer.write("\n");
            // } else if (mod == 0b01000000) {
            //     const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
            //     const disp = getData(0);
            //
            //     if (d == 0) {
            //         // _ = try aw.writer.write("[");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.print(" + {}", .{disp});
            //         // _ = try aw.writer.write("], ");
            //         // _ = try aw.writer.write(regLabel);
            //     } else {
            //         // _ = try aw.writer.write(regLabel);
            //         // _ = try aw.writer.write(", [");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.print(" + {}", .{disp});
            //         // _ = try aw.writer.write("]");
            //     }
            //     // _ = try aw.writer.write("\n");
            // } else if (mod == 0b10000000) {
            //     const rmLabel = getAddressCalc(arenaAllocator, rm) catch undefined;
            //     const disp = getData(1);
            //
            //     if (d == 0) {
            //         // _ = try aw.writer.write("[");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.print(" + {}", .{disp});
            //         // _ = try aw.writer.write("], ");
            //         // _ = try aw.writer.write(regLabel);
            //     } else {
            //         // _ = try aw.writer.write(regLabel);
            //         // _ = try aw.writer.write(", [");
            //         // _ = try aw.writer.write(rmLabel);
            //         // _ = try aw.writer.print(" + {}", .{disp});
            //         // _ = try aw.writer.write("]");
            //     }
            //     // _ = try aw.writer.write("\n");
            // }
        } else if ((byte1 & 0b11111100) == 0b00000000) {
            //add imm + rm

        } else if ((byte1 & 0b11111100) == 0b00000000) {
            //add imm + accumulator
        }
    }
    pub fn string(this: *Instruction, aw: *std.Io.Writer.Allocating) !void {
        switch (this.op) {
            .mov_rm_rm => {
                _ = try aw.writer.write("mov ");
                try this.stringCommonModRMRM(aw);
            },
            .mov_imm_r => {
                _ = try aw.writer.write("mov ");

                const regLabel = try getRegister(arenaAllocator, this.reg, this.w);

                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});

                _ = try aw.writer.write(regLabel);
                _ = try aw.writer.write(", ");
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },

            else => {},
        }
    }
    pub fn stringCommonModRMRM(this: *Instruction, aw: *std.Io.Writer.Allocating) !void {
        const regLabel = getRegister(arenaAllocator, this.reg, this.w) catch undefined;
        switch (this.mod) {
            3 => {
                //registers
                const rmLabel = getRegister(arenaAllocator, this.rm, this.w) catch undefined;
                if (this.d == 0) {
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(rmLabel);
                }
                _ = try aw.writer.write("\n");
            },
            0 => {
                //TODO:dont forget the 110 rm
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch undefined;

                if (this.d == 0) {
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
            },
            1 => {
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch undefined;

                if (this.d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            },
            2 => {
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch undefined;
                if (this.d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("], ");
                    _ = try aw.writer.write(regLabel);
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            },
        }
    }
};

const instructionSet = struct {
    const mov_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b10001000 };
    const mov_imm_rm = InstructionDef{ .mask = 0b11111110, .value = 0b11000110 };
    const mov_imm_r = InstructionDef{ .mask = 0b11110000, .value = 0b10110000 };
    const add_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b00000000 };
};

const InstructionDef = struct {
    mask: u8,
    value: u8,

    pub fn check(this: *const InstructionDef, byte: u8) bool {
        return ((byte & this.mask) == this.value);
    }
};
