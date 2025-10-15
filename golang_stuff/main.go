package main

import (
	"fmt"
	"unsafe"
)

func performadd(a, b int) int {
	return a + b
}

type book struct {
	title  string
	author string
	pages  int
}

func main() {

	x := performadd(1234, 5678)
	fmt.Println(x)

	slice := []int64{1, 2, 3, 4, 5, 6, 7}
	fmt.Println(len(slice), cap(slice))
	slice2 := [100]int8{1}
	fmt.Println(unsafe.Sizeof(slice2))

	a := 2
	fmt.Println(unsafe.Sizeof(a))

	book1 := book{
		title:  "asd",
		author: "qwe",
		pages:  123,
	}
	book2 := book{
		title:  "asd",
		author: "qwe",
		pages:  123,
	}

	books := []book{book1, book2}

	fmt.Println(unsafe.Sizeof(book1))
	fmt.Println(unsafe.Sizeof(books))
}
