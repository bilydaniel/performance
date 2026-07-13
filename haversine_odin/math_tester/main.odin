package main

import "core:math"

sin_f64 :: proc(x: f64) -> f64 {return math.sin(x)}
cos_f64 :: proc(x: f64) -> f64 {return math.cos(x)}
asin_f64 :: proc(x: f64) -> f64 {return math.asin(x)}
sqrt_f64 :: proc(x: f64) -> f64 {return math.sqrt(x)}


approx_sin :: proc(x: f64) -> f64 {
	assert(x >= 0 && x <= math.PI / 2, "x is shit")
	a := (-4 / (math.PI * math.PI))
	b := (4 / math.PI)

	result := a * (x * x) + (b * x)
	return result
}


factorial :: proc(x: i64) -> i64 {
	// could use math.factorial, which is a table, gonna calculate for perf testing
	//return i64(math.factorial(int(x)))

	result: i64 = x
	count := x
	for count > 1 {
		count -= 1
		result *= count
	}

	return result
}

approx_taylor_sin :: proc(x: f64, number_of_steps: u32) -> f64 {
	result: f64 = 0
	assert(x >= 0 && x <= math.PI / 2, "x is shit")

	sign: f64 = 1
	power: f64 = 1
	divider: i64 = 1
	for i: u32 = 0; i < number_of_steps; i += 1 {
		result += sign * (math.pow(x, power) / f64(factorial(divider)))

		sign = -sign
		power += 2
		divider += 2
	}

	return result
}

/* NOTE(casey): These are our stub functions. We will start filling
   them in with real computation over time.
*/
sin_ce :: proc(x: f64) -> f64 {
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

taylor_sin :: proc(x: f64, max_power: u32) -> f64 {
	result: f64 = 0
	if x >= 0 && x <= math.PI / 2 {
		result = approx_taylor_sin(x, taylor_const)
	} else if x > math.PI / 2 && x <= math.PI {
		x_shifted := math.PI - x
		result = approx_taylor_sin(x_shifted, taylor_const)
	} else if x < 0 && x >= -math.PI / 2 {
		x_abs := -x
		result = -approx_taylor_sin(x_abs, taylor_const)
	} else if x < -math.PI / 2 && x >= -math.PI {
		x_shifted := x + math.PI
		result = -approx_taylor_sin(x_shifted, taylor_const)
	}
	return result
}

cos_ce :: proc(x: f64) -> f64 {
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

asin_ce :: proc(x: f64) -> f64 {
	result := x
	return result
}

sqrt_ce :: proc(x: f64) -> f64 {
	result := x
	return result
}

main :: proc() {
	// check_hard_coded_reference("sin", sin_f64, RefTableSinX[:])
	// check_hard_coded_reference("cos", cos_f64, RefTableCosX[:])
	// check_hard_coded_reference("asin", asin_f64, RefTableArcSinX[:])
	// check_hard_coded_reference("sqrt", sqrt_f64, RefTableSqrtX[:])
	//check_hard_coded_reference("sinCE", sin_ce, RefTableSinX[:])
	//check_hard_coded_reference("cosCE", cos_ce, RefTableCosX[:])


	tester: Math_Tester

	for precision_test(&tester, -PI64, PI64) {
		for i: u32 = 1; i < 31; i += 2 {
			test_result(
				&tester,
				sin_f64(tester.input_value),
				taylor_sin(tester.input_value, i),
				"TaylorSin [%d]",
				i,
			)
		}
	}

	// for precision_test(&tester, -PI64, PI64) {
	// 	test_result(&tester, sin_f64(tester.input_value), sin_ce(tester.input_value), "SinCE")
	// }

	// for precision_test(&tester, -PI64 / 2, PI64 / 2) {
	// 	test_result(&tester, cos_f64(tester.input_value), cos_ce(tester.input_value), "CosCE")
	// }

	// for precision_test(&tester, 0, 1) {
	// 	test_result(&tester, asin_f64(tester.input_value), asin_ce(tester.input_value), "ASinCE")
	// }

	// for precision_test(&tester, 0, 1) {
	// 	test_result(&tester, sqrt_f64(tester.input_value), sqrt_ce(tester.input_value), "SqrtCE")
	// }

	print_results(&tester)
}
