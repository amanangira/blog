---
title: "Go Concurrency 2.2 - Patterns and Idioms | Error handling"
date: 2023-09-18T18:08:12+05:30
summary: "In this post we see how to check for errors on responses being read from a channel and let the goroutine with the right information decide how to handle the error."
---
#### Error Handling
The rule of thumb is to relay the error to the goroutine that has the right information on what to do about it. In most of the cases, this is going to be your `main` (parent) goroutine. One common way of streamlining the errors and handling them is to wrap them in a certain type.

```Go
package main

import (
	"fmt"
)

type outputType struct {
	input  int
	err    error
	modTwo bool
}

func main() {
	modTwo := func(done, inputStream <-chan interface{}, outputStream chan<- outputType) {
		for {
			select {
			case <-done:
				return
			case v := <-inputStream:
				i := v.(int)
				var divisibility bool
				if i < 1 {
					outputStream <- outputType{
						input:  i,
						err:    fmt.Errorf("negative numbers not allowed"),
						modTwo: false,
					}
					break
				}

				if i%2 == 0 {
					divisibility = true
				}

				outputStream <- outputType{
					input:  i,
					err:    nil,
					modTwo: divisibility,
				}
			}
		}
	}

	writeInputStream := func(done, writeTo chan interface{}) {
		testData := []int{2, -1, 4}

		for _, v := range testData {
			select {
			case <-done:
				return
			case writeTo <- v:
			}
		}
	}

	done := make(chan interface{})
	inputStream := make(chan interface{})
	outputStream := make(chan outputType)
	go writeInputStream(done, inputStream)
	go modTwo(done, inputStream, outputStream)

	for result := range outputStream {
		if result.err != nil {
			fmt.Printf("\n Input number - %d | Moddable by two : %t | Err - %s", result.input, result.modTwo, result.err)
			close(inputStream)
			close(outputStream)
			close(done)
		} else {
			fmt.Printf("\n Input number - %d | Moddable by two : %t ", result.input, result.modTwo)
		}
	}

}

```
[Playground](https://go.dev/play/p/RgYjHm1lBUn)

- We create a new wrapper type `outputType` to wrap our error and result.
- We update our channel type to be of type `outputType`. 
- We leverage `outputType` fields to check for errors.