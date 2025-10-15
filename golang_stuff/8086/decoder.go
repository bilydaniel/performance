package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
)

// TODO do printing of instructions in one place, based on the instruciton struct
type decoder struct {
	instructions      []int
	instrPointer      int
	maxInstrPointer   int
	registers_w0      []string
	registers_w1      []string
	memory_registers  []string
	segments          [][]int
	instructionCycles int
	sumCycles         int
}

func newDecoder() *decoder {
	registers_w0 := []string{
		"al",
		"cl",
		"dl",
		"bl",
		"ah",
		"ch",
		"dh",
		"bh",
	}
	registers_w1 := []string{
		"ax",
		"cx",
		"dx",
		"bx",
		"sp",
		"bp",
		"si",
		"di",
	}
	memory_registers := []string{
		"bx + si",
		"bx + di",
		"bp + si",
		"bp + di",
		"si",
		"di",
		"bp",
		"bx",
	}
	segments := [][]int{
		{3, 6},
		{3, 7},
		{5, 6},
		{5, 7},
		{6},
		{7},
		{5},
		{3},
	}
	return &decoder{registers_w0: registers_w0, registers_w1: registers_w1, memory_registers: memory_registers, segments: segments}
}

func (d *decoder) setInstructions(instructions []int) {
	d.instructions = instructions
	d.instrPointer = 0
	d.maxInstrPointer = len(instructions) - 1
}

func (e *decoder) decodeSecondByte(w, d bool, c *cpu) string {
	resultInst := ""
	byte2 := e.loadByte()

	mod := byte2 & 0b11000000 >> 6
	reg := byte2 & 0b00111000 >> 3
	rm := byte2 & 0b00000111
	c.inst.mod = int8(mod)
	c.inst.reg = int8(reg)
	c.inst.rm = int8(rm)

	var regName, rmName string
	if mod == 0b11 {
		if w {
			regName = e.registers_w1[reg]
			rmName = e.registers_w1[rm]
		} else {
			regName = e.registers_w0[reg]
			rmName = e.registers_w0[rm]
		}

	}

	if mod == 0b00 {
		if rm == 0b110 {
			address := int16(e.load2Byte())
			c.inst.address = address
			rmName = "[" + strconv.Itoa(int(address)) + "]"
		} else {
			rmName = "[" + e.memory_registers[rm] + "]"

			segments := e.segments[rm]
			var address int16
			for _, segment := range segments {
				segmentValue := c.registers[int8(segment)]
				address += segmentValue
			}
			c.inst.address = address
		}
		if w {
			regName = e.registers_w1[reg]
		} else {
			regName = e.registers_w0[reg]
		}
	}

	if mod == 0b01 {
		data := e.loadByte()
		c.inst.data = int16(data)
		var dataString string
		if data == 0 {
			dataString = ""
		} else {
			dataString = "+" + strconv.Itoa(data)
		}
		rmName = "[" + e.memory_registers[rm] + dataString + "]"
		if w {
			regName = e.registers_w1[reg]
		} else {
			regName = e.registers_w0[reg]
		}

		segments := e.segments[rm]
		var address int16
		for _, segment := range segments {
			segmentValue := c.registers[int8(segment)]
			address += segmentValue
		}
		c.inst.address = address + int16(data)
	}
	if mod == 0b10 {
		data := e.load2Byte()
		c.inst.data = int16(data)
		var dataString string
		if data == 0 {
			dataString = ""
		} else {
			dataString = "+" + strconv.Itoa(data)
		}
		rmName = "[" + e.memory_registers[rm] + dataString + "]"
		if w {
			regName = e.registers_w1[reg]
		} else {
			regName = e.registers_w0[reg]
		}

		segments := e.segments[rm]
		var address int16
		for _, segment := range segments {
			segmentValue := c.registers[int8(segment)]
			address += segmentValue
		}
		c.inst.address = address + int16(data)
	}
	if d {
		resultInst += regName + ", " + rmName
	} else {
		resultInst += rmName + ", " + regName
	}
	return resultInst
}

