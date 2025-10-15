package main

import (
	"fmt"
)

type cpu struct {
	inst      instruction
	registers map[int8]int16
	memory    [1024 * 1024]int8
	zeroFlag  bool
	signFlag  bool
}

func newCpu() cpu {
	return cpu{
		registers: map[int8]int16{},
	}
}

type instruction struct {
	opcode  int
	d       bool
	w       bool
	mod     int8
	reg     int8
	rm      int8
	data    int16
	imm     bool
	address int16
}

func (c *cpu) printRegisters() {
	fmt.Printf("AX: %d\n", c.registers[0])
	fmt.Printf("CX: %d\n", c.registers[1])
	fmt.Printf("DX: %d\n", c.registers[2])
	fmt.Printf("BX: %d\n", c.registers[3])
	fmt.Printf("SP: %d\n", c.registers[4])
	fmt.Printf("BP: %d\n", c.registers[5])
	fmt.Printf("SI: %d\n", c.registers[6])
	fmt.Printf("DI: %d\n", c.registers[7])
	fmt.Printf("ZF: %v\n", c.zeroFlag)
	fmt.Printf("SF: %v\n", c.signFlag)
}

func (c *cpu) mov() {
	c.resetFlags()

	if c.inst.imm {
		c.registers[c.inst.reg] = c.inst.data
		c.inst.imm = false
		return
	}

	if c.inst.mod == 3 {
		if c.inst.d {
			c.registers[c.inst.reg] = c.registers[c.inst.rm]
		} else {
			c.registers[c.inst.rm] = c.registers[c.inst.reg]
		}
	} else {
		if c.inst.d {
			if c.inst.w {
				c.registers[c.inst.reg] = int16(int16(c.memory[c.inst.address]) | (int16(c.memory[c.inst.address+1]) << 8))
			} else {
				c.registers[c.inst.reg] = int16(c.memory[c.inst.address])
			}
		} else {
			if c.inst.w {
				c.memory[c.inst.address] = int8(c.registers[c.inst.reg])
				c.memory[c.inst.address+1] = int8(c.registers[c.inst.reg] >> 8)
			} else {
				c.memory[c.inst.address] = int8(c.registers[c.inst.reg])
			}
		}
	}

}

func (c *cpu) movIM() {
	c.resetFlags()
	if c.inst.w {
		c.memory[c.inst.address] = int8(c.inst.data)
		c.memory[c.inst.address+1] = int8(c.inst.data >> 8)
	} else {
		c.memory[c.inst.address] = int8(c.inst.data)
	}
}

func (c *cpu) resetFlags() {
	c.zeroFlag = false
	c.signFlag = false
}

func (c *cpu) getFlags(result int16) {
	if result == 0 {
		c.zeroFlag = true
	} else {
		c.zeroFlag = false
	}
	//TODO spravne se ma kontorlovat horni bit, nefungovalo, mozna zkusit vyresit
	if result < 0 {
		c.signFlag = true
	} else {
		c.signFlag = false
	}
	//TODO MEMORY
}

func (c *cpu) add() {
	if c.inst.imm {
		c.registers[c.inst.rm] += c.inst.data
		c.getFlags(c.registers[c.inst.rm])
		c.inst.imm = false
		return
	}

	if c.inst.mod == 3 {
		if c.inst.d {
			c.registers[c.inst.reg] += c.registers[c.inst.rm]
			c.getFlags(c.registers[c.inst.reg])
		} else {
			c.registers[c.inst.rm] += c.registers[c.inst.reg]
			c.getFlags(c.registers[c.inst.rm])
		}
	}
}

func (c *cpu) sub() {
	if c.inst.imm {
		c.registers[c.inst.rm] -= c.inst.data
		c.getFlags(c.registers[c.inst.rm])
		c.inst.imm = false
		return
	}

	if c.inst.mod == 3 {
		if c.inst.d {
			c.registers[c.inst.reg] -= c.registers[c.inst.rm]
			c.getFlags(c.registers[c.inst.reg])
		} else {
			c.registers[c.inst.rm] -= c.registers[c.inst.reg]
			c.getFlags(c.registers[c.inst.rm])
		}
	}

}

func (c *cpu) cmp() {
	if c.inst.imm {
		result := c.registers[c.inst.rm] - c.inst.data
		c.getFlags(result)
		c.inst.imm = false
		return
	}

	if c.inst.mod == 3 {
		var result int16
		if c.inst.d {
			result = c.registers[c.inst.reg] - c.registers[c.inst.rm]
		} else {
			result = c.registers[c.inst.rm] - c.registers[c.inst.reg]
		}
		c.getFlags(result)
	}
}

func (c *cpu) jnz() bool {
	return !c.zeroFlag
}
