---
title: "Go Concurrency 1.1 - Sync Package | WaitGroup & Mutex"
slug: "sync-package-waitgroup-and-mutex"
date: 2023-07-17T19:44:05+05:30
summary: "Memory access synchronisation is one of the popular ways to achieve concurrency in various languages. `Sync` package is one of the major difference between these languages and Go. The package provides you new set of concurrency primitives with wide abilities on top of the memory access synchronisation primitives. I am going to briefly talk about some commonly used tools from this package."
categories:
  - Web Development
series:
  - 'Go Concurrency: Sync Package'
tags:
  - Development
  - Go
  - Concurrency 
---
![Cover Image]()

Memory access synchronisation is one of the popular ways to achieve concurrency in various languages. `Sync` package is one of the major difference between other languages and Go. The package provides you new set of concurrency primitives with wide abilities on top of the memory access synchronisation primitives. I am going to briefly talk about some commonly used tools from this package.
#### WaitGroup
It is an excellent abstraction to wait for a set of goroutines when you either don't care about the result or have other ways to collect the result
```Go
package main  
  
import (  
   "fmt"  
   "sync"   
   "time")  
  
func main() {  
   maxConcurrency := 2  
   var wg sync.WaitGroup  
   for i := 0; i < maxConcurrency; i++{  
      wg.Add(1)  
      go func(wg *sync.WaitGroup, i int) {  
         defer wg.Done()  
         fmt.Printf("\n goroutine %d going to sleep", i)  
         time.Sleep(time.Second * 1)  
      }(&wg, i)  
   }  
  
   wg.Wait()  
   fmt.Printf("\nAll goroutines complete.")  
}
```

[Go Playground](https://go.dev/play/p/PHY10Dbx4n9)

##### Application
To fire up multiple goroutines and wait for them to complete before moving forward.
- Firing of multiple queries part of a common result that needs to be returned.
- Firing of multiple HTTP request and waiting for them to complete.

#### Mutex
This tool helps guard a critical section in your program. A critical section is nothing but a part of your program that could be sharing access to a memory with another part of the program at the same time. Mutex stands for _mutual exclusion_. It a way to provide concurrent safe access to a shared resource.

```Go  
package main  
  
import (  
   "fmt"  
   "sync")  
  
func main() {  
   var counter int  
   increment := func(wg *sync.WaitGroup, m sync.Locker) {  
      defer wg.Done()  
         m.Lock()  
         defer m.Unlock()  
         counter++  
         fmt.Printf("\nPost increment count %d", counter)  
   }  
  
   decrement := func(wg *sync.WaitGroup, m sync.Locker) {  
      defer wg.Done()  
         m.Lock()  
         defer m.Unlock()  
         counter--  
         fmt.Printf("\nPost decrement count %d", counter)  
   }  
  
   iterations := 5  
   var lock sync.Mutex  
   var wg sync.WaitGroup  
   for i:=0; i < iterations; i++{  
      wg.Add(1)  
      go increment(&wg, &lock)  
   }  
  
   for i:=0; i < iterations; i++{  
      wg.Add(1)  
      go decrement(&wg, &lock)  
   }  
   wg.Wait()  
   fmt.Println("\nOperation complete")  
}
```

[Go Playground](https://go.dev/play/p/4ULKz0YJ00p)

##### Application
Any resource that is being modified/accessed by multiple goroutines.
- Appending errors from multiple queries together from a set of goroutines part of the current scope.
- Appending results together from a set of goroutines performing HTTP requests.  
