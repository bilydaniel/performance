package main

import "base:intrinsics"
import "core:fmt"
import "core:math"

sin_f64 :: proc(x: f64) -> f64 {return math.sin(x)}
cos_f64 :: proc(x: f64) -> f64 {return math.cos(x)}
asin_f64 :: proc(x: f64) -> f64 {return math.asin(x)}
sqrt_f64 :: proc(x: f64) -> f64 {return math.sqrt(x)}


@(private)
fma :: intrinsics.fused_mul_add

sin_ce :: #force_inline proc(orig_x: f64) -> f64 {
	half_pi := PI64 / 2
	pos_x := abs(orig_x)
	x := pos_x > half_pi ? (PI64 - pos_x) : pos_x

	x2 := x * x

	r: f64 = 0h3CE883C1C5DEFFBE
	r = fma(r, x2, 0hBD6AE43DC9BF8BA7)
	r = fma(r, x2, 0h3DE6123CE513B09F)
	r = fma(r, x2, 0hBE5AE6454D960AC4)
	r = fma(r, x2, 0h3EC71DE3A52AAB96)
	r = fma(r, x2, 0hBF2A01A01A014EB6)
	r = fma(r, x2, 0h3F811111111110C9)
	r = fma(r, x2, 0hBFC5555555555555)
	r = fma(r, x2, 0h3FF0000000000000)
	r *= x

	result := orig_x < 0 ? -r : r

	return result
}

cos_ce :: #force_inline proc(x: f64) -> f64 {
	result := sin_ce(x + PI64 / 2.0)
	return result
}

sqrt_ce :: #force_inline proc(scalar_x: f64) -> f64 {
	// Odin's math.sqrt on f64 compiles down to a single sqrtsd,
	// same as the original SSE intrinsic version.
	result := math.sqrt(scalar_x)
	return result
}

asin_ce :: #force_inline proc(orig_x: f64) -> f64 {
	needs_transform := orig_x > 0.7071067811865475244
	x := needs_transform ? sqrt_ce(1.0 - orig_x * orig_x) : orig_x

	x2 := x * x

	r: f64 = 0h3FEDFC53682725CA
	r = fma(r, x2, 0hC00BEC6DAF74ED61)
	r = fma(r, x2, 0h4018BF4DADAF548C)
	r = fma(r, x2, 0hC01B06F523E74F33)
	r = fma(r, x2, 0h4014537DDDE2D76D)
	r = fma(r, x2, 0hC006067D334B4792)
	r = fma(r, x2, 0h3FF1FB54DA575B22)
	r = fma(r, x2, 0hBFD57380BCD2890E)
	r = fma(r, x2, 0h3FB69B370AAD086E)
	r = fma(r, x2, 0hBF721438CCC95D62)
	r = fma(r, x2, 0h3F8B8A33B8E380EF)
	r = fma(r, x2, 0h3F8C37061F4E5F55)
	r = fma(r, x2, 0h3F91C875D6C5323D)
	r = fma(r, x2, 0h3F96E88CE94D1149)
	r = fma(r, x2, 0h3F9F1C73443A02F5)
	r = fma(r, x2, 0h3FA6DB6DB3184756)
	r = fma(r, x2, 0h3FB3333333380DF2)
	r = fma(r, x2, 0h3FC555555555531E)
	r = fma(r, x2, 0h3FF0000000000000)
	r *= x

	result := needs_transform ? (1.57079632679489661923 - r) : r
	return result
}


approx_sin :: proc(x: f64) -> f64 {
	assert(x >= 0 && x <= math.PI / 2, "x is shit")
	a := (-4 / (math.PI * math.PI))
	b := (4 / math.PI)

	result := a * (x * x) + (b * x)
	return result
}


factorial :: proc(x: u32) -> f64 {
	// could use math.factorial, which is a table, gonna calculate for perf testing
	//return i64(math.factorial(int(x)))

	result: f64 = f64(x)
	count := f64(x)
	for count > 1 {
		count -= 1
		result *= count
	}


	return result
}


/* NOTE(casey): These are our stub functions. We will start filling
   them in with real computation over time.
*/
old_sin_ce :: proc(x: f64) -> f64 {
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


taylor_coeff :: proc(power: u32) -> f64 {
	result: f64 = 0
	sign_test := math.mod(f32((power - 1) / 2), f32(2))
	sign: f64 = 1
	if sign_test == 1 {
		sign = -1
	}
	result = sign / factorial(power)
	return result
}

taylor_sin :: proc(x: f64, max_power: u32) -> f64 {
	result: f64 = 0


	x_2 := x * x
	x_pow := x

	for power: u32 = 1; power <= max_power; power += 2 {
		result += x_pow * taylor_coeff(power)
		x_pow *= x_2
	}

	return result
}

horner_sin :: proc(x: f64, max_power: u32) -> f64 {
	x_2 := x * x
	result: f64 = 0

	for inv_power: u32 = 1; inv_power <= max_power; inv_power += 2 {
		power := max_power - (inv_power - 1)
		//result = result * x_2 + taylor_coeff(power)
		result = math.fmuladd(result, x_2, taylor_coeff(power)) // should be better for rounding, doesent seem to be better
		//intrinsics.fused_mul_add()
	}
	result *= x

	return result
}

old_cos_ce :: proc(x: f64) -> f64 {
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

old_asin_ce :: proc(x: f64) -> f64 {
	result := x
	return result
}

old_sqrt_ce :: proc(x: f64) -> f64 {
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

	// for precision_test(&tester, 0, PI64 / 2) {
	// 	for i: u32 = 1; i < 11; i += 2 {
	// 		test_result(
	// 			&tester,
	// 			sin_f64(tester.input_value),
	// 			taylor_sin(tester.input_value, i),
	// 			"TaylorSin [%d]",
	// 			i,
	// 		)
	// 	}
	// }

	for precision_test(&tester, 0, PI64 / 2) {
		for i: u32 = 1; i < 31; i += 2 {
			test_result(
				&tester,
				sin_f64(tester.input_value),
				sin_ce(tester.input_value),
				"sin_ce [%d]",
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