func (e *decoder) getEA(c *cpu) int {
	cycles := 0

	if c.inst.mod == 0b11 {

	}

	if c.inst.mod == 0b00 {
		if c.inst.rm == 0b110 {
			cycles = 6
		} else {
			cycles = 5
		}
	}

	if c.inst.mod == 0b01 {
		if c.inst.data == 0 {
			cycles = 5
		}
	}
	if c.inst.mod == 0b10 {
		if c.inst.data != 0 {
			cycles = 9
		}
	}
	if c.inst.d {
	} else {
	}
	return cycles
}
func (e *decoder) getAddRMR(c *cpu) string {
	resultInst := "add "
	byte1 := e.loadByte()

	d := (byte1 & 0b00000010) != 0
	w := (byte1 & 0b00000001) != 0

	c.inst.d = d
	c.inst.w = w

	resultInst += e.decodeSecondByte(w, d, c)

	c.add()

	if c.inst.mod == 3 {
		e.instructionCycles = 3
	}
	if c.inst.mod == 0 {
		if d {
			e.instructionCycles = 8 + e.getEA(c)
		} else {
			e.instructionCycles = 9 + e.getEA(c)
		}
	}
	if c.inst.mod == 1 {
		e.instructionCycles = 16 + e.getEA(c)
	}
	if c.inst.mod == 2 {
		if d {
			e.instructionCycles = 16 + e.getEA(c)
		} else {
			e.instructionCycles = 16 + e.getEA(c)
		}
	}

	return resultInst
}
func (e *decoder) getSubRMR(c *cpu) string {
	resultInst := "sub "
	byte1 := e.loadByte()

	d := (byte1 & 0b00000010) != 0
	w := (byte1 & 0b00000001) != 0
	c.inst.d = d
	c.inst.w = w

	resultInst += e.decodeSecondByte(w, d, c)

	c.sub()

	return resultInst
}
func (e *decoder) getCmpRMR(c *cpu) string {
	resultInst := "cmp "
	byte1 := e.loadByte()

	d := (byte1 & 0b00000010) != 0
	w := (byte1 & 0b00000001) != 0

	resultInst += e.decodeSecondByte(w, d, c)
	c.cmp()

	return resultInst
}
func (e *decoder) getMovIR(c *cpu) string {
	resultInst := "mov "
	byte1 := e.loadByte()

	w := (byte1 & 0b00001000) != 0

	reg := byte1 & 0b00000111
	var regName string
	var data int
	if w {
		regName = e.registers_w1[reg]
		data = e.load2Byte()
	} else {
		regName = e.registers_w0[reg]
		data = e.loadByte()
	}
	resultInst += regName + ", " + strconv.Itoa(data)

	c.inst.d = true //implicit
	c.inst.w = w
	c.inst.reg = int8(reg)
	c.inst.data = int16(data)
	c.inst.imm = true
	c.mov()

	e.instructionCycles = 4

	return resultInst
}
func (e *decoder) getMovIM(c *cpu) string {
	resultInst := "mov "
	byte1 := e.loadByte()
	w := (byte1 & 0b00000001) != 0

	byte2 := e.loadByte()
	mod := (byte2 & 0b11000000) >> 6
	rm := byte2 & 0b00000111

	c.inst.w = w
	c.inst.mod = int8(mod)
	c.inst.rm = int8(rm)

	var rmName string
	if mod == 0b00 {
		//DIRECT ADDRESS
		if rm == 0b110 {
			byte3 := e.load2Byte()
			address := int16(byte3)
			c.inst.address = address

			rmName = "[" + strconv.Itoa(int(address)) + "]"
		} else {
			segments := e.segments[rm]

			var address int16
			for _, segment := range segments {
				segmentValue := c.registers[int8(segment)]
				address += segmentValue
			}
			c.inst.address = address
			rmName = "[" + e.memory_registers[rm] + "]"
		}

	}

	if mod == 0b01 {
		displ := int8(e.loadByte())
		segments := e.segments[rm]

		var address int16
		for _, segment := range segments {
			segmentValue := c.registers[int8(segment)]
			address += segmentValue
		}
		address += int16(displ)
		c.inst.address = address

		rmName = "[" + e.memory_registers[rm] + "+" + strconv.Itoa(int(displ)) + "]"

	}
	if mod == 0b10 {
		displ := int16(e.load2Byte())
		segments := e.segments[rm]

		var address int16
		for _, segment := range segments {
			segmentValue := c.registers[int8(segment)]
			address += segmentValue
		}
		address += int16(displ)
		c.inst.address = address

		rmName = "[" + e.memory_registers[rm] + "+" + strconv.Itoa(int(displ)) + "]"
	}

	var dataByte int
	if w {
		dataByte = e.load2Byte()
	} else {
		dataByte = e.loadByte()
	}
	c.inst.data = int16(dataByte)
	c.movIM()
	resultInst += rmName + ", " + strconv.Itoa(dataByte)

	return resultInst
}
func (e *decoder) getMovRMR(c *cpu) string {
	resultInst := "mov "
	byte1 := e.loadByte()

	d := (byte1 & 0b00000010) != 0
	w := (byte1 & 0b00000001) != 0

	resultInst += e.decodeSecondByte(w, d, c)

	c.inst.d = d
	c.inst.w = w
	c.mov()

	if c.inst.mod == 3 {
		e.instructionCycles = 2
	}
	if c.inst.mod == 0 {
		if d {
			e.instructionCycles = 8 + e.getEA(c)
		} else {
			e.instructionCycles = 9 + e.getEA(c)
		}
	}
	if c.inst.mod == 1 {
		e.instructionCycles = 8 + e.getEA(c)
	}
	if c.inst.mod == 2 {
		if d {
			e.instructionCycles = 8 + e.getEA(c)
		} else {
			e.instructionCycles = 9 + e.getEA(c)
		}
	}

	return resultInst
}

