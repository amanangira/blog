---
title: "Go Concurrency 2.4 - Patterns and Idioms | Generators"
date: 2023-10-24T11:16:30+05:30
summary: "Generator pattern is an effective way to handle conversion of concrete slice/array types to a data stream in 
the for of channels. These become absolutely handy when you start working with sync primitives in Go. Using this pattern 
also helps in predictability and readability across application. "
categories:
  - Web Development
series:
  - 'Go Concurrency: Common Patterns'
tags:
  - Development
  - Go
  - Concurrency
  - Functional Programming
  - DRY Principles
---
Generators are functions that convert a set of values into a stream of values on a channel. Their primary purpose is to 
help work with channels and make programs composable. We are going to use some trivial examples to see how they might not 
seem like much at the beginning but soon become highly impactful.

Repeat generator
```Go 
package main  
  
import (  
   "fmt"  
   "time")  
  
func repeat(  
   value, n int)chan interface{}{  
   outputStream := make(chan interface{})  
   go func() {  
      defer close(outputStream)  
      for i := 0; i<n ; i++ {  
         outputStream <- value  
      }  
   }()  
  
   return outputStream  
}  
  
func repeatWithDone(  
   done chan interface{},  
   value ...interface{}) chan interface{}{  
   outputStream := make(chan interface{})  
   go func() {  
      defer close(outputStream)  
      for {  
         for _, item := range value{  
            select {  
               case <-done:  
                  return  
  
               case outputStream <- item:  
            }  
         }      }   }()  
  
   return outputStream  
}  
  
func main() {  
   // repeat  
   vanillaStream := repeat(5, 2)  
  
   fmt.Println("Vanilla repeat")  
   for elem := range vanillaStream {  
      fmt.Println(elem)  
   }  
  
   // repeatWithDone  
   done := make(chan interface{})  
   go func() {  
      defer close(done)  
      time.Sleep(time.Second * 3)  
   }()  
  
   numberStream := repeatWithDone(done, 1,2,3,4,5,6)  
   fmt.Println("repeatWithDone")  
   go func() {  
      for elem := range numberStream{  
         fmt.Println(elem)  
         time.Sleep(time.Second)  
      }  
   }()  
  
   <-done  
}
```
[Playground](https://go.dev/play/p/zlsz_v3hZjU)
- We provide discrete values to both the functions and get a channel in return that can be operated on under a 
separate Go routine.
- Notice the `interface{}` type?

Use of _interface return types is something that is often argued against in the Go community_ but the important thing 
here to understand that the use of interfaces actually aligns with the ability to make your program composable and be 
widely used in case of Pipelines.

Let's do a benchmark on type conversion to verify the performance impact of using interfaces with Generators.
```Go
package test  
  
import (  
   "testing"  
)  
  
func repeat(  
   value, n int) chan interface{} {  
   outputStream := make(chan interface{})  
   go func() {  
      defer close(outputStream)  
      for i := 0; i < n; i++ {  
         outputStream <- value  
      }  
   }()  
  
   return outputStream  
}  
  
func toInt(  
   valueStream chan interface{}) chan int {  
   outputStream := make(chan int)  
   go func() {  
      defer close(outputStream)  
      for elem := range valueStream {  
         // type casting  
         outputStream <- elem.(int)  
      }  
   }()  
  
   return outputStream  
}  
  
func BenchmarkRepeat(b *testing.B) {  
   // repeat  
   vanillaStream := repeat(5, b.N)  
  
   b.ResetTimer()  
   for _ = range vanillaStream {  
   }}  
  
func BenchmarkRepeatInt(b *testing.B) {  
   intStream := toInt(repeat(5, b.N))  
  
   b.ResetTimer()  
   for _ = range intStream {  
   }
}
```

```sh
cpu: Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
BenchmarkRepeat
BenchmarkRepeat-12       	 5436332	       221.5 ns/op
BenchmarkRepeatInt
BenchmarkRepeatInt-12    	 1548529	       791.5 ns/op
PASS
```

With this we conclude that the type cast specific stage are about 4x as fast as the one dealing with interface but only 
marginally faster in magnitude. Most of the time, things such as network lag, database lag, I/O, memory would eclipse 
this margin. And should be something that you revisit as part of optimisation not pre-optimisation.

#### Application
- Converting a slice of values to a stream/channel of values.
- Consider this pattern to be an extension of adapters, for converting one type to another in order to keep your program 
composable. 
