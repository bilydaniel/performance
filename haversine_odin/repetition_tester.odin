package haversine

// NOTE: this assumes a sibling "profiling" package exposing:
//   read_cpu_timer          :: proc() -> u64
//   read_os_page_fault_count :: proc() -> u64
// mirroring the Zig `profiling.zig` module's readCPUTimer / readOSPageFaultCount.

import "core:fmt"
import "core:io"
import "core:mem"

TestMode :: enum u32 {
	Uninitialized,
	Testing,
	Completed,
	Test_Error,
}

ValueType :: enum uint {
	Test_Count,
	Cpu_Time,
	Mem_Page_Faults,
	Byte_Count,
	Seconds,
	Gb_Per_Second,
	Kb_Per_Page_Fault,
	Count,
}

// Matches the Zig `@typeInfo(ValueType).@"enum".fields.len`: one slot per
// variant, including Count itself as a reserved/unused trailing slot.
VALUE_TYPE_LEN :: int(ValueType.Count) + 1

Value :: struct {
	e:         [VALUE_TYPE_LEN]u64,
	per_count: [VALUE_TYPE_LEN]f64,
}

value_init :: proc() -> Value {
	return Value{}
}

value_get :: proc(v: ^Value, v_type: ValueType) -> u64 {
	return v.e[int(v_type)]
}

value_compute_derived_values :: proc(v: ^Value, cpu_freq: u64) {
	test_count := v.e[int(ValueType.Test_Count)]
	divisor: f64 = f64(test_count) if test_count > 0 else 1.0

	for i in 0 ..< VALUE_TYPE_LEN {
		v.per_count[i] = f64(v.e[i]) / divisor
	}

	if cpu_freq > 0 {
		seconds := seconds_from_cpu_time(v.per_count[int(ValueType.Cpu_Time)], cpu_freq)
		v.per_count[int(ValueType.Seconds)] = seconds

		if v.per_count[int(ValueType.Byte_Count)] > 0.0 {
			gigabyte: f64 = 1024.0 * 1024.0 * 1024.0
			v.per_count[int(ValueType.Gb_Per_Second)] =
				v.per_count[int(ValueType.Byte_Count)] / (gigabyte * seconds)
		}
	}

	if v.per_count[int(ValueType.Mem_Page_Faults)] > 0.0 {
		v.per_count[int(ValueType.Kb_Per_Page_Fault)] =
			v.per_count[int(ValueType.Byte_Count)] /
			(v.per_count[int(ValueType.Mem_Page_Faults)] * 1024.0)
	}
}

value_print :: proc(v: ^Value, label: string) {
	fmt.printf("%s: %.0f", label, v.per_count[int(ValueType.Cpu_Time)])
	fmt.printf(" (%.4fms)", 1000.0 * v.per_count[int(ValueType.Seconds)])

	if v.per_count[int(ValueType.Byte_Count)] > 0.0 {
		fmt.printf(" %.4fgb/s", v.per_count[int(ValueType.Gb_Per_Second)])
	}

	if v.per_count[int(ValueType.Kb_Per_Page_Fault)] > 0.0 {
		fmt.printf(
			" PF: %.4f (%.4fk/fault)",
			v.per_count[int(ValueType.Mem_Page_Faults)],
			v.per_count[int(ValueType.Kb_Per_Page_Fault)],
		)
	}
}

TestResults :: struct {
	total: Value,
	min:   Value,
	max:   Value,
}

test_results_print :: proc(tr: ^TestResults) {
	value_print(&tr.min, "Min")
	fmt.printf("\n")
	value_print(&tr.max, "Max")
	fmt.printf("\n")
	value_print(&tr.total, "Avg")
	fmt.printf("\n")
}

Repetition_tester :: struct {
	target_processed_byte_count: u64,
	cpu_freq:                    u64,
	try_for_time:                u64,
	tests_started_at:            u64,
	test_mode:                   TestMode,
	print_new_minimums:          bool,
	open_block_count:            u32,
	closed_block_count:          u32,
	this_test:                   Value,
	results:                     TestResults,
}

repetition_tester_error_mode :: proc(rt: ^Repetition_tester, message: string) {
	rt.test_mode = .Test_Error
	fmt.printf("ERROR: %s\n", message)
}

