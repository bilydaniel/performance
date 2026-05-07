package helper

import (
	"math"
	"math/rand"
)

const File = "data2.json"
const EarthRadiusKm = 6371

type Pairs struct {
	Input []Pair `json:"pairs"`
}

func GenerateValue(maxVal float64, random *rand.Rand) float64 {
	signPicker := random.Intn(2)
	sign := 1
	if signPicker == 0 {
		sign = -1
	}
	return random.Float64() * maxVal * float64(sign)

}

func GenerateValueCenter(random *rand.Rand, center float64, maxVal float64) float64 {
	signPicker := random.Intn(2)
	sign := 1
	if signPicker == 0 {
		sign = -1
	}
	offset := random.Float64() * maxVal / 3 * float64(sign)
	result := center + offset
	if result > maxVal {
		return maxVal
	}
	if result < -maxVal {
		return -maxVal
	}
	return result
}

func NewRandomPair(random *rand.Rand) Pair {
	return Pair{
		GenerateValue(180, random),
		GenerateValue(90, random),
		GenerateValue(180, random),
		GenerateValue(90, random),
	}
}
func NewRandomPairCenter(random *rand.Rand, center Point) Pair {
	return Pair{
		GenerateValueCenter(random, center.X0, 180),
		GenerateValueCenter(random, center.Y0, 90),
		GenerateValueCenter(random, center.X0, 180),
		GenerateValueCenter(random, center.Y0, 90),
	}
}

type Pair struct {
	X0 float64 `json:"x0"`
	Y0 float64 `json:"y0"`
	X1 float64 `json:"x1"`
	Y1 float64 `json:"y1"`
}
type Point struct {
	X0 float64 `json:"x0"`
	Y0 float64 `json:"y0"`
}

func DgrToRad(dgr float64) float64 {
	return dgr * (math.Pi / 180)
}

func HaversineOfDegrees(x0, y0, x1, y1, r float64) float64 {
	dy := DgrToRad(y1 - y0)
	dx := DgrToRad(x1 - x0)
	y0 = DgrToRad(y0)
	y1 = DgrToRad(y1)

	rootTerm := (math.Pow(math.Sin(dy/2), 2)) + math.Cos(y0)*math.Cos(y1)*(math.Pow(math.Sin(dx/2), 2))
	result := 2 * r * math.Asin(math.Sqrt(rootTerm))
	return result
}
