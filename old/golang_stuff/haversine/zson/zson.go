package zson

import (
	"errors"
	"fmt"
	"os"
)

type Zson struct {
	file *os.File
}

func Unmarshal(file *os.File, output *interface{}) error {
	char := loadChar(file)
	fmt.Println(string(char))
	if *output == nil {
		*output = make(map[string]any)
	}
	data, ok := (*output).(map[string]any)
	if !ok {
		return errors.New("notOK")
	}
	data["x"] = 5

	return nil
}

func loadChar(file *os.File) []byte {
	b := []byte{0}
	n, err := file.Read(b)
	fmt.Println(n)
	fmt.Println(err)

	return b
}
