---
title: "Go Concurrency 2.2 - Patterns and Idioms | Error handling"
date: 2023-09-18T18:08:12+05:30
summary: "In this post we see how to check for errors on responses being read from a channel and let the goroutine with the right information decide how to handle the error."
categories:
  - Web Development
series:
  - 'Go Concurrency: Patterns and Idioms'
tags:
  - Development
  - Go
  - Concurrency
---


With [Go Concurrency - Common patterns | Fundamentals](https://www.amanreasoned.com/tech/common-patterns/1-fundamentals/), we learnt some basic, composable and idiomatic patterns that can be combined
to solve different problems. In this blog, we are going to see how these common patterns can quickly begin to fit together and help us solve error handling when working with goroutines.

#### Error Handling
Similar to how concurrent programs require different approach for their design and implementation, similarly error handling requires patterns different from synchronous programming as well. 
To better understand this problem, let's see a simple program that calculates if a number is mod of two or not.

```Go
package main

import (
	"fmt"
	"time"
)

func main() {
	// 1.
	done := make(chan interface{})
	inputStream := make(chan interface{})
	go func() {
		time.Sleep(time.Second * 6)
		close(done)
	}()

	go seedNumbers(done, inputStream)
	go modTwo(done, inputStream)

	<-done
}

func seedNumbers(done <-chan interface{}, inputStream chan<- interface{}){
	// 2.
	stream := []interface{}{"abc", 1, "2", 3, 4}
	go func() {
		for v := range stream{
			select {
			case <-done:
				return
			default:
				inputStream <- v
			}
		}
	}()
}

func modTwo(done, inputStream <-chan interface{}){
	go func() {
		for {
			select {
				case <-done:
					return
				case  v := <-inputStream:
					intV, ok := v.(int)
					// 3.
					if !ok {
						fmt.Printf("\n seeded value not of type int: %+v", v)
						continue
					}
					if intV == 0 {
						fmt.Println("seeded value is zero: cannot mod with zero")
						continue
					}

					// 4.
					if intV % 2 == 0{
						fmt.Printf("\n %d is divisible by two", v)
					}else{
						fmt.Printf("\n %d is not divisible by two", v)
					}
			}
			time.Sleep(time.Second)
		}
	}()
}
```
The program - [Playground](https://go.dev/play/p/MstMH141GfK)
1. We use the pattern we learnt in [Go Concurrency 1.3 - Sync Package | Channels & Select](https://www.amanreasoned.com/tech/sync-package/3-channel-and-select/) to create a done channel to indicate
termination of our program to our child go routines. Also, we add a 6 seconds sleep before we call `close()` on this channel to indicate termination of child go routines.
2. We define `seedNumbers()` to seed numbers into the provided channel of interface. Notice how we initialise it with two values that would result in error on invoking `modTwo()` on them. We leverage 
the patterns we learnt in [Go Concurrency 2.1 - Patterns and Idioms | Fundamentals](https://www.amanreasoned.com/tech/common-patterns/1-fundamentals/) for working with channels.
3. In this function `modTwo()`, we have two if blocks checking for errors and printing the error to the `stdout`.
4. If we receive a valid divisible value, we proceed to check and print if that is divisible by two. 

Simple enough? Some questions to ask yourselves keeping this program in mind. 
1. What happens if I want to capture the invalid input streams and handle them separately? 
2. How does the main goroutine know if it should terminate or do something about an error?
3. How do we get rid of the `done` and `close(done)` approach and guarantee an iteration equal to the number of inputs?

Let's see the below refactored program.

```Go
package main

import (
	"fmt"
	"time"
)

type Result struct {
	Input          interface{}
	DivisibleByTwo bool
	Error          error
}

func main() {
	// 1.
	outputStream := make(chan Result)
	inputStream := make(chan interface{})
	defer close(inputStream)
	defer close(outputStream)

	// 2.
	stream := []interface{}{"abc", 1, 0, 3, 4}

	go seedNumbers(stream, inputStream)
	go modTwo(inputStream, outputStream)

	for i:=0; i < len(stream); i++ {
		r := <- outputStream
		// 5. 
		if r.Error != nil{
			fmt.Printf("\n input : %+v, err - %s", r.Input, r.Error)
		}else{
			fmt.Printf("\n %d is divisible by two: %t", r.Input.(int), r.DivisibleByTwo)
		}
	}
}

func seedNumbers(rawStream []interface{}, inputStream chan<- interface{}) {
	go func() {
		for _, v := range rawStream {
			// 3.
			inputStream <- v
			time.Sleep(time.Second)
		}
	}()
}

func modTwo(inputStream <-chan interface{}, outputStream chan<- Result) {
	go func() {
		for v := range inputStream {
			// 4.
			r := Result{Input: v}
			intV, ok := v.(int)
			if !ok {
				r.Error = fmt.Errorf("seeded value not of type int: %+v", v)
				outputStream <- r
				continue
			}
			if intV == 0 {
				r.Error = fmt.Errorf("seeded value is zero: cannot mod with zero")
				outputStream <- r

				continue
			}

			if intV%2 == 0 {
				r.DivisibleByTwo = true
			}

			outputStream <- r
		}
	}()
}
```
[Playground](https://go.dev/play/p/-G8XJZhMhGE)
1. We create two channels, one to seed input values by `seedNumbers()` and the other to read and write the output of 
`modTwo()`. Additionally, we defer `close()` so that the range statement can know that the channel has been closed and 
doesn't wait for further read or writes.
2. We define slice of interface, with values that could cause error in our `modTwo()` function. 
3. We range on `rawStream` and write those values into `inputStream` to allow `modTwo()` to read and validate values from it. We add wait time to observe program pause as the goroutines halt.
4. We wrap our `outputStream` in a type that helps us relay the required values to the goroutine responsible for handling the output or with the information to handle the output i.e. `main()` goroutine.
5. We range of `outputStream`, and our `main()` goroutine decides what to do with the response and prints the respective message. 


#### Conclusion
Coupling of potential result with potential errors when working with goroutines helps us separate our concerns of error handling from our worker goroutines. This in turn makes our program composable, 
and enables the programmer to debug potential issues easily. 
 