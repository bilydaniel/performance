package haversine

import "core:fmt"
import "core:log"
import "core:os"


// Mirrors the anonymous `testFunction` struct in the Zig version.
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
		name    = "ReferenceHaversine",
		compute = reference_haversine_sum,
		//verify = reference_verify_haversine,
	},
	{
		name    = "HaversineCE",
		compute = haversine_sum_ce,
		//verify = reference_verify_haversine,
	},
}

test_enum :: enum {
	reference_haversine,
	dependency_chain,
}
main :: proc() {
	context.logger = log.create_console_logger()

	current_test: test_enum = .dependency_chain

	switch current_test {
	case .reference_haversine:
		reference_haversine_test()
	case .dependency_chain:
		dependency_chain_test()
	}

}

dependency_chain_test :: proc() {
	cpu_freq := estimate_cpu_timer_freq()

	series, error := test_series_init(1, 1024)
	if error == nil {
		test_series_set_row_label_label(&series, "ChainLength")

		// for chain_length: u64 = 8; chain_length <= 256; chain_length += 8 {
		// 	rep_count: u64 = 1024 * 1024
		// 	chaint_count := rep_count / chain_length
		//
		// 	rep_count = chaint_count * chain_length
		// 	test_series_set_row_label(&series, "%v", chain_length)
		// 	test_series_set_column_label(&series, "FMADepChain")
		//
		// 	tester := Repetition_tester{}
		// 	test_series_new_test_wave(&series, &tester, .op_count, rep_count, cpu_freq, 10)
		//
		// 	for test_series_is_testing(&series, &tester) {
		// 		repetition_tester_begin_time(&tester)
		// 		fma_dep_chain(chaint_count, chain_length)
		// 		repetition_tester_count_ops(&tester, rep_count)
		// 		repetition_tester_end_time(&tester)
		// 	}
		// }

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
