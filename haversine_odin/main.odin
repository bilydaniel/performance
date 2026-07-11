package haversine

import "core:fmt"
import "core:io"
import "core:log"
import "core:os"


// Mirrors the anonymous `testFunction` struct in the Zig version.
Test_Function :: struct {
	name:    string,
	compute: Compute_Func, // inferred type name, adjust to match reference_haversine.odin
	verify:  Verify_Func, // inferred type name, adjust to match reference_haversine.odin
}

test_functions := [?]Test_Function {
	{
		name = "ReferenceHaversine",
		compute = reference_haversine_sum,
		verify = reference_verify_haversine,
	},
}

main :: proc() {
	context.logger = log.create_console_logger()
	cpu_freq := estimate_cpu_timer_freq()

	setup := setup_haversine()
	if !setup.valid {
		log.error("setup is not valid")
		return
	}

	series, error := test_series_init(len(test_functions), 1)
	if error != .None {
		return
	}

	init_math_functions()

	stdout := os.stdout

	for {
		for test_func in test_functions {
			test_series_set_column_label(&series, fmt.tprintf("func: %s", test_func.name))

			tester: Repetition_tester
			repetition_tester_new_test_wave(&tester, setup.parsed_byte_count, cpu_freq, 10)

			individual_error_count := test_func.verify(setup)
			sum_error_count: u64 = 0

			for repetition_tester_is_testing(&tester) {
				repetition_tester_begin_time(&tester)
				check := test_func.compute(setup)
				repetition_tester_count_bytes(&tester, setup.parsed_byte_count)
				repetition_tester_end_time(&tester)

				if !approx_equal(check, setup.sum_answer) {
					sum_error_count += 1
				}
			}

			if sum_error_count > 0 || individual_error_count > 0 {
				fmt.printf(
					"haversines are wrong, sum: %d, individual: %d \n",
					sum_error_count,
					individual_error_count,
				)
			}
		}

		test_series_print_csv_for_value(&series, .Gb_Per_Second, os.to_stream(stdout), 1.0)

		if testInputRange {
			for math_type in Math_func_type {
				value := ranges[math_type]
				fmt.printf("%v: %v\n", math_type, value)
			}
		}
		fmt.printf("\n")

		if testReferenceFunctions {
			for math_type in Math_func_type {
				value := math_results[math_type]
				fmt.printf("%v: %v\n", math_type, value)
			}
		}
		fmt.printf("\n")
	}
}
