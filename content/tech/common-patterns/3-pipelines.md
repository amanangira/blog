---
title: "Go Concurrency 2.3 - Patterns and Idioms | Pipelines"
date: 2023-10-01T10:49:48+05:30
summary: "Pipeline design pattern is not limited to concurrency and is something that every programmer has followed or 
implemented, even if unknowingly. A pipeline could contain one or more stages, ideally limiting single responsibility to 
each stage. This allows different stages to be rearranged, to be added or removed."
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
#### Pipelines
Pipelines are a tool to abstract away logic that doesn't matter to immediate work in hand. It constitutes of primarily 
three parts, input, perform an operation, and output. Each such operation can be referred as a *stage*, and 
a pipeline can have more than one stage. Each stage is supposed to be isolated from the other, and therefore can be 
individually modified, leveraged, removed or be used to limit the rate of flow of data. Consider these a specific 
derivative of *functional programming*.

Two important attributes for a  pipeline stage
- The stage consumes and returns the same type.
- The stage should be reified i.e. developers can work directly with the types related to it.

##### Batch processing pipelines
Pipelines that accept and return batch of data.
```Go
package main

import (
	"fmt"
)

func multiply(numberStream []int, multiplier int) []int {
	result := make([]int, len(numberStream))
	for i, v := range numberStream {
		result[i] = v * multiplier
	}

	return result
}

func add(numberStream []int, additive int) []int {
	result := make([]int, len(numberStream))
	for i, v := range numberStream {
		result[i] = v + additive
	}

	return result
}

func main() {
	input := []int{1, 2, 3, 4, 5}

	for _, v := range add(multiply(input, 2), 1) {
		fmt.Println(v)
	}
}
```
[Playground](https://go.dev/play/p/Vo3_IL8JmSI) -
- The business logic has been kept simple to focus on the design pattern.
- This kind of processing is called as *batch processing*, since the processing happens in batch. It has it's own pros and cons.
- Notice how at every stage we have to create another slice of equal length to input slice. This means at any point of a stage, we will need double the memory.
- In this approach, the next stage starts only when all elements are done processing by the first stage.

##### Stream processing pipelines
Pipelines that receive and return one element at a time.
```Go 
package main

import (
	"fmt"
)

func multiply(input, multiplier int) int {
	return input * multiplier
}

func add(input, additive int) int {
	return input + additive
}

func main() {
	input := []int{1, 2, 3, 4, 5}

	for _, v := range input {
		fmt.Println(add(multiply(v, 2), 1))
	}
}
```
[Playground](https://go.dev/play/p/hjkAIjsliZM)
- Notice how each stage operates on a single element, removing the need of additional memory.
- In this approach as soon an element is processed by one stage, it enters the other.

##### Channels and pipelines
[Channels]({{< ref "../sync-package/3-channel-and-select" >}}) fit perfectly to be used along with pipeline design pattern. They allow read or write of values of same kind onto channels. This makes them highly composable following the DRY principle.  

