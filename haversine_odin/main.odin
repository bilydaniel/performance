package haversine

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:os"
import "core:simd"


Test_Function :: struct {
	name:    string,
	compute: Compute_Func,
	//verify:  Verify_Func,
}

test_functions := [?]Test_Function {
	// {
	// 	name    = "ReferenceHaversine",
	// 	compute = reference_haversine_sum,
	// 	//verify = reference_verify_haversine,
	// },
	// {
	// 	name    = "HaversineCE", //
	// 	compute = haversine_sum_ce,
	// 	//verify  = verify_haversine_ce,
	// },
	{
		name    = "ExpandedHaversine",
		compute = expanded_haversine,
		//verify = reference_verify_haversine,
	},
	{
		name    = "ExpandedHaversineWide",
		compute = expanded_haversine_wide,
		//verify = reference_verify_haversine,
	},
	{
		name    = "ReferenceHaversine",
		compute = reference_haversine_sum,
		//verify = reference_verify_haversine,
	},
	// {
	// 	name    = "HaversineCE",
	// 	compute = haversine_sum_ce,
	// 	//verify = reference_verify_haversine,
	// },
}

test_enum :: enum {
	reference_haversine,
	dependency_chain,
	predicates,
	shuffle_puzzles,
}

main :: proc() {
	context.logger = log.create_console_logger()

	current_test: test_enum = .reference_haversine

	switch current_test {
	case .reference_haversine:
		reference_haversine_test()
	case .dependency_chain:
		dependency_chain_test()
	case .predicates:
		predicates_test()
	case .shuffle_puzzles:
		shuffle_puzzles()
	}

}

dependency_chain_test :: proc() {
	cpu_freq := estimate_cpu_timer_freq()

	test_dependency := false
	test_interleaved := false
	test_spaced := true

	series, error := test_series_init(1, 1024)
	if error == nil {
		test_series_set_row_label_label(&series, "ChainLength")

		if test_dependency {
			for chain_length: u64 = 8; chain_length <= 256; chain_length += 8 {
				rep_count: u64 = 1024 * 1024
				chaint_count := rep_count / chain_length

				rep_count = chaint_count * chain_length
				test_series_set_row_label(&series, "%v", chain_length)
				test_series_set_column_label(&series, "FMADepChain")

				tester := Repetition_tester{}
				test_series_new_test_wave(&series, &tester, .op_count, rep_count, cpu_freq, 10)

				for test_series_is_testing(&series, &tester) {
					repetition_tester_begin_time(&tester)
					fma_dep_chain(chaint_count, chain_length)
					repetition_tester_count_ops(&tester, rep_count)
					repetition_tester_end_time(&tester)
				}
			}
		}

		if test_interleaved {
			for chain_length: u64 = 8; chain_length <= 256; chain_length += 8 {
				rep_count: u64 = 1024 * 1024
				chaint_count := rep_count / chain_length

				rep_count = chaint_count * chain_length
				test_series_set_row_label(&series, "%v", chain_length)
				test_series_set_column_label(&series, "FMADepChainInterleaved")

				tester := Repetition_tester{}
				test_series_new_test_wave(&series, &tester, .op_count, rep_count, cpu_freq, 10)

				for test_series_is_testing(&series, &tester) {
					repetition_tester_begin_time(&tester)
					fma_dep_chain_interleaved(chaint_count, chain_length)
					repetition_tester_count_ops(&tester, rep_count)
					repetition_tester_end_time(&tester)
				}
			}
		}

		if test_spaced {
			for chain_length: u64 = 8; chain_length <= 256; chain_length += 8 {
				rep_count: u64 = 1024 * 1024
				chaint_count := rep_count / chain_length

				rep_count = chaint_count * chain_length
				test_series_set_row_label(&series, "%v", chain_length)
				test_series_set_column_label(&series, "FMADepChainSpaced")

				tester := Repetition_tester{}
				test_series_new_test_wave(&series, &tester, .op_count, rep_count, cpu_freq, 10)

				for test_series_is_testing(&series, &tester) {
					repetition_tester_begin_time(&tester)
					fma_dep_chain_spaced(chaint_count, chain_length)
					repetition_tester_count_ops(&tester, rep_count)
					repetition_tester_end_time(&tester)
				}
			}
		}
		stdout := os.stdout
		test_series_print_csv_for_value(&series, .Gb_Per_Second, os.to_stream(stdout), 1.0)
	}
}

