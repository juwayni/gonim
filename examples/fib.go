package main

// We assume println is a builtin for this prototype
func fib(n int) int {
	if n <= 1 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	res := fib(10)
    println(res)
}
