---
title: "Go Concurrency 2.1 - Patterns and Idioms | Fundamentals"
date: 2023-08-08T18:48:33+05:30
summary: "In this post we talk about some of the common patterns used in Go community that are going to prove handy 
when working with goroutines. The topics covered are Confinement, Infinite for loop with exit case, Loop with default 
case and Loop with Range and the default case pattern."
---
#### Confinement
If multiple goroutines are responsible for update in dedicate memory spaces then you don't have to worry about the safe operation. The main advantage of this would be to avoid the mental overhead of memory sharing or communicating over shared memory as well as side stepping the potential issues possible because of synchronisation.
Synchronisation comes with a cost.

```Go
package main

import (
	"fmt"
	"strings"
	"sync"
)

func main() {
	printStream := func(wg *sync.WaitGroup, items []int) {
		defer wg.Done()
		buffer := strings.Builder{}
		for _, v := range items {
			fmt.Fprintf(&buffer, "%d", v)
		}

		fmt.Println(buffer.String())
	}

	var wg sync.WaitGroup
	intSlice := []int{1, 2, 3, 4, 5}
	wg.Add(2)
	go printStream(&wg, intSlice[:2])
	go printStream(&wg, intSlice[2:])
	wg.Wait()
}

```
[Playground](https://go.dev/play/p/MCKm1mTRPsD)

Since both the goroutines are operating on different sub set of slices, these would to be said to be confined under their respective goroutines.

#### For-Select loop
This is probably going to be the most used pattern for you. It functions as an always true `for` loop statement with a `select` statement. Remember what `select` does from [[Go Concurrency#Go Concurrency - Sync Package - Part 3]]?

##### Infinite for loop with exit case
```Go
package main

import (
	"fmt"
	"time"
)

func main() {
	done := make(chan interface{})
	numberStream := make(chan interface{}, 2)

	// wouldn't block since buffered channel
	numberStream <- 1
	numberStream <- 2

	printStream := func(done, stream chan interface{}) {
		for {
			select {
			case <-done:
				return
			case v := <-stream:
				fmt.Println(v)
				time.Sleep(time.Second * 1)
			}
		}
	}

	go printStream(done, numberStream)
	go func() {
		time.Sleep(time.Second * 2)
		close(done)
	}()

	<-done
}

```
[Playground](https://go.dev/play/p/dvMvjeGiujB)

##### Loop with default case
```Go
printStream := func(done, stream chan interface{}) {  
   for {  
      select {  
      case <-done:  
         return  
      default:  
         v := <-stream  
         fmt.Println(v)  
         time.Sleep(time.Second * 1)  
      }  
   }}
```

##### Loop with Range and default case

```Go
printStream := func(done, stream chan interface{}) {  
   for v := range stream {  
      select {  
      case <-done:  
         return  
      default:  
         fmt.Println(v)  
         time.Sleep(time.Second * 1)  
      }  
   }}
```


Additionally in the above examples you would notice the `done` channelGoroutines are not garbage collected by the runtime, so regardless of their small footprint, we don't want to leave them dangling.
For this, one of the very common pattern is to pass an additional channel to signal termination of work.

#### Important rules when dealing with goroutines
- The channel owner should
    - Instantiate the channel.
    - Perform writes, or pass the ownership to another goroutines.
    - Close the channel.
- Passing a signal channel to indicate termination from parent to the child goroutine. 