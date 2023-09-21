---
title: "Go Concurrency 1.2 - Sync Package | Once & Pool"
date: 2023-07-24T19:44:05+05:30
summary: "Continuing the sync package series, in this post I talk about the type `sync.Once` and `sync.Pool` available 
under the sync package. While `sync.Once` offers a `once.Do(func() {})` signature that is perfect for initialising most 
of the clients in your application. While `sync.Pool{New: func() interface{}}`, lets you do things like warming up, 
managing and creation of pool of resources."
categories:
  - Web Development
series:
  - 'Go Concurrency: Sync Package'
tags:
  - Development
  - Go
  - Concurrency
---
### Go Concurrency 1.2 - Sync Package | Once & Pool
#### Once
It is a type that internally utilises the sync primitives to ensure that only one call happens to the passed in function. 

Note - it does not care about the unique functions passed in, and only cares about the invocation on the `sync.Once.Do(f func())` method.

```Go 
package main

import (
	"fmt"
	"sync"
)

func main() {
	var counter int
	var once sync.Once

	for i := 0; i < 10; i++ {
		once.Do(func() {
			counter++
		})
		
	}

	fmt.Println(counter)
}

```
[Playground](https://go.dev/play/p/tsoGU1sXgwE)

##### Application
- Any kind of initialisation logic, various clients like - DB clients, loggers etc

#### Pool
It is a type that allow concurrent safe way to create and re-use objects that could be costly to create or are being used by processes that dispose of these objects rapidly. The type has two main methods `Get` and `Put`. When the `Get` is called first it checks if there are any available instances in the pool else it calls the `New` member variable to issue a new one, once the resource has been used it can be freed up and be allocated back to the pool using the `Put` method.

```Go
package main  
  
import (  
   "fmt"  
   "sync")  
  
var instanceCount int  
  
func warmUpPool(p *sync.Pool, resourceCount int) {  
   for i := 0; i < resourceCount; i++ {  
      p.Put(p.New())  
   }  
}  
  
func main() {  
   p := sync.Pool{  
      New: func() interface{} {  
         fmt.Println("Creating new resource")  
         instanceCount++  
         s := make([]byte, 1024)  
  
         return s  
      },  
   }  
  
   warmUpPool(&p, 4)  
   var wg sync.WaitGroup  
   for i := 0; i < 100; i++ {  
      wg.Add(1)  
      go func() {  
         defer wg.Done()  
         resource := p.Get()  
         p.Put(resource)  
      }()  
   }  
  
   wg.Wait()  
   fmt.Println(instanceCount)  
}
```
[Playground](https://go.dev/play/p/z3JN9aL2-MO)

#### Application
- Database pool to be leveraged by multiple workers at a time.
- Cache to be utilised by multiple workers. 