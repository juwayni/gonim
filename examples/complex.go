package main

type Greeter interface {
	Greet() string
}

type Person struct {
	Name string
	Age  int
}

func (p Person) Greet() string {
	return "Hello, my name is " + p.Name
}

func main() {
	var g Greeter = Person{Name: "Jules", Age: 30}
	println(g.Greet())
}
