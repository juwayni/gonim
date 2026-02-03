package pkg1
import "fmt"
type Data struct {
	Value int
}
func (d *Data) Display() {
	fmt.Printf("Data value is %d\n", d.Value)
}
func Process(v int) *Data {
	return &Data{Value: v * 2}
}