reference_haversine_test :: proc() {
	cpu_freq := estimate_cpu_timer_freq()

	setup := setup_haversine()
	if !setup.valid {
		log.error("setup is not valid")
		return
	}

	series, error := test_series_init(len(test_functions), 1024)
	if error != .None {
		return
	}

	init_math_functions()

	stdout := os.stdout

	reference_sum := setup.sum_answer
	test_series_set_row_label_label(&series, "Test")
	test_series_set_row_label(&series, "Haversine")

	for test_func in test_functions {
		test_series_set_column_label(&series, fmt.tprintf("%s", test_func.name))

		tester: Repetition_tester
		test_series_new_test_wave(
			&series,
			&tester,
			.Byte_Count,
			setup.parsed_byte_count,
			cpu_freq,
			1,
		) //10

		sum_error_count: u64 = 0
		test_sum: f64 = 0


		for repetition_tester_is_testing(&tester) {
			repetition_tester_begin_time(&tester)
			test_sum = test_func.compute(setup)
			repetition_tester_count_bytes(&tester, setup.parsed_byte_count)
			repetition_tester_end_time(&tester)

			if !approx_equal(test_sum, reference_sum) {
				sum_error_count += 1
				fmt.printf("test_sum: %v, reference_sum: %v \n", test_sum, reference_sum)
			}
		}

		fmt.printf("             ________________                  ________________\n")
		fmt.printf("Sum: %+32.24f (%+32.24f)\n", test_sum, test_sum - reference_sum)
		fmt.printf("\n")

		if sum_error_count > 0 {
			fmt.printf("haversines are wrong, sum: %d,  \n", sum_error_count)
		}
	}

	test_series_print_csv_for_value(&series, .Gb_Per_Second, os.to_stream(stdout), 1.0)

	// if testInputRange {
	// 	for math_type in Math_func_type {
	// 		value := ranges[math_type]
	// 		fmt.printf("%v: %v\n", math_type, value)
	// 	}
	// }
	// fmt.printf("\n")
	//
	// if testReferenceFunctions {
	// 	for math_type in Math_func_type {
	// 		value := math_results[math_type]
	// 		fmt.printf("%v: %v\n", math_type, value)
	// 	}
	// }
	// fmt.printf("\n")

}

scalar_predicates :: struct {
	lat_less_180:    bool,
	lon_less_180:    bool,
	needs_transform: bool,
}

compute_scalar_predicates :: proc(abs_d_lat: f64, abs_d_lon: f64, a: f64) -> scalar_predicates {
	deg180: f64 = 180.0
	half: f64 = 0.5

	result: scalar_predicates = {}
	result.lat_less_180 = abs_d_lat < deg180
	result.lon_less_180 = abs_d_lon < deg180
	result.needs_transform = a > half

	return result
}

avx_predicates :: struct {
	lat_less_180:    #simd[4]u64,
	lon_less_180:    #simd[4]u64,
	needs_transform: #simd[4]u64,
}

compute_avx_predicates :: proc(
	abs_d_lat: #simd[4]f64,
	abs_d_lon: #simd[4]f64,
	a: #simd[4]f64,
) -> avx_predicates {
	deg180: #simd[4]f64 = 180.0
	half: #simd[4]f64 = 0.5

	result: avx_predicates = {}
	result.lat_less_180 = simd.lanes_lt(abs_d_lat, deg180)
	result.lon_less_180 = simd.lanes_lt(abs_d_lon, deg180)
	result.needs_transform = simd.lanes_lt(half, a)

	return result
}

