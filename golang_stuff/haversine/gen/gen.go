package main

import (
	"designPatterns/performance/haversine/helper"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"
)

/*
	generate json

{
"pairs": [
{"x0": 3, "y0": 6}
]
}

however many, write down what is the sum, results for each pair

uniform/cluster random seed pairs
*/
func writeHeader(file *os.File) {
	file.WriteString("{\n\"pairs\": [\n")
}

func writeFooter(file *os.File) {
	file.WriteString("]\n}")
}

func newCenter(random *rand.Rand) helper.Point {
	return helper.Point{
		X0: helper.GenerateValue(180, random),
		Y0: helper.GenerateValue(90, random),
	}
}

func main() {
	uniform := flag.Bool("uniform", false, "0-cluster, 1-uniform")
	seed := flag.Int64("seed", time.Now().UnixNano(), "")
	pairs := *flag.Int("pairs", 10, "")
	batchSize := *flag.Int("batch", 10, "")
	clusterSize := *flag.Int("cluster", 10, "")

	source := rand.NewSource(*seed)
	random := rand.New(source)

	jsonFile, err := os.Create(helper.File)
	if err != nil {
		log.Println("Could not open file")
		return
	}
	defer jsonFile.Close()

	writeHeader(jsonFile)

	var haversineSum float64
	var center helper.Point
	batch := strings.Builder{}
	for i := 0; i < pairs; i++ {
		var data helper.Pair
		if *uniform {
			data = helper.NewRandomPair(random)
		} else {
			data = helper.NewRandomPairCenter(random, center)
		}
		haversine := helper.HaversineOfDegrees(data.X0, data.Y0, data.X1, data.X1, helper.EarthRadiusKm)
		haversineSum += haversine

		jsonData, err := json.Marshal(data)
		if err != nil {
			log.Println("Could not marshal")
			return
		}
		if i == pairs-1 {
			batch.WriteString("\t\t" + string(jsonData) + "\n")
		} else {
			batch.WriteString("\t\t" + string(jsonData) + ",\n")
		}
		if batch.Len() >= batchSize {
			jsonFile.WriteString(batch.String())
			batch.Reset()
		}
		if i%clusterSize == 0 {
			center = newCenter(random)
		}
	}
	haversineAvg := haversineSum / float64(pairs)
	fmt.Println(haversineAvg)
	writeFooter(jsonFile)
}
