package haversine

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:simd"


EARTH_RADIUS :: 6372.8 // KM
PI64 :: 3.14159265358979323846264338327950288419716939937510582097494459230781640628

Compute_Func :: proc(setup: Haversine_Setup) -> f64
Verify_Func :: proc(setup: Haversine_Setup) -> u64

Haversine_Setup :: struct {
	json_buffer:       []u8,
	answers_buffer:    []u8,
	answers:           []f64,
	parsed_pairs:      []Pair,
	parsed_byte_count: u64,
	sum_answer:        f64,
	valid:             bool,
}

haversine_setup_is_valid :: proc(s: ^Haversine_Setup) -> bool {
	return s.valid
}

approx_equal :: proc(x, y: f64) -> bool {
	EPSILON :: 0.00000001
	diff := x - y
	return diff > -EPSILON && diff < EPSILON
}

square :: proc(x: f64) -> f64 {
	return x * x
}

fma :: intrinsics.fused_mul_add

sin_ce :: proc(orig_x: f64) -> f64 {
	half_pi := PI64 / 2
	pos_x := abs(orig_x)
	x := pos_x > half_pi ? (PI64 - pos_x) : pos_x

	x2 := x * x

	r: f64 = transmute(f64)u64(0x3ce883c1c5deffbe)
	r = fma(r, x2, transmute(f64)u64(0xbd6ae43dc9bf8ba7))
	r = fma(r, x2, transmute(f64)u64(0x3de6123ce513b09f))
	r = fma(r, x2, transmute(f64)u64(0xbe5ae6454d960ac4))
	r = fma(r, x2, transmute(f64)u64(0x3ec71de3a52aab96))
	r = fma(r, x2, transmute(f64)u64(0xbf2a01a014eb6))
	r = fma(r, x2, transmute(f64)u64(0x3f811111111110c9))
	r = fma(r, x2, transmute(f64)u64(0xbfc5555555555555))
	r = fma(r, x2, 1.0)
	r *= x

	result := orig_x < 0 ? -r : r

	return result
}


cos_ce :: proc(x: f64) -> f64 {
	result := sin_ce(x + PI64 / 2.0)
	return result
}

sqrt_ce :: proc(scalar_x: f64) -> f64 {
	result := math.sqrt(scalar_x)
	return result
}

asin_core_from_squared :: proc(x2: f64) -> f64 {

	x := sqrt_ce(x2)

	r: f64 = transmute(f64)u64(0x3fedfc53682725ca)
	r = fma(r, x2, transmute(f64)u64(0xc00bec6daf74ed61))
	r = fma(r, x2, transmute(f64)u64(0x4018bf4dadaf548c))
	r = fma(r, x2, transmute(f64)u64(0xc01b06f523e74f33))
	r = fma(r, x2, transmute(f64)u64(0x4014537ddde2d76d))
	r = fma(r, x2, transmute(f64)u64(0xc006067d334b4792))
	r = fma(r, x2, transmute(f64)u64(0x3ff1fb54da575b22))
	r = fma(r, x2, transmute(f64)u64(0xbfd57380bcd2890e))
	r = fma(r, x2, transmute(f64)u64(0x3fb69b370aad086e))
	r = fma(r, x2, transmute(f64)u64(0xbf721438ccc95d62))
	r = fma(r, x2, transmute(f64)u64(0x3f8b8a33b8e380ef))
	r = fma(r, x2, transmute(f64)u64(0x3f8c37061f4e5f55))
	r = fma(r, x2, transmute(f64)u64(0x3f91c875d6c5323d))
	r = fma(r, x2, transmute(f64)u64(0x3f96e88ce94d1149))
	r = fma(r, x2, transmute(f64)u64(0x3f9f1c73443a02f5))
	r = fma(r, x2, transmute(f64)u64(0x3fa6db6db3184756))
	r = fma(r, x2, transmute(f64)u64(0x3fb3333333380df2))
	r = fma(r, x2, transmute(f64)u64(0x3fc555555555531e))
	r = fma(r, x2, 1.0)
	r *= x

	return r
}

