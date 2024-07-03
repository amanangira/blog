---
title: "Go Effective String Concatenation"
date: 2024-07-03T17:03:00+05:30
slug: "go-effective-string-concatenation"
draft: false
categories:
  - Web Development
tags:
  - string concatenation
  - golang
---

#### Introduction 
In this article we will see and compare two ways of string concatenation in Golang. We will compare there performances 
with benchmarking and will learn about the use cases of both the approaches.

#### Let's dive in
##### Approach 1, concatenation with + operator
String concatenation is one of the most commonly done operation in day to day development. And during a similar task I 
learnt about the performance impact of using widely used practice of string concatenation with the + operator. 

Let's write a simple benchmark implementing the concatenation with + operator.  

```Go
package content

import (
	"strconv"
	"testing"
)

// BenchmarkStringConcatenationByPlus - benchmarks the concatenation of t.N records by + operator
func BenchmarkStringConcatenationByPlus(t *testing.B) {
	var resultString string
	for i := 0; i < t.N; i++ {
		resultString += strconv.Itoa(i)
	}
}
```

The output of the program comes out to be `80066 ns/op` for `490260` iterations. That means it took `~40 seconds` for 
the program to complete its execution. 
Doesn't that feel little too much for a simple string concatenation operation?   

##### Approach 2, concatenation with strings.Builder

Let's take a look at another approach using `strings.Builder` type. That use a slice below the hood with exponential 
memory allocation strategy. 

```Go
package content

import (
	"fmt"
	"strconv"
	"strings"
	"testing"
)


// BenchmarkStringConcatenationByPlus - Approach 1, concatenation with + operator
func BenchmarkStringConcatenationByPlus(t *testing.B) {
	var resultString string
	for i := 0; i < t.N; i++ {
		resultString += strconv.Itoa(i)
	}
}

// BenchmarkStringConcatenationByBuilder - Approach 2, concatenation with strings.Builder
func BenchmarkStringConcatenationByBuilder(t *testing.B) {
	var buff strings.Builder
	buff.Grow(16)
	for i := 0; i < t.N; i++ {
		fmt.Fprintf(&buff, "%s", strconv.Itoa(i))
	}

	// we build the string in order to include its computation time in the benchmark
	buff.String()
}
```
In this case the output of the benchmark is 1000x faster with `17335111` at `67.64 ns/op`, giving the total execution 
time to mere `~1.17 seconds`.

##### Comparison
While the total execution time for the concatenation using the `strings.Builder` is +1000x more than the + alternative. It is important to under-stand the reasoning of it. Let's see a comparison between them.


| strings.Builder                                                                                                      | + Operator                                                                                               |
|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| 1. Uses an underlying []byte slice.                                                                                  | 1. Each concatenation generates a new string.                                                            |
| 2. Employs exponential memory allocation strategy, avoiding <br/>frequent memory allocation.                         | 2. Continuous memory reallocation.                                                                       |
| 3. Suitable for bulk operations.                                                                                     | 3. Suitable for simpler, where there are fewer and the iterations are known, keeping the program simple. |
| 4. Can be optimised further with helpers like `Grow()` or <br/>pre-allocated memory with []byte slice concatenation. |                                                                                                          |
|                                                                                                                      |                                                                                                          |

![Combined output of the benchmark](/static/tech/string-concatenation-benchmark.png)

#### Conclusion
In summary, the use of `strings.Builder` significantly outperforms traditional + operator-based string concatenation in Go. By leveraging this efficient function, developers can reduce memory allocation and improve performance when working with strings in bulk operations.
It's crucial to consider your use-case before employing any one of the strategy. 

 