func (e *decoder) getArithmeticImm(c *cpu) string {
	resultInst := ""

	byte1 := e.loadByte()

	s := (byte1 & 0b00000010) != 0
	w := (byte1 & 0b00000001) != 0

	byte2 := e.loadByte()

	mod := byte2 & 0b11000000 >> 6
	op := byte2 & 0b00111000 >> 3
	rm := byte2 & 0b00000111

	var rmName string
	if mod == 0b11 {
		if w {
			rmName = e.registers_w1[rm]
		} else {
			rmName = e.registers_w0[rm]
		}
	}

	if mod == 0b00 {
		if rm == 0b110 {
			var disp int
			if w {
				disp = e.load2Byte()
			} else {
				disp = e.loadByte()
			}
			var dispString string
			dispString = "[" + strconv.Itoa(disp) + "]"
			rmName = dispString
		} else {
			rmName = "[" + e.memory_registers[rm] + "]"
		}

	}

	if mod == 0b01 {
		disp := e.loadByte()
		var dispString string
		if disp == 0 {
			dispString = ""
		} else {
			dispString = "+" + strconv.Itoa(disp)
		}
		rmName = "[" + e.memory_registers[rm] + dispString + "]"

	}
	if mod == 0b10 {
		disp := e.load2Byte()
		var dispString string
		if disp == 0 {
			dispString = ""
		} else {
			dispString = "+" + strconv.Itoa(disp)
		}
		rmName = "[" + e.memory_registers[rm] + dispString + "]"
	}

	var byte3 int
	if !s && w {
		byte3 = e.load2Byte()
	} else {
		byte3 = e.loadByte()
	}

	c.inst.w = w
	c.inst.mod = int8(mod)
	c.inst.rm = int8(rm)
	c.inst.data = int16(byte3)
	c.inst.imm = true

	if op == 0b000 {
		resultInst += "add "
		e.instructionCycles = 4
		c.add()
	} else if op == 0b101 {
		resultInst += "sub "
		c.sub()
	} else if op == 0b111 {
		resultInst += "cmp "
		c.cmp()
	}
	resultInst += rmName + ", " + strconv.Itoa(byte3)
	return resultInst
}

func (e *decoder) getAddImmToAx() string {
	result := "add "

	byte1 := e.loadByte()
	w := (byte1 & 0b00000001) != 0

	var byte2 int
	if w {
		result += "ax, "
		byte2 = e.load2Byte()
	} else {
		result += "al, "
		byte2 = e.loadByte()
	}
	result += strconv.Itoa(byte2)

	return result
}
func (e *decoder) getSubImmToAx() string {
	result := "sub "

	byte1 := e.loadByte()
	w := (byte1 & 0b00000001) != 0

	var byte2 int
	if w {
		result += "ax, "
		byte2 = e.load2Byte()
	} else {
		result += "al, "
		byte2 = e.loadByte()
	}
	result += strconv.Itoa(byte2)

	return result
}
func (e *decoder) getCmpImmToAx() string {
	result := "cmp "

	byte1 := e.loadByte()
	w := (byte1 & 0b00000001) != 0

	var byte2 int
	if w {
		result += "ax, "
		byte2 = e.load2Byte()
	} else {
		result += "al, "
		byte2 = e.loadByte()
	}
	result += strconv.Itoa(byte2)

	return result
}
func (e *decoder) getJNZ(c *cpu) string {
	result := "jnz "

	_ = e.loadByte()
	byte2 := e.loadByte()
	result += strconv.Itoa(byte2)

	cond := c.jnz()
	if cond {
		e.instrPointer += int(int8(byte2))
	}

	return result
}

