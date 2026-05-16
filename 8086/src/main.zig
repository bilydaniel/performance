const std = @import("std");
const Cpu = @import("cpu.zig");

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

    Cpu.init();

    const MB = 1024 * 1024;
    instructions = try cwd.readFileAlloc(arenaAllocator, fileName, 1 * MB);

    //var buffer: [32]u8 = undefined;
    var buffer = std.ArrayList(u8).empty;
    //var writer = std.Io.Writer.fixed(&buffer);
    var aw: std.Io.Writer.Allocating = .fromArrayList(arenaAllocator, &buffer);
    _ = try aw.writer.write("bits 16 \n");
    _ = try aw.writer.write("\n");

    while (Cpu.ip < instructions.len) {
        var instruction = Instruction{};
        try instruction.decodeNext();
        try instruction.string(&aw);
        try Cpu.executeInstruction(instruction);
        try Cpu.getFlags(&aw);

        //std.debug.print("{s}", .{buffer[0..writer.end]});
        buffer = aw.toArrayList();
        std.debug.print("{s}", .{buffer.items});
    }

    Cpu.printRegisters();
}

var instructions: []u8 = undefined;
pub fn getNext() !u8 {
    if (Cpu.ip >= instructions.len) {
        return error.OutOfInstructions;
    }
    const instruction = instructions[@intCast(Cpu.ip)];
    Cpu.ip += 1;
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

pub fn getData(w: u8) !i16 {
    var imm: i16 = 0;
    if (w == 0) {
        const data1 = try getNext();
        imm = data1;
    } else {
        const data1 = try getNext();
        const data2: i16 = try getNext();
        const data = (data1) | (data2 << 8);
        imm = data;
    }

    return imm;
}

const Op = enum {
    none,

    // MOV
    mov_rm_rm,
    mov_imm_rm,
    mov_imm_r,

    // ADD
    add_rm_rm,
    add_imm_rm,
    add_imm_r,

    // SUB
    sub_rm_rm,
    sub_imm_rm,
    sub_imm_r,

    // CMP
    cmp_rm_rm,
    cmp_imm_rm,
    cmp_imm_r,

    // COND JUMPS
    jnz,
    je,
    jl,
    jle,
    jb,
    jbe,
    jp,
    jo,
    js,
    jne,
    jnl,
    jg,
    jnb,
    ja,
    jnp,
    jno,
    jns,
    loop,
    looz,
    loopnz,
    jcxz,
};

pub const Instruction = struct {
    op: Op = .none,
    d: u1 = 0, // 0 = reg is source 1 = reg is dest
    w: u1 = 0, // 0 = 8  1 = 16
    s: u1 = 0,
    mod: u2 = 0, // 00 = memory, 01 memory 8 displace, 10 memory 16 displace, 11 register
    reg: u3 = 0,
    rm: u3 = 0,
    imm: i16 = 0,
    disp: i16 = 0,

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
        } else if (instructionSet.any_imm_rm.check(byte1)) {
            //TODO:@finish
            //add imm + rm

            this.s = @intCast((byte1 & 0b00000010) >> 1);
            this.w = @intCast(byte1 & 0b00000001);

            const byte2 = try getNext();
            this.mod = @intCast((byte2 & 0b11000000) >> 6);
            this.reg = @intCast((byte2 & 0b00111000) >> 3);
            this.rm = @intCast(byte2 & 0b00000111);

            if (this.reg == 0) {
                this.op = .add_imm_rm;
            } else if (this.reg == 5) {
                this.op = .sub_imm_rm;
            } else if (this.reg == 7) {
                this.op = .cmp_imm_rm;
            }

            if (this.mod == 1) {
                this.disp = try getData(0);
            } else if (this.mod == 2) {
                this.disp = try getData(1);
            }

            if (this.s == 0 and this.w == 1) {
                this.imm = try getData(1);
            } else {
                this.imm = try getData(0);
            }
        } else if (instructionSet.add_imm_r.check(byte1)) {
            //add imm + accumulator
            this.op = .add_imm_r;
            this.w = @intCast(byte1 & 0b00000001);
            this.imm = try getData(this.w);
        } else if (instructionSet.sub_rm_rm.check(byte1)) {
            //sub rm + rm
            this.op = .sub_rm_rm;

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
        } else if (instructionSet.sub_imm_r.check(byte1)) {
            //sub imm + accumulator
            this.op = .sub_imm_r;
            this.w = @intCast(byte1 & 0b00000001);
            this.imm = try getData(this.w);
        } else if (instructionSet.cmp_rm_rm.check(byte1)) {
            //sub rm + rm
            this.op = .cmp_rm_rm;

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
        } else if (instructionSet.cmp_imm_r.check(byte1)) {
            //sub imm + accumulator
            this.op = .cmp_imm_r;
            this.w = @intCast(byte1 & 0b00000001);
            this.imm = try getData(this.w);
        } else if (instructionSet.jnz.check(byte1)) {
            this.op = .jnz;
            this.imm = @as(i8, @truncate(try getData(0)));
        } else if (instructionSet.je.check(byte1)) {
            this.op = .je;
            this.imm = try getData(0);
        } else if (instructionSet.jl.check(byte1)) {
            this.op = .jl;
            this.imm = try getData(0);
        } else if (instructionSet.jle.check(byte1)) {
            this.op = .jle;
            this.imm = try getData(0);
        } else if (instructionSet.jb.check(byte1)) {
            this.op = .jb;
            this.imm = try getData(0);
        } else if (instructionSet.jbe.check(byte1)) {
            this.op = .jbe;
            this.imm = try getData(0);
        } else if (instructionSet.jp.check(byte1)) {
            this.op = .jp;
            this.imm = try getData(0);
        } else if (instructionSet.jo.check(byte1)) {
            this.op = .jo;
            this.imm = try getData(0);
        } else if (instructionSet.js.check(byte1)) {
            this.op = .js;
            this.imm = try getData(0);
        } else if (instructionSet.jnl.check(byte1)) {
            this.op = .jnl;
            this.imm = try getData(0);
        }
    }
    pub fn string(this: *Instruction, aw: *std.Io.Writer.Allocating) !void {
        switch (this.op) {
            .mov_rm_rm => {
                _ = try aw.writer.write("mov ");
                try this.stringCommonModRMRM(aw, false);
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
            .add_rm_rm => {
                _ = try aw.writer.write("add ");
                try this.stringCommonModRMRM(aw, false);
            },
            .add_imm_rm => {
                _ = try aw.writer.write("add ");
                try this.stringCommonModRMRM(aw, true);
            },
            .add_imm_r => {
                //A only
                _ = try aw.writer.write("add ");
                const regLabel = try getRegister(arenaAllocator, 0, this.w);

                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});

                _ = try aw.writer.write(regLabel);
                _ = try aw.writer.write(", ");
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .sub_rm_rm => {
                _ = try aw.writer.write("sub ");
                try this.stringCommonModRMRM(aw, false);
            },
            .sub_imm_rm => {
                _ = try aw.writer.write("sub ");
                try this.stringCommonModRMRM(aw, true);
            },
            .sub_imm_r => {
                //A only
                _ = try aw.writer.write("sub ");
                const regLabel = try getRegister(arenaAllocator, 0, this.w);

                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});

                _ = try aw.writer.write(regLabel);
                _ = try aw.writer.write(", ");
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .cmp_rm_rm => {
                _ = try aw.writer.write("cmp ");
                try this.stringCommonModRMRM(aw, false);
            },
            .cmp_imm_rm => {
                _ = try aw.writer.write("cmp ");
                try this.stringCommonModRMRM(aw, true);
            },
            .cmp_imm_r => {
                //A only
                _ = try aw.writer.write("cmp ");
                const regLabel = try getRegister(arenaAllocator, 0, this.w);

                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});

                _ = try aw.writer.write(regLabel);
                _ = try aw.writer.write(", ");
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .jnz => {
                _ = try aw.writer.write("jnz ");
                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .je => {
                _ = try aw.writer.write("je ");
                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .jl => {
                _ = try aw.writer.write("jl ");
                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .jle => {
                _ = try aw.writer.write("jle ");
                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            .jb => {
                _ = try aw.writer.write("jbe ");
                var immBuff: [20]u8 = undefined;
                const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});
                _ = try aw.writer.write(immString);
                _ = try aw.writer.write("\n");
            },
            //TODO: @finish

            else => {},
        }
    }
    pub fn stringCommonModRMRM(this: *Instruction, aw: *std.Io.Writer.Allocating, useImm: bool) !void {
        const regLabel = getRegister(arenaAllocator, this.reg, this.w) catch unreachable;

        var immBuff: [20]u8 = undefined;
        const immString = try std.fmt.bufPrint(&immBuff, "{d}", .{this.imm});

        switch (this.mod) {
            3 => {
                //registers
                const rmLabel = getRegister(arenaAllocator, this.rm, this.w) catch unreachable;
                if (this.d == 0) {
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write(", ");
                    if (useImm) {
                        _ = try aw.writer.write(immString);
                    } else {
                        _ = try aw.writer.write(regLabel);
                    }
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", ");
                    _ = try aw.writer.write(rmLabel);
                }
                _ = try aw.writer.write("\n");
            },
            0 => {
                //TODO:dont forget the 110 rm
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch unreachable;

                if (this.d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("], ");
                    if (useImm) {
                        _ = try aw.writer.write(immString);
                    } else {
                        _ = try aw.writer.write(regLabel);
                    }
                } else {
                    _ = try aw.writer.write(regLabel);
                    _ = try aw.writer.write(", [");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.write("]");
                }
                _ = try aw.writer.write("\n");
            },
            1 => {
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch unreachable;

                if (this.d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("], ");
                    if (useImm) {
                        _ = try aw.writer.write(immString);
                    } else {
                        _ = try aw.writer.write(regLabel);
                    }
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
                const rmLabel = getAddressCalc(arenaAllocator, this.rm) catch unreachable;
                if (this.d == 0) {
                    _ = try aw.writer.write("[");
                    _ = try aw.writer.write(rmLabel);
                    _ = try aw.writer.print(" + {}", .{this.disp});
                    _ = try aw.writer.write("], ");
                    if (useImm) {
                        _ = try aw.writer.write(immString);
                    } else {
                        _ = try aw.writer.write(regLabel);
                    }
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
    // MOV
    const mov_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b10001000 };
    const mov_imm_rm = InstructionDef{ .mask = 0b11111110, .value = 0b11000110 };
    const mov_imm_r = InstructionDef{ .mask = 0b11110000, .value = 0b10110000 };

    const any_imm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b10000000 };

    // ADD
    const add_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b00000000 };
    const add_imm_r = InstructionDef{ .mask = 0b11111110, .value = 0b00000100 };

    // SUB
    const sub_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b00101000 };
    const sub_imm_r = InstructionDef{ .mask = 0b11111110, .value = 0b00101100 };

    // CMP
    const cmp_rm_rm = InstructionDef{ .mask = 0b11111100, .value = 0b00111000 };
    const cmp_imm_r = InstructionDef{ .mask = 0b11111110, .value = 0b00111100 };

    const jnz = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    const je = InstructionDef{ .mask = 0b11111111, .value = 0b01110100 };
    const jl = InstructionDef{ .mask = 0b11111111, .value = 0b01111100 };
    const jle = InstructionDef{ .mask = 0b11111111, .value = 0b01111110 };
    const jb = InstructionDef{ .mask = 0b11111111, .value = 0b01110010 };
    const jbe = InstructionDef{ .mask = 0b11111111, .value = 0b01110110 };
    const jp = InstructionDef{ .mask = 0b11111111, .value = 0b01111010 };
    const jo = InstructionDef{ .mask = 0b11111111, .value = 0b01110000 };
    const js = InstructionDef{ .mask = 0b11111111, .value = 0b01111000 };
    const jnl = InstructionDef{ .mask = 0b11111111, .value = 0b01111101 };
    //TODO: @finish
    // const jg = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const jnb = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const ja = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const jnp = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const jno = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const jns = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const loop = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const loopz = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const loopnz = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
    // const jcxz = InstructionDef{ .mask = 0b11111111, .value = 0b01110101 };
};

const InstructionDef = struct {
    mask: u8,
    value: u8,

    pub fn check(this: *const InstructionDef, byte: u8) bool {
        return ((byte & this.mask) == this.value);
    }
};