asin_ce :: proc(orig_x: f64) -> f64 {
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
sine_core_with_prefix :: proc(a: f64, b: f64, c: f64) -> f64 {
	x: f64 = fma(a, b, c)
	x2 := x * x

	r: f64 = transmute(f64)u64(0x3ce883c1c5deffbe)
	r = fma(r, x2, transmute(f64)u64(0xbd6ae43dc9bf8ba7))
	r = fma(r, x2, transmute(f64)u64(0x3de6123ce513b09f))
	r = fma(r, x2, transmute(f64)u64(0xbe5ae6454d960ac4))
	r = fma(r, x2, transmute(f64)u64(0x3ec71de3a52aab96))
	r = fma(r, x2, transmute(f64)u64(0xbf2a01a01a014eb6))
	r = fma(r, x2, transmute(f64)u64(0x3f811111111110c9))
	r = fma(r, x2, transmute(f64)u64(0xbfc5555555555555))
	r = fma(r, x2, 1.0)
	r *= x

	return r
}


expanded_haversine :: proc(setup: Haversine_Setup) -> f64 {
	sum: f64 = 0
	sum_coeff := (2 * EARTH_RADIUS) / f64(len(setup.parsed_pairs))


	for pair in setup.parsed_pairs {
		x0 := pair.x0
		x1 := pair.x1
		y0 := pair.y0
		y1 := pair.y1


		radian_c: f64 = 0.01745329251994329577 // pi / 180
		radian_c_half := radian_c / 2
		pi_half := PI64 / 2
		deg180: f64 = 180

		//slc1: f64 = (y0 < 0) ? radian_c : -radian_c
		slc1: f64 = -radian_c
		//y0_abs := abs(y0)

		//slc2: f64 = (y1 < 0) ? radian_c : -radian_c
		slc2: f64 = -radian_c
		//y1_abs := abs(y1)

		// dx := abs(x1 - x0)
		// dy := abs(y1 - y0)

		vector_values := #simd[4]f64{y0, y1, x1 - x0, y1 - y0}
		vector_values2 := #simd[4]f64{180, 180, 180, 180}

		simd.lanes_le(vector_values, vector_values2)
		vector_abs := simd.abs(vector_values)
		y0_abs := simd.extract(vector_abs, 0)
		y1_abs := simd.extract(vector_abs, 1)
		dx := simd.extract(vector_abs, 2)
		dy := simd.extract(vector_abs, 3)

		//slc0 := (dy < deg180) ? radian_c_half : -radian_c_half
		slc0 := radian_c_half // always gets squared, sign doesent matter
		//slc3 := (dx < deg180) ? radian_c_half : -radian_c_half
		slc3 := radian_c_half // always gets squared, sign doesent matter

		alc0 := (dy < deg180) ? 0 : -PI64
		alc3 := (dx < deg180) ? 0 : -PI64

		s1: f64 = sine_core_with_prefix(slc1, y0_abs, pi_half)
		s2: f64 = sine_core_with_prefix(slc2, y1_abs, pi_half)
		s0: f64 = sine_core_with_prefix(slc0, dy, alc0)
		s3: f64 = sine_core_with_prefix(slc3, dx, alc3)

		a: f64 = fma(s0, s0, s1 * s2 * s3 * s3)


		// ASIN
		needs_transform := a > 0.5
		range_a := needs_transform ? (1.0 - a) : a
		if range_a < 0 {
			fmt.println(range_a)
		}
		r: f64 = asin_core_from_squared(range_a)
		range_r := needs_transform ? (1.57079632679489661923 - r) : r

		sum = fma(range_r, sum_coeff, sum)
	}


	return sum
}

read_entire_file :: proc(name: string) -> ([]u8, os.Error) {
	data, err := os.read_entire_file_from_path(name, context.allocator)
	return data, err
}

setup_haversine :: proc() -> Haversine_Setup {
	result: Haversine_Setup

	json_buffer, err := read_entire_file("pairs.json")
	if err != nil {
		log.error("could not read file pairs.json: ", err)
		return result
	}

	answers_buffer, err2 := read_entire_file("answers.f64")
	if err2 != nil {
		log.error("could not read file answers.f64: ", err)
		return result
	}

	answers := mem.slice_data_cast([]f64, answers_buffer)

	pairs: [dynamic]Pair
	pair_count, parse_ok := parse_haversine_pairs(json_buffer, &pairs)
	if !parse_ok {
		log.error("parse failed")
		return result
	}

	if len(answers) == len(pairs) + 1 {
		result.json_buffer = json_buffer
		result.answers_buffer = answers_buffer
		result.answers = answers[:len(answers) - 1]
		result.parsed_pairs = pairs[:]
		result.sum_answer = answers[len(answers) - 1]
		result.parsed_byte_count = u64(size_of(Pair) * len(pairs))

		MEGABYTE :: 1024 * 1024

		fmt.printf("Source JSON: %dmb\n", len(result.json_buffer) / MEGABYTE)
		fmt.printf(
			"Parsed: %dmb (%d pairs)\n",
			result.parsed_byte_count / MEGABYTE,
			len(result.parsed_pairs),
		)

		result.valid = len(result.parsed_pairs) != 0
	}

	return result
}