repetition_tester_new_test_wave :: proc(
	rt: ^Repetition_tester,
	target_processed_byte_count: u64,
	cpu_freq: u64,
	seconds_to_try: u32,
) {
	if rt.test_mode == .Uninitialized {
		rt.test_mode = .Testing
		rt.target_processed_byte_count = target_processed_byte_count
		rt.cpu_freq = cpu_freq
		rt.print_new_minimums = true
		rt.results.min.e[int(ValueType.Cpu_Time)] = max(u64)
	} else if rt.test_mode == .Completed {
		rt.test_mode = .Testing

		if rt.target_processed_byte_count != target_processed_byte_count {
			repetition_tester_error_mode(rt, "TargetProcessedByteCount changed")
		}

		if rt.cpu_freq != cpu_freq {
			repetition_tester_error_mode(rt, "CPU frequency changed")
		}
	}

	rt.try_for_time = u64(seconds_to_try) * cpu_freq
	rt.tests_started_at = read_cpu_timer()
}

repetition_tester_begin_time :: proc(rt: ^Repetition_tester) {
	rt.open_block_count += 1
	rt.this_test.e[int(ValueType.Mem_Page_Faults)] -= read_os_page_fault_count()
	rt.this_test.e[int(ValueType.Cpu_Time)] -= read_cpu_timer()
}

repetition_tester_end_time :: proc(rt: ^Repetition_tester) {
	rt.this_test.e[int(ValueType.Cpu_Time)] += read_cpu_timer()
	rt.this_test.e[int(ValueType.Mem_Page_Faults)] += read_os_page_fault_count()
	rt.closed_block_count += 1
}

repetition_tester_count_bytes :: proc(rt: ^Repetition_tester, byte_count: u64) {
	rt.this_test.e[int(ValueType.Byte_Count)] += byte_count
}

repetition_tester_is_testing :: proc(rt: ^Repetition_tester) -> bool {
	if rt.test_mode == .Testing {
		accumulator := rt.this_test
		curr_time := read_cpu_timer()

		if rt.open_block_count > 0 {
			if rt.open_block_count != rt.closed_block_count {
				repetition_tester_error_mode(rt, "Unbalanced beginTime/endTime")
			}

			if accumulator.e[int(ValueType.Byte_Count)] != rt.target_processed_byte_count {
				repetition_tester_error_mode(rt, "Processed byte count mismatch")
			}

			if rt.test_mode == .Testing {
				results := &rt.results

				accumulator.e[int(ValueType.Test_Count)] = 1

				for i in 0 ..< VALUE_TYPE_LEN {
					results.total.e[i] += accumulator.e[i]
				}

				if value_get(&results.max, .Cpu_Time) < value_get(&accumulator, .Cpu_Time) {
					results.max = accumulator
				}

				if value_get(&results.min, .Cpu_Time) > value_get(&accumulator, .Cpu_Time) {
					results.min = accumulator
					rt.tests_started_at = curr_time

					if rt.print_new_minimums {
						value_compute_derived_values(&rt.results.min, rt.cpu_freq)
						value_print(&rt.results.min, "Min")
						fmt.printf("                                   \r")
					}
				}

				rt.open_block_count = 0
				rt.closed_block_count = 0
				rt.this_test = Value{}
			}
		}

		if (curr_time - rt.tests_started_at) > rt.try_for_time {
			rt.test_mode = .Completed

			value_compute_derived_values(&rt.results.total, rt.cpu_freq)
			value_compute_derived_values(&rt.results.min, rt.cpu_freq)
			value_compute_derived_values(&rt.results.max, rt.cpu_freq)

			fmt.printf("                                                          \r")
			test_results_print(&rt.results)
		}
	}

	return rt.test_mode == .Testing
}

seconds_from_cpu_time :: proc(cpu_time: f64, cpu_freq: u64) -> f64 {
	if cpu_freq == 0 {
		return 0
	}
	return cpu_time / f64(cpu_freq)
}

print_time :: proc(label: string, cpu_time: f64, cpu_freq: u64, byte_count: u64) {
	fmt.printf("%s: %.1f", label, cpu_time)

	if cpu_freq > 0 {
		seconds := seconds_from_cpu_time(cpu_time, cpu_freq)
		fmt.printf(" (%.6fms)", 1000 * seconds)

		if byte_count > 0 {
			gb: f64 = 1024 * 1024 * 1024
			best_bandwidth := f64(byte_count) / (gb * seconds)
			fmt.printf(" %.6fgb/s", best_bandwidth)
		}
	}
}

SeriesLabel :: struct {
	chars: [64]u8,
	len:   int,
}

// NOTE: Zig's bufPrint errors (and leaves len untouched) if the formatted
// text doesn't fit in the 64-byte buffer. Odin's fmt.bprintf instead just
// truncates to fit, so overly long labels are silently cut off rather than
// left unset.
series_label_set :: proc(sl: ^SeriesLabel, format: string, args: ..any) {
	formatted := fmt.bprintf(sl.chars[:], format, ..args)
	sl.len = len(formatted)
}

series_label_get :: proc(sl: ^SeriesLabel) -> string {
	return string(sl.chars[:sl.len])
}

