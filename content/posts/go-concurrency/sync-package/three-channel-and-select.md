---
title: "Go Concurrency 1.3 - Sync Package | Channels & Select"
date: 2023-08-01T19:44:05+05:30
draft: true
summary: "In this post I talk about the type `Channels` and `Select` available under the sync package. While 
`Channels` can be used for both communication between concurrent processes, they can also be used in synchronisation by 
sharing the memory address. `Select` allows you to pseudo-randomly resolve one of the available/ready case."
gh_comment_id: 3
---

### Go Concurrency 1.3 - Sync Package | Channels & Select
#### Channels
While these can be used to synchronise memory access, they are best used to communicate information between go routines. One of the main advantage that channels offer is composition. Different parts of your program don't have to require the information about each other, only a reference to a channel can be used to pass information around.
Channels can be declared only for unidirectional data flow support as well i.e. a channel that could only receive or send data.

```Go
package main

import (
	"fmt"
	"time"
)

func main() {
    //1.
 	var primeNumberStream chan int
	primeNumberStream = make(chan int)

    //2. 
	go func(stream chan<- int) {
		//3.
		defer close(stream)
		time.Sleep(time.Second)
		//4.
		primeNumberStream <- 2
	}(primeNumberStream)

    //5.
	fmt.Println(<-primeNumberStream)
}

```

[Playground](https://go.dev/play/p/IZxsRxaO46P)
1. We declare a channel of type `int`. Can merge declaration and instantiation in a single line as well using the `:=`  operator along with `make` keyword.
2. Declare unidirectional channel i.e a channel that receives data. Most of the time you won't see unidirectional channels in directional but instead in function argument or return types, i.e because Go implicitly converts the passed in channel.
3. Channel is closed in a deferred state before use. This is a common idiom. Note closing a channel signals all Go routines listening to it.
4. Sending data into a channel.
5. Reading from channel. Note - this is a blocking statement and would remain blocked unless the channel being read from receives a value.

Remember, writes to a channel block if the channel is full and reads on a channel block if the channel is empty.

Interesting fact - it has been directly derived from Hoare's CSP. Hoare is one of the turing award winner who is known for his many findings in computer programming along with the quick sort algorithm


#### Buffered Channels
Buffered channels are channels that are instantiated with a capacity. It means that a buffered channel of capacity 4 can have done 4 writes before reading anything from it. An unbuffered channel has capacity of 0, so it's already full before any writes.

```Go
package main

func main() {
	//1.
	var primeNumberStream chan int
	primeNumberStream = make(chan int, 4)

	//2.
	for i := 0; i < 4; i++ {
		primeNumberStream <- i
	}

}

```
[Playground](https://go.dev/play/p/QmjdeLTT7W6)
1. Instantiating a channel of capacity 4.
2. Sending 4 elements to the channel without reading any.

##### Application
- Composing together program snippets.
- Passing data between different Go routines.


#### Select
The select statement binds together channels. They bring the abilities like cancellations, timeouts, waiting and default values when working with channels. Select statement syntax is similar to that of switch case statements however the cases aren't executed sequentially in case of select statement. Instead all channel reads and writes are considered simultaneously and the one ready is executed. If more than one are ready at a time than the compiler pseudo randomly picks one from the ready cases.

```Go
package main

import (
	"fmt"
	"time"
)

func main() {
	start := time.Now()
	c := make(chan interface{})
	d := make(chan interface{})

	block := func(ch chan interface{}) {
		time.Sleep(2 * time.Second)
		close(ch)
	}

	go block(c)
	go block(d)

	fmt.Println("Blocking on read")

	select {
	case <-c:
		fmt.Printf("\nc Unblocked %f later.\n", time.Since(start).Seconds())
	case <-d:
		fmt.Printf("\nd Unblocked %f later.\n", time.Since(start).Seconds())
	}

}

```
[Playground](https://go.dev/play/p/E3Dy1GvKO_u)
In the above program, within few executions you will either of c or d being picked up. Try tweaking with the time of one and see what happens?


Another example, using channels to signal termination of Go routine.
```Go
package main

import (
	"fmt"
	"time"
)

func main() {
	startFrom := 5000000
	primeNumberStream := make(chan int)

	primeCalculator := func(startFrom int, primeNumberStream chan<- int) {
		for i := startFrom; i > 0; i-- {
			var factorCount int
			for j := i; j > 0; j-- {
				if i%j == 0 {
					factorCount++
				}
			}

			if factorCount == 2 {
				primeNumberStream <- i
			}
		}
	}

	primeReader := func(done <-chan int, primeNumberStream <-chan int) {
		for {
			select {
			case <-done:
				return
			case v := <-primeNumberStream:
				fmt.Println(v)
			}
		}
	}

	done := make(chan int)
	go primeCalculator(startFrom, primeNumberStream)
	go primeReader(done, primeNumberStream)
	go func() {
		time.Sleep(time.Second * 2)
		close(done)
	}()
	<-done
}

```
[Playground](https://go.dev/play/p/M94KV15I2p_o)

1. I have instantiated a high starting point to start calculating prime number.
2. I have setup a very brute technique of finding whether the provided number is prime number.
3. I have setup a reader to read from `primeNumerStream` and print and until signalled otherwise.
4. I have used the `done` channel to wait for the Go routines to finish.

##### Application
- Composing together channel streams.
- Composing together timeouts. See `time.After` and `context.WithTimeout` function.
- Composing signals from other channels together. See `context.WithCancel`.


#### Sync Package Conclusion
We have covered two ways of synchronisation, by memory access synchronisation using the primitives in the `sync` package and by sharing memory by communicating using channels and select. Play around with the snippets, put together your own programs using these to establish a good understanding of the basic concepts.
Moving forward I am going to discuss some of the idiomatic and common patterns used with these primitives to put together a readable, performant and logically correct programs. 