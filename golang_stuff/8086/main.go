package main

import (
	"fmt"
)

func main() {
	instructions, err := getInstructionsFromArgs()
	if err != nil {
		fmt.Println(err)
		return
	}
	decoder := newDecoder()
	decoder.setInstructions(instructions)
	cpu := newCpu()
	decoder.run(&cpu)
}
