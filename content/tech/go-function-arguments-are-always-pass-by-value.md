---
title: "Go Function Arguments Are Always Pass by Value"
date: 2024-06-26T19:10:36+05:30
summary: This article demonstrates different ways in which pointers can be passed to functions as arguments and how they can affect the original variable or create new versions of the pointer. Each approach has its use cases and trade-offs depending on the specific requirements of a program.
slug: "go-function-arguments-are-always-pass-by-value"
categories:
  - Web Development
  - Go
tags:
  - Development
---
##### Introduction 
In this post, we will learn the difference and _caveats_ of passing arguments by pass by reference in Go. By the end of 
this article you should have a better understanding about the topic "pass by reference" with respect to function arguments, and you should also be 
able to identify this pattern being used in various SDKs and libraries. 

##### Let's Dive In

Check out the program below. Try to compute the output of the program before proceeding forward. 

[Go playground](https://go.dev/play/p/gbT-bzgi9yN)
```Go
package main

import "fmt"

func incrementByPointer(a *int) {
	var b int
	b = *a
	b++

	a = &b
}

func main() {
	value := 1
	a := &value

	// print initial value
	fmt.Println("[initial value of a]", *a)

	incrementByPointer(a)
	fmt.Println("[incrementByPointer]", *a)
}

```

Inspecting `incrementByPointer` function and analyse what it does step by step. 

1. `var b int`, we declare a new variable `b` of type int to temporarily store and update the value of incoming argument `a`. 
2. `b = *a`, we copy the _value_ being referenced by `a` to our locally scoped variable `b`. 
3. `b++`, we increment our locally scoped variable `b`. 
4. `a = &b`, this is probably the most interesting part. Remember the function argument is a pointer, a pointer holds a memory address of a certain type. 
So, in this statement we set the value of our incoming pointer argument `a` to hold the address of our locally scoped variable `b`.


The output of the program is going to be as below.
```text
[initial value of a] 1
[incrementByPointer] 1
```
Shouldn't our `incrementByPointer` reflect output as 2? _The Go spec highlights that all the function arguments are pass by value_. This means even the references are copy of the actual variables.
However, they would still point to the same address in the memory.

> the parameters of the call are passed by value to the function and the called function begins execution. The return parameters of the function are passed by value back
> to the caller when the function returns. [Source](https://go.dev/ref/spec#Calls)

With that in mind let's confirm that with two approaches. Let's write two new functions `incrementByPointerV2` and `incrementByPointerV3` that would follow and validate the spec.

[Go Playground](https://go.dev/play/p/d8950RmpuHS)
```Go
package main

import "fmt"

func incrementByPointer(a *int) {
	var b int
	b = *a
	b++

	a = &b
}

func incrementByPointerV2(a *int) *int {
	var b int
	b = *a
	b++

	a = &b

	return a
}

func incrementByPointerV3(a *int) {
	*a = *a + 1
}

func main() {
	value := 1
	a := &value

	// print initial value
	fmt.Println("[initial value of a]", *a)

	incrementByPointer(a)
	fmt.Println("[incrementByPointer]", *a)

	a = incrementByPointerV2(a)
	fmt.Println("[incrementByPointerV2]", *a)

	incrementByPointerV3(a)
	fmt.Println("[incrementByPointerV3]", *a)
}


```

Let's take a look at our `incrementByPointerV2` function and see step by step what it does.

1. Step 1-4 are as is as `incrementByPointerV2`.
2. The final thing that we do here is to return the pass by value pointer function argument `a` to update the pointer `a` scoped under the main block.

Let's take a look at our `incrementByPointerV3` function and see step by step what it does. 
1. In this function, we deal with the value that the pointer points to and hence are not required to return the updated pointer to update the value in the invoking scope. 

While both approaches yield about the same result at high level. There might be cases when you might want to use one over the other. Let's see them below. 

##### Approach One - `incrementByPointerV2`
Use case - query builders.

Pros 
- Provides flexibility to the invoking program to store the return result in the same or a different variable.
- Original argument is not modified providing flexibility to branch out different versions from a base pointer. 
- Allows method chaining based on the updated value.

Cons 
- Updated values need to be captured.


##### Approach Two - `incrementByPointerV3`
Use Case - SDK Clients. 

Pros 
- No overhead of capturing the updated result. 

Cons 
- Dev needs to self-manage any branching out from the same version of variable.


#### Conclusion 
With the above programs and examples, I hope to have helped you get a better understanding of how passing of references to function arguments works in Go. With two versions of our approach we also 
observed possible use cases along with their trade-offs. 