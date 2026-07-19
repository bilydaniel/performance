package haversine

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"

Range :: struct {
	min: f64,
	max: f64,
}

Math_func_type :: enum {
	Cos, // -1.56 => 1.56
	Sin, // -3 => 3
	Asin, // 0 => 1
	Sqrt, // 0 => 1
}

check_range :: proc(range_type: Math_func_type, x: f64) {
	if testInputRange {
		min := ranges[range_type].min
		max := ranges[range_type].max

		if x < min {
			ranges[range_type].min = x
		}

		if x > max {
			ranges[range_type].max = x
		}
	}
}

ranges: [Math_func_type]Range = {
	.Cos = {min = math.F64_MAX, max = math.F64_MIN},
	.Sin = {min = math.F64_MAX, max = math.F64_MIN},
	.Asin = {min = math.F64_MAX, max = math.F64_MIN},
	.Sqrt = {min = math.F64_MAX, max = math.F64_MIN},
}

dgr_to_rad :: proc(dgr: f64) -> f64 {
	return dgr * (math.PI / 180.0)
}

Math_test_result :: struct {
	input:            f64,
	test_output:      f64,
	reference_output: f64,
	diff:             f64,
}


check_results :: proc(math_type: Math_func_type, input: f64) -> f64 {
	math_function := math_functions[math_type]
	test_output := math_function.test_function(input)
	if testReferenceFunctions {
		reference_output := math_function.reference_function(input)

		diff := abs(test_output - reference_output)
		math_result := &math_results[math_type]
		if diff > math_result.diff {
			math_result.input = input
			math_result.test_output = test_output
			math_result.reference_output = reference_output
			math_result.diff = diff
		}
	}
	return test_output
}

Math_functions :: struct {
	test_function:      proc(x: f64) -> f64,
	reference_function: proc(x: f64) -> f64,
}

testReferenceFunctions :: true
testInputRange :: true
math_results: [len(Math_func_type)]Math_test_result
math_functions: [len(Math_func_type)]Math_functions

init_math_functions :: proc() {
	math_functions[Math_func_type.Cos].reference_function = reference_cos
	math_functions[Math_func_type.Cos].test_function = cos_ce

	math_functions[Math_func_type.Sin].reference_function = reference_sin
	math_functions[Math_func_type.Sin].test_function = sin_ce

	math_functions[Math_func_type.Asin].reference_function = reference_asin
	math_functions[Math_func_type.Asin].test_function = asin_ce

	math_functions[Math_func_type.Sqrt].reference_function = reference_sqrt
	math_functions[Math_func_type.Sqrt].test_function = sqrt_ce
}

test_cos :: proc(x: f64) -> f64 {
	x_abs := abs(x)

	result: f64 = 0
	if x_abs >= 0 && x_abs <= math.PI / 2 {
		result = approx_sin(math.PI / 2 - x_abs)
	} else if x_abs > math.PI / 2 && x_abs <= math.PI {
		x_shifted := math.PI - x_abs
		result = -approx_sin(math.PI / 2 - x_shifted)
	}

	return result
}

reference_cos :: proc(x: f64) -> f64 {
	return math.cos(x)
}

cos :: proc(x: f64) -> f64 {
	check_range(.Cos, x)
	test_output := check_results(.Cos, x)
	return test_output
}

reference_sin :: proc(x: f64) -> f64 {
	return math.sin(x)
}

//approximates 0 -> pi, acting like its only 0 -> pi/2 for practice
approx_sin :: proc(x: f64) -> f64 {
	assert(x >= 0 && x <= math.PI / 2, "x is shit")
	a := (-4 / (math.PI * math.PI))
	b := (4 / math.PI)

	result := a * (x * x) + (b * x)
	return result
}

test_sin :: proc(x: f64) -> f64 {
	result: f64 = 0
	if x >= 0 && x <= math.PI / 2 {
		result = approx_sin(x)
	} else if x > math.PI / 2 && x <= math.PI {
		x_shifted := math.PI - x
		result = approx_sin(x_shifted)
	} else if x < 0 && x >= -math.PI / 2 {
		x_abs := -x
		result = -approx_sin(x_abs)
	} else if x < -math.PI / 2 && x >= -math.PI {
		x_shifted := x + math.PI
		result = -approx_sin(x_shifted)
	}
	return result
}

sin :: proc(x: f64) -> f64 {
	check_range(.Sin, x)
	test_output := check_results(.Sin, x)
	return test_output
}

reference_asin :: proc(x: f64) -> f64 {
	return math.asin(x)
}

test_asin :: proc(x: f64) -> f64 {
	return math.asin(x)
}

asin :: proc(x: f64) -> f64 {
	check_range(.Asin, x)
	test_output := check_results(.Asin, x)
	return test_output
}

sqrt :: proc(x: f64) -> f64 {
	check_range(.Sqrt, x)
	test_output := check_results(.Sqrt, x)
	return test_output
}
reference_sqrt :: proc(x: f64) -> f64 {
	return math.sqrt(x)
}

test_sqrt :: proc(x: f64) -> f64 {
	// could cast to f32 for faster calculation with less precision
	a: #simd[1]f64 = x
	int_result := intrinsics.sqrt(a)
	result := intrinsics.simd_extract(int_result, 0)


	return result
}

haversine_ce :: proc(x0, y0, x1, y1, radius: f64) -> f64 {
	dy := dgr_to_rad(y1 - y0)
	dx := dgr_to_rad(x1 - x0)
	y0_rad := dgr_to_rad(y0)
	y1_rad := dgr_to_rad(y1)

	sin_dy_2 := sin_ce(dy / 2.0)
	sin_dx_2 := sin_ce(dx / 2.0)

	term_a := square(sin_dy_2)
	term_b := cos_ce(y0_rad) * cos_ce(y1_rad) * square(sin_dx_2)

	root_term := term_a + term_b

	result := 2 * radius * asin_ce(sqrt_ce(root_term))
	return result
}

reference_haversine :: proc(x0, y0, x1, y1, radius: f64) -> f64 {
	dy := dgr_to_rad(y1 - y0)
	dx := dgr_to_rad(x1 - x0)
	y0_rad := dgr_to_rad(y0)
	y1_rad := dgr_to_rad(y1)

	sin_dy_2 := math.sin(dy / 2.0)
	sin_dx_2 := math.sin(dx / 2.0)

	term_a := math.pow(sin_dy_2, 2)
	term_b := math.cos(y0_rad) * math.cos(y1_rad) * math.pow(sin_dx_2, 2)

	root_term := term_a + term_b

	result := 2 * radius * math.asin(math.sqrt(root_term))
	return result
}

reference_haversine_sum :: proc(setup: Haversine_Setup) -> f64 {
	sum: f64 = 0
	sum_coeff := 1.0 / f64(len(setup.parsed_pairs))

	for pair in setup.parsed_pairs {
		dist := reference_haversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS)
		sum += sum_coeff * dist
	}
	return sum
}

haversine_sum_ce :: proc(setup: Haversine_Setup) -> f64 {
	sum: f64 = 0
	sum_coeff := 1.0 / f64(len(setup.parsed_pairs))

	for pair in setup.parsed_pairs {
		dist := haversine_ce(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS)
		sum += sum_coeff * dist
	}
	return sum
}

reference_verify_haversine :: proc(setup: Haversine_Setup) -> u64 {
	error_count: u64 = 0

	for pair, i in setup.parsed_pairs {
		dist := reference_haversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS)
		if !approx_equal(dist, setup.answers[i]) {
			error_count += 1
		}
	}
	return error_count
}


verify_haversine_ce :: proc(setup: Haversine_Setup) -> u64 {
	error_count: u64 = 0

	for pair, i in setup.parsed_pairs {
		dist := haversine_ce(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS)
		if !approx_equal(dist, setup.answers[i]) {
			error_count += 1
		}
	}
	return error_count
}
