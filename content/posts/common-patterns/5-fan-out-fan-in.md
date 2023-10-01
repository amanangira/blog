---
title: "Go Concurrency 2.5 - Patterns and Idioms | Fan Out Fan In "
date: 2023-10-15T11:36:02+05:30
categories:
  - Web Development
series:
  - 'Go Concurrency: Common Patterns'
tags:
  - Development
  - Go
  - Concurrency
  - Functional Programming
---

So far we have discussed how Pipelines pattern can be leveraged to re-use and compose programs together. But what if I 
told you that we can leverage performance/speed gains by utilising Pipelines to process streams in parallel? Isn't that 
the general idea of concurrency? 
Let's do a simple program to find prime numbers and then let's compare it with its 
Fan Out Fan In equivalent.

I am going to use `testing` package in this case to benchmark performance and compare them later. 
Below benchmarks were executed on a 12 core CPU machine.
`prime_number_test.go`
```Go
package main  
  
import (  
   "fmt"  
   "math/rand"   
   "runtime"   
   "sync"   
   "testing"   
   )  
  
func randomStream(  
   done <-chan interface{},  
) <-chan interface{} {  
   resultStream := make(chan interface{})  
   go func() {  
      defer close(resultStream)  
      for {  
         select {  
         case <-done:  
            return  
         default:  
            r := rand.Intn(5000000)  
            //fmt.Printf("\n Sending random - %d ", r)  
            resultStream <- r  
         }  
      }  
   }()  
  
   return resultStream  
}  
  
func toIntStream(  
   done <-chan interface{},  
   stream <-chan interface{},  
) <-chan int {  
   intStream := make(chan int)  
   go func() {  
      defer close(intStream)  
  
      for v := range stream {  
         select {  
         case <-done:  
            return  
         default:  
            intStream <- v.(int)  
         }  
      }  
   }()  
  
   return intStream  
}  
  
func take(  
   done <-chan interface{},  
   valueStream <-chan int,  
   n int) <-chan int {  
   takeStream := make(chan int)  
   go func() {  
      defer close(takeStream)  
      for i := 0; i < n; i++ {  
         select {  
         case <-done:  
            return  
         case r := <-valueStream:  
            takeStream <- r  
         }  
      }  
   }()  
  
   return takeStream  
}  
  
func primeFinder(  
   done <-chan interface{},  
   inputStream <-chan int,  
) <-chan int {  
   outputStream := make(chan int)  
   go func() {  
      defer close(outputStream)  
      for {  
         select {  
         case <-done:  
         default:  
            subject := <-inputStream  
            if subject > 0 {  
               count := 0  
               for i := 1; i <= subject; i++ {  
                  if subject%i == 0 {  
                     count++  
                  }  
               }  
  
               if count == 2 {  
                  outputStream <- subject  
               }  
            }  
         }  
      }  
   }()  
  
   return outputStream  
}

func BenchmarkPrimeNumberWithVanilla(b *testing.B) {  
   done := make(chan interface{})  
  
   b.ResetTimer()
   now := time.Now()
   for _ = range take(done, primeFinder(done, toIntStream(done, randomStream(done))), 100){ 
   }  
   close(done)
   fmt.Println("Vanilla", time.Since(now).Seconds())
}


// BenchmarkPrimeNumberWithVanilla-12         	       1	26213399007 ns/op
```

Note - go playground doesn't seem to be yielding expected result for `time.Since` and was always yielding 0 as the 
result. Therefore, we do not have a go playground link for this topic. Now let's build the Fan Out Fan In version of the 
program we just wrote. Analysing our vanilla program, we see that we need to identify the stage to Fan Out and then Fan 
In. This stage needs to be order independent and should not be time costly. And if we look back at our program we 
realise that `primeFinder` is a perfect candidate qualifying these parameter.

For the first part, fanning out, is relatively an easier process. All we have to do is start multiple versions of our 
qualifying stage.

```Go 
cpuCount := runtime.NumCPU()  
done := make(chan interface{})  
pool := make([]<-chan int, cpuCount)  
randomIntStream := toIntStream(done, randomStream(done))    
for i := 0; i < runtime.NumCPU(); i++ {  
   pool[i] = primeFinder(done, randomIntStream)  
}
```

- I am running this program on a 12 core machine at the time of writing this post.
- I have 12 Go routines, pulling from the `randomStream`, followed by `toIntStream`, and finally `primeFinder`.
- Each Go routine will identify whether the random number is prime or not and will then move to the next number available in the stream/channel.
- Notice how we use different stages to compose our program together.

Great! Now we have concurrent Go routines working together to quickly yield prime numbers. However, we still need to 
merge these results together or Fan In.