func (e *decoder) getInstruction(c *cpu) (string, error) {
	resultInstruction := ""
	byte1 := e.getByte(0)
	debug := false

	if byte1 != 0 && debug {
		fmt.Printf("%08b\n", byte1)
		fmt.Printf("%08b\n", e.getByte(1))
		fmt.Printf("%08b\n", e.getByte(2))
	}

	//TODO simulate add sub cmp, AX versios not needed
	if byte1&0b11111100 == 0b10001000 {
		resultInstruction = e.getMovRMR(c)
	} else if byte1&0b11110000 == 0b10110000 {
		resultInstruction = e.getMovIR(c)
	} else if byte1&0b11111110 == 0b11000110 {
		resultInstruction = e.getMovIM(c)
	} else if byte1&0b11111100 == 0b00000000 {
		resultInstruction = e.getAddRMR(c)
	} else if byte1&0b11111100 == 0b00101000 {
		resultInstruction = e.getSubRMR(c)
	} else if byte1&0b11111100 == 0b00111000 {
		resultInstruction = e.getCmpRMR(c)
	} else if byte1&0b11111100 == 0b10000000 {
		resultInstruction = e.getArithmeticImm(c)
	} else if byte1&0b11111110 == 0b00000100 {
		resultInstruction = e.getAddImmToAx()
	} else if byte1&0b11111110 == 0b00101100 {
		resultInstruction = e.getSubImmToAx()
	} else if byte1&0b11111110 == 0b00111100 {
		resultInstruction = e.getCmpImmToAx()
	} else if byte1&0b11111111 == 0b01110101 {
		resultInstruction = e.getJNZ(c)
	} else if byte1&0b11111111 == 0b01110101 {
		//TODO je jl jle jb jbe jp jo js jne jnl jg jnb ja jnp jno jns loop loopz loopnz jcxz
		//resultInstruction = e.getJNZ()
	} else {
		return resultInstruction, errors.New(fmt.Sprintf("%08b\n", byte1))
	}
	return resultInstruction, nil
}

func (e *decoder) run(c *cpu) {
	printDecode := false
	printRegisters := false
	printCycles := true
	result := ""
	for e.instrPointer < e.maxInstrPointer {
		resultInst, err := e.getInstruction(c)
		if err != nil {
			fmt.Println(result)
			fmt.Println(err)
			fmt.Println("Unknown instruction")
			return
		}

		result += resultInst + "\n"
		e.sumCycles += e.instructionCycles
		if printCycles {
			fmt.Printf("C_C: %v, ", e.instructionCycles)
			fmt.Printf("C_S: %v \n", e.sumCycles)
			fmt.Printf("%+v \n", c.inst)
		}
		e.instructionCycles = 0
		if printRegisters {
			fmt.Printf("IP: %v\n", e.instrPointer)
			c.printRegisters()
			fmt.Println("================================")
		}

	}
	if printDecode {
		fmt.Println(result)
	}
	//c.printRegisters()
}

func (e *decoder) loadByte() int {
	byte := e.instructions[e.instrPointer]
	e.instrPointer++
	return byte
}

func (e *decoder) load2Byte() int {
	byte1 := e.instructions[e.instrPointer]
	e.instrPointer++
	byte2 := e.instructions[e.instrPointer]
	e.instrPointer++

	result := byte2<<8 | byte1
	return result
}

func (e *decoder) getByte(offset int) int {
	byte := e.instructions[e.instrPointer+offset]
	return byte
}

func getInstructionsFromArgs() ([]int, error) {

	args := os.Args

	if len(args) < 2 {
		return nil, errors.New("Probide a file so dissassemble")
	}

	fileName := args[1]

	_, err := os.Stat(fileName)
	if err != nil {
		return nil, errors.New("Wrong file")
	}

	file, err := os.Open(fileName)
	if err != nil {
		return nil, errors.New("Could not open file")
	}

	contents, err := io.ReadAll(file)
	if err != nil {
		return nil, errors.New("Could not read file")
	}

	instructions := []int{}
	for _, byte := range contents {
		//fmt.Printf("%08b\n", byte)
		instructions = append(instructions, int(byte))
	}
	return instructions, nil
}
