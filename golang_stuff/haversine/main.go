package main

import (
	"designPatterns/performance/haversine/helper"
	"designPatterns/performance/haversine/zson"
	"fmt"
	"os"
)

func main() {
	jsonFile, err := os.Open("gen/" + helper.File)
	if err != nil {
		fmt.Println(err)
		return
	}

	//startTime := time.Now()
	var jsonInput interface{}
	err = zson.Unmarshal(jsonFile, &jsonInput)
	fmt.Println("OUTPUT:")
	fmt.Println(jsonInput)

	/*

		//err = json.NewDecoder(jsonFile).Decode(&jsonInput)
		err = json.Unmarshal([]byte(jsonByte), &jsonInput)
		if err != nil {
			fmt.Printf("error: %v\n", err)
			return
		}
		fmt.Println("B")
		fmt.Println(jsonInput)
		fmt.Println("TEST parsing")
		data, ok := jsonInput.(map[string]interface{})
		if !ok {
			fmt.Printf("error: %v\n", data)
			return
		}

		fmt.Println(data["pairs"].([]interface{})[0].(map[string]interface{})["x0"])
	*/

	/*
		midTime := time.Now()

		sum := 0
		count := 0

			for _, pair := range jsonInput.Input {
				sum += int(helper.HaversineOfDegrees(pair.X0, pair.Y0, pair.X1, pair.Y1, float64(helper.EarthRadiusKm)))
				count += 1
			}
			average := sum / count
			endTime := time.Now()

			fmt.Printf("Result: %v \n", average)
			fmt.Printf("Input: %v \n", midTime.Sub(startTime))
			fmt.Printf("Math: %v \n", endTime.Sub(midTime))
			fmt.Printf("Total: %v \n", endTime.Sub(startTime))
			fmt.Printf("Throughput: %v \n", (float64(count) / (endTime.Sub(startTime).Seconds())))
			fmt.Println(count)
	*/

}