predicates_test :: proc() {
	print_debug :: false
	width :: 4

	abs_d_lat: [width]f64 = {134.34, 212.34, 305.3, 20.6}
	abs_d_lon: [width]f64 = {160.43, 179.49, 180.0, 200.4}
	a: [width]f64 = {0.1232, 0.890, 0.49, 0.5}


	avx_result := compute_avx_predicates(
		simd.from_array(abs_d_lat),
		simd.from_array(abs_d_lon),
		simd.from_array(a),
	)

	avx_lat_less_180: [width]u64 = simd.to_array(avx_result.lat_less_180)
	avx_lon_less_180: [width]u64 = simd.to_array(avx_result.lon_less_180)
	avx_needs_transform: [width]u64 = simd.to_array(avx_result.needs_transform)

	avx_mask := avx_result.lat_less_180
	avx_true: #simd[4]f64 = 7
	avx_false: #simd[4]f64 = -3

	avx_true_u64 := transmute(#simd[4]u64)avx_true
	avx_false_u64 := transmute(#simd[4]u64)avx_false


	avx_result_combined := simd.bit_or(
		simd.bit_and(avx_true_u64, avx_mask),
		simd.bit_and_not(avx_false_u64, avx_mask),
	)
	fmt.println(transmute(#simd[4]f64)avx_result_combined)

	select_result := intrinsics.simd_select(avx_mask, avx_true, avx_false)
	fmt.println(select_result)


	for i := 0; i < width; i += 1 {
		scalar_result := compute_scalar_predicates(abs_d_lat[i], abs_d_lon[i], a[i])

		if print_debug {
			print_predicate(
				"LatLess180",
				abs_d_lat[i],
				scalar_result.lat_less_180,
				avx_lat_less_180[i],
			)
			print_predicate(
				"LonLess180",
				abs_d_lon[i],
				scalar_result.lon_less_180,
				avx_lon_less_180[i],
			)
			print_predicate(
				"NeedsTransform",
				a[i],
				scalar_result.needs_transform,
				avx_needs_transform[i],
			)
		}
	}
}

print_predicate :: proc(label: string, input_value: f64, scalar_answer: bool, avx_answer: u64) {
	fmt.printf("%16s: %9.4f %s ", label, input_value, "T" if bool(scalar_answer) else "f")
	if avx_answer == max(u64) {
		fmt.printf("T ")
	} else if avx_answer == 0 {
		fmt.printf("f ")
	} else {
		fmt.printf("ERROR ")
	}

	fmt.printf("%016x\n", avx_answer)
}


SHUFIMM_2x4 :: #force_inline proc "contextless" (e0: u8, e1: u8) -> u8 {
	result: u8 = e0 | (e1 << 4)
	return result
}

SHUFIMM_4x2 :: #force_inline proc "contextless" (e0: u8, e1: u8, e2: u8, e3: u8) -> u8 {
	result: u8 = e0 | (e1 << 2) | (e2 << 4) | (e3 << 6)
	return result
}

SHUFIMM_4x1 :: #force_inline proc "contextless" (e0: u8, e1: u8, e2: u8, e3: u8) -> u8 {
	result: u8 = e0 | (e1 << 1) | (e2 << 2) | (e3 << 3)
	return result
}

simd_type :: #simd[32]u8

SolutionGoesHere :: proc(A: simd_type) -> simd_type {
	result: #simd[32]u8 = 97
	return result
}

Puzzle0 :: proc(A: simd_type) -> simd_type {
	x := transmute(#simd[8]u32)A
	x = simd.swizzle(x, 2, 3, 0, 1, 6, 7, 4, 5)
	result := transmute(simd_type)x
	return result
}

Puzzle1 :: proc(A: simd_type) -> simd_type {
	x := transmute(#simd[8]u32)A
	x = simd.swizzle(x, 7, 4, 2, 5, 6, 0, 1, 3)
	result := transmute(simd_type)x
	return result
}
Puzzle2 :: proc(A: simd_type) -> simd_type {
	x := transmute(#simd[8]u32)A
	x = simd.swizzle(x, 2, 3, 0, 1, 6, 7, 4, 5)
	result := transmute(simd_type)x
	return result
}
Puzzle3 :: proc(A: simd_type) -> simd_type {
	x := transmute(#simd[8]u32)A
	x = simd.swizzle(x, 2, 3, 0, 1, 6, 7, 4, 5)
	result := transmute(simd_type)x
	return result
}
Puzzle4 :: proc(A: simd_type) -> simd_type {
	result := SolutionGoesHere(A)

	return result
}
Puzzle5 :: proc(A: simd_type) -> simd_type {
	result := SolutionGoesHere(A)

	return result
}
Puzzle6 :: proc(A: simd_type) -> simd_type {
	result := SolutionGoesHere(A)

	return result
}

Match :: proc(label: string, value: #simd[32]u8, target: string) {
	SIMD_BYTE_COUNT :: 32
	error_count: u32 = 0

	value_arr := simd.to_array(value)


	for i := 0; i < SIMD_BYTE_COUNT; i += 1 {
		if value_arr[i] != target[i] {
			error_count += 1
		}
	}

	fmt.printf("%v\n", label)
	fmt.printf("error_count: %v\n", error_count)
	if error_count > 0 {
		fmt.printf("target: %v\n", target)
		fmt.printf("value: %s\n", value_arr)
	}

}

shuffle_puzzles :: proc() {

	//ValuesA: string = "abcdefghijklmnopqrstuvwx12345678"
	// ValuesA: string = "abcd" + "efghijklmnopqrstuvwx12345677"
	// ValuesB: string = "ABCDEFGHIJKLMNOPQRSTUVWX.,;-=[]|"

	ValuesA := "abcd" + "efgh" + "ijkl" + "mnop" + "qrst" + "uvwx" + "1234" + "5678"
	ValuesB := "ABCD" + "EFGH" + "IJKL" + "MNOP" + "QRST" + "UVWX" + ".,+-" + "=[]|"

	values_a_data := ([^]u8)(raw_data(ValuesA))[0:32]
	A: #simd[32]u8 = simd.from_slice(#simd[32]u8, values_a_data)

	Match("Puzzle0", Puzzle0(A), "ijklmnopabcdefgh12345678qrstuvwx")
	Match("Puzzle1", Puzzle1(A), "5678qrstijkluvwx1234abcdefghmnop")
	Match("Puzzle2", Puzzle2(A), "keiadbcmfgljnohpsr5tuq8wx1234v67")
	Match("Puzzle3", Puzzle3(A), "3fch1267ab8d45eguxlqvminopwjktrs")

	// //
	// // NOTE(casey): Two-input puzzles
	// //
	//
	// Match("Puzzle4", Puzzle4(A, B), "ijkl" "mnop" "ABCD" "EFGH" "qrst" "uvwx" ".,;-" "=[]|");
	// Match("Puzzle5", Puzzle5(A, B), "ijkl" "abcd" "MNOP" "EFGH" "1234" "qrst" "=[]|" "UVWX");
	// Match("Puzzle6", Puzzle6(A, B), ";V=0" "X.|W" "T,Q]" "URS-" "u7x8" "0123" "rsqv" "04wt");
	//
}
