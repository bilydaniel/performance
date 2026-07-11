package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

EARTH_RADIUS :: 6372.8 // KM

Point :: struct {
	x: f64,
	y: f64,
}

Arguments :: struct {
	uniform:         bool,
	seed:            u64,
	number_of_pairs: int,
	cluster_size:    int,
}

random_in_range :: proc(min, max: f64) -> f64 {
	value := rand.float64()
	return min + (value * (max - min))
}

generate_value_center :: proc(center, radius, max_val: f64) -> f64 {
	min_val := -max_val

	min_value := center - radius
	if min_value < min_val {
		min_value = min_val
	}

	max_value := center + radius
	if max_value > max_val {
		max_value = max_val
	}

	result := random_in_range(min_val, max_val)
	return result
}

haversine :: proc(x0, y0, x1, y1, radius: f64) -> f64 {
	dy := dgr_to_rad(y1 - y0)
	dx := dgr_to_rad(x1 - x0)
	y0_rad := dgr_to_rad(y0)
	y1_rad := dgr_to_rad(y1)

	root_term :=
		(math.sin(dy / 2) * math.sin(dy / 2)) +
		math.cos(y0_rad) * math.cos(y1_rad) * (math.sin(dx / 2) * math.sin(dx / 2))
	result := 2 * radius * math.asin(math.sqrt(root_term))
	return result
}

dgr_to_rad :: proc(dgr: f64) -> f64 {
	return dgr * (math.PI / 180.0)
}

parse_args :: proc(args: []string) -> (Arguments, bool) {
	arguments := Arguments {
		uniform         = false,
		seed            = u64(time.to_unix_nanoseconds(time.now())),
		number_of_pairs = 100,
		cluster_size    = 25,
	}

	for arg in args {
		fmt.printf("arg: %s\n", arg)
		if strings.has_prefix(arg, "--") {
			if idx := strings.index(arg, "="); idx != -1 {
				key := arg[:idx]
				value := arg[idx + 1:]

				fmt.printf("key: %s\n", key)
				fmt.printf("v: %s\n", value)

				if key == "--uniform" {
					if value == "true" {
						arguments.uniform = true
					} else if value == "false" {
						arguments.uniform = false
					} else {
						fmt.eprintln("Error: wrong value for --uniform")
						return arguments, false
					}
				} else if key == "--seed" {
					val, ok := strconv.parse_u64(value)
					if !ok do return arguments, false
					arguments.seed = val
				} else if key == "--pairs" {
					val, ok := strconv.parse_int(value)
					if !ok do return arguments, false
					arguments.number_of_pairs = val
				} else if key == "--cluster" {
					val, ok := strconv.parse_int(value)
					if !ok do return arguments, false
					arguments.cluster_size = val
				} else {
					fmt.eprintln("Error: unknown argument")
					return arguments, false
				}
			} else {
				fmt.eprintln("Error: argument has no equal sign")
				return arguments, false
			}
		}
	}

	return arguments, true
}

main :: proc() {
	arguments, ok := parse_args(os.args)
	if !ok {
		os.exit(1)
	}

	rand.reset(arguments.seed)

	file, err1 := os.open("pairs.json", os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err1 != 0 {
		fmt.eprintln("Error creating pairs.json")
		os.exit(1)
	}
	defer os.close(file)

	file_answers, err2 := os.open("answers.f64", os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err2 != 0 {
		fmt.eprintln("Error creating answers.f64")
		os.exit(1)
	}
	defer os.close(file_answers)

	w: bufio.Writer

	bufio.writer_init(&w, os.to_stream(file))
	defer bufio.writer_flush(&w)
	writer := bufio.writer_to_stream(&w)

	io.write_string(writer, "{\n\"pairs\": [\n")

	center: Point
	radiusx, radiusy: f64
	if !arguments.uniform {
		center.x = random_in_range(-180, 180)
		center.y = random_in_range(-90, 90)
		radiusx = random_in_range(0, 180)
		radiusy = random_in_range(0, 90)
	}

	point0, point1: Point
	haversine_sum: f64 = 0

	for i in 0 ..< arguments.number_of_pairs {
		if arguments.uniform {
			point0.x = random_in_range(-180, 180)
			point0.y = random_in_range(-90, 90)
			point1.x = random_in_range(-180, 180)
			point1.y = random_in_range(-90, 90)
		} else {
			point0.x = generate_value_center(180, center.x, radiusx)
			point0.y = generate_value_center(90, center.y, radiusy)
			point1.x = generate_value_center(180, center.x, radiusx)
			point1.y = generate_value_center(90, center.y, radiusy)
		}

		haversine_value := haversine(point0.x, point0.y, point1.x, point1.y, EARTH_RADIUS)

		bytes_val := transmute([8]u8)haversine_value
		os.write(file_answers, bytes_val[:])
		haversine_sum += haversine_value

		// Escaped JSON braces by doubling them {{ and }}
		if i == arguments.number_of_pairs - 1 {
			fmt.wprintf(
				writer,
				"\t\t{{\"x0\": %.16f, \"y0\": %.16f, \"x1\": %.16f, \"y1\": %.16f}}\n",
				point0.x,
				point0.y,
				point1.x,
				point1.y,
			)
		} else {
			fmt.wprintf(
				writer,
				"\t\t{{\"x0\": %.16f, \"y0\": %.16f, \"x1\": %.16f, \"y1\": %.16f}},\n",
				point0.x,
				point0.y,
				point1.x,
				point1.y,
			)
		}

		if !arguments.uniform && (i % arguments.cluster_size == 0) {
			center.x = random_in_range(-180, 180)
			center.y = random_in_range(-90, 90)
			radiusx = random_in_range(0, 180)
			radiusy = random_in_range(0, 90)
		}
	}

	io.write_string(writer, "]\n}")
	bufio.writer_flush(&w)

	haversine_avg := haversine_sum / f64(arguments.number_of_pairs)
	fmt.printf("%.16f\n", haversine_avg)

	bytes_avg := transmute([8]u8)haversine_avg
	os.write(file_answers, bytes_avg[:])
}