TestSeries :: struct {
	allocator:       mem.Allocator,
	max_row_count:   u32,
	column_count:    u32,
	row_index:       u32,
	column_index:    u32,
	test_results:    []TestResults,
	row_labels:      []SeriesLabel,
	column_labels:   []SeriesLabel,
	row_label_label: SeriesLabel,
}

test_series_init :: proc(
	column_count: u32,
	max_row_count: u32,
) -> (
	TestSeries,
	mem.Allocator_Error,
) {
	test_results, err1 := make([]TestResults, int(column_count) * int(max_row_count))
	if err1 != .None {
		return TestSeries{}, err1
	}

	row_labels, err2 := make([]SeriesLabel, int(max_row_count))
	if err2 != .None {
		delete(test_results)
		return TestSeries{}, err2
	}

	column_labels, err3 := make([]SeriesLabel, int(column_count))
	if err3 != .None {
		delete(test_results)
		delete(row_labels)
		return TestSeries{}, err3
	}

	return TestSeries {
			max_row_count = max_row_count,
			column_count = column_count,
			test_results = test_results,
			row_labels = row_labels,
			column_labels = column_labels,
		},
		.None
}

test_series_deinit :: proc(ts: ^TestSeries) {
	delete(ts.test_results, ts.allocator)
	delete(ts.row_labels, ts.allocator)
	delete(ts.column_labels, ts.allocator)
	ts^ = TestSeries{}
}

test_series_is_in_bounds :: proc(ts: ^TestSeries) -> bool {
	return ts.column_index < ts.column_count && ts.row_index < ts.max_row_count
}

test_series_set_row_label_label :: proc(ts: ^TestSeries, format: string, args: ..any) {
	series_label_set(&ts.row_label_label, format, ..args)
}

test_series_set_row_label :: proc(ts: ^TestSeries, format: string, args: ..any) {
	if test_series_is_in_bounds(ts) {
		series_label_set(&ts.row_labels[ts.row_index], format, ..args)
	}
}

test_series_set_column_label :: proc(ts: ^TestSeries, format: string, args: ..any) {
	if test_series_is_in_bounds(ts) {
		series_label_set(&ts.column_labels[ts.column_index], format, ..args)
	}
}

test_series_new_test_wave :: proc(
	ts: ^TestSeries,
	tester: ^Repetition_tester,
	target_processed_byte_count: u64,
	cpu_freq: u64,
	seconds_to_try: u32,
) {
	if test_series_is_in_bounds(ts) {
		fmt.printf(
			"\n--- %s %s ---\n",
			series_label_get(&ts.column_labels[ts.column_index]),
			series_label_get(&ts.row_labels[ts.row_index]),
		)
	}
	repetition_tester_new_test_wave(tester, target_processed_byte_count, cpu_freq, seconds_to_try)
}

test_series_get_test_results :: proc(
	ts: ^TestSeries,
	column_index: u32,
	row_index: u32,
) -> ^TestResults {
	if column_index < ts.column_count && row_index < ts.max_row_count {
		return &ts.test_results[row_index * ts.column_count + column_index]
	}
	return nil
}

test_series_is_testing :: proc(ts: ^TestSeries, tester: ^Repetition_tester) -> bool {
	result := repetition_tester_is_testing(tester)

	if !result {
		if test_series_is_in_bounds(ts) {
			if res := test_series_get_test_results(ts, ts.column_index, ts.row_index); res != nil {
				res^ = tester.results
			}

			ts.column_index += 1
			if ts.column_index >= ts.column_count {
				ts.column_index = 0
				ts.row_index += 1
			}
		}
	}

	return result
}

// NOTE: Zig's version uses `try writer.print(...)` to propagate I/O errors.
// Odin's fmt.wprintf reports errors via its own return values rather than
// through Zig-style error unions; here we simply ignore them, matching the
// original's "best effort" console/CSV output style.
test_series_print_csv_for_value :: proc(
	ts: ^TestSeries,
	value_type: ValueType,
	w: io.Writer,
	coefficient: f64,
) {
	fmt.wprintf(w, "%s", series_label_get(&ts.row_label_label))

	for col_index in 0 ..< ts.column_count {
		fmt.wprintf(w, ",%s", series_label_get(&ts.column_labels[col_index]))
	}
	fmt.wprintf(w, "\n")

	for r_index in 0 ..< ts.row_index {
		fmt.wprintf(w, "%s", series_label_get(&ts.row_labels[r_index]))

		for c_index in 0 ..< ts.column_count {
			if test_results := test_series_get_test_results(ts, c_index, r_index);
			   test_results != nil {
				v := coefficient * test_results.min.per_count[int(value_type)]
				fmt.wprintf(w, ",%v", v)
			}
		}
		fmt.wprintf(w, "\n")
	}
}