```Go 
func fanIn(  
   done <-chan interface{},  
   channels ...<-chan int) <-chan int {  
   // 1.
   var wg sync.WaitGroup  
   fanInStream := make(chan int)  
   // 2. 
   multiplex := func(c <-chan int) {  
      defer wg.Done()  
      for i := range c {  
         select {  
         case <-done:  
            return  
         case fanInStream <- i:  
         }  
      }  
   }  
  
   wg.Add(len(channels))  
   for _, c := range channels {  
      // 3. 
      go multiplex(c)  
   }  
   // 4. 
   go func() {  
      wg.Wait()  
      close(fanInStream)  
   }()  
  
   return fanInStream  
}
```
1. We create `sync.WaitGroup` to wait until all channels have been drained.
2. We create `multiplex` function, which when provided with a channel will pass the value from the channel into the 
`fanInStream`
3. Here we fire one Go routine `multiplex` for each available channel from the Fan Out step.
4. We wait for all channels to drain and then close the output channel.

Let's pull all this together under a benchmark.

`fan_out_fan_in_test.go`
```Go
package main  
  
import (  
   "math/rand"  
   "sync"
   "testing"
   "time")  

func BenchmarkPrimeNumbersWithFanInFanOut(b *testing.B) {  
   cpuCount := runtime.NumCPU()  
   done := make(chan interface{})  
   pool := make([]<-chan int, cpuCount)  
   randomIntStream := toIntStream(done, randomStream(done))  
   b.ResetTimer()  
   now := time.Now()
   // Fan Out
   for i := 0; i < runtime.NumCPU(); i++ {  
      pool[i] = primeFinder(done, randomIntStream)  
   }  
   // Fan In
   for _ = range take(done, fanIn(done, pool...), 100) {  
   }  
   
   fmt.Println("Fan Out Fan In", time.Since(now).Seconds())
}
  
func fanIn(  
   done <-chan interface{},  
   channels ...<-chan int) <-chan int {  
   var wg sync.WaitGroup  
   fanInStream := make(chan int)  
  
   multiplex := func(c <-chan int) {  
      defer wg.Done()  
      for i := range c {  
         select {  
         case <-done:  
            return  
         case fanInStream <- i:  
         }  
      }  
   }  
  
   wg.Add(len(channels))  
   for _, c := range channels {  
      go multiplex(c)  
   }  
  
   go func() {  
      wg.Wait()  
      close(fanInStream)  
   }()  
  
   return fanInStream  
}  
  
func randomStream(  
   done <-chan interface{},  
) <-chan interface{} {  
   resultStream := make(chan interface{})  
   go func() {  
      defer close(resultStream)  
      for {  
         select {  
         case <-done:  
            return  
         default:  
            r := rand.Intn(5000000)  
            resultStream <- r  
         }  
      }  
   }()  
  
   return resultStream  
}  
  
func toIntStream(  
   done <-chan interface{},  
   stream <-chan interface{},  
) <-chan int {  
   intStream := make(chan int)  
   go func() {  
      defer close(intStream)  
  
      for v := range stream {  
         select {  
         case <-done:  
            return  
         default:  
            intStream <- v.(int)  
         }  
      }  
   }()  
  
   return intStream  
}  
  
func take(  
   done <-chan interface{},  
   valueStream <-chan int,  
   n int) <-chan int {  
   takeStream := make(chan int)  
   go func() {  
      defer close(takeStream)  
      for i := 0; i < n; i++ {  
         select {  
         case <-done:  
            return  
         case r := <-valueStream:  
            takeStream <- r  
         }  
      }  
   }()  
  
   return takeStream  
}  
  
func primeFinder(  
   done <-chan interface{},  
   inputStream <-chan int,  
) <-chan int {  
   outputStream := make(chan int)  
   go func() {  
      defer close(outputStream)  
      for {  
         select {  
         case <-done:  
         default:  
            subject := <-inputStream  
            if subject > 0 {  
               count := 0  
               for i := 1; i <= subject; i++ {  
                  if subject%i == 0 {  
                     count++  
                  }  
               }  
  
               if count == 2 {  
                  outputStream <- subject  
               }  
            }  
         }  
      }  
   }()  
  
   return outputStream  
}

// BenchmarkPrimeNumbersWithFanInFanOut-12    	       1	3455097777 ns/op
```

Comparing it with our vanilla implementation, the order of the `primeNumbers` being identified was not important. On the 
same lines, looking at the Fan Out and Fan In parts, you should notice that the order of the prime number being 
identified is not being maintained either. 

#### Conclusion
It's clearly visible that the Fan Out Fan In approach has drastically cut down our time. For 100 prime numbers the time 
came down to ~3seconds from ~26 seconds, ain't that a desirable performance gain?

```Table
BenchmarkPrimeNumberWithVanilla
Vanilla 26.915574551
BenchmarkPrimeNumberWithVanilla-12         	       1	26915617820 ns/op
BenchmarkPrimeNumbersWithFanInFanOut
Fan Out Fan In 3.35643029
BenchmarkPrimeNumbersWithFanInFanOut-12    	       1	3356471942 ns/op
```
