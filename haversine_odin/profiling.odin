package haversine

import "base:intrinsics"
import "core:sys/posix"

read_cpu_timer :: proc "contextless" () -> u64 {
	return u64(intrinsics.read_cycle_counter())
}

read_os_timer :: proc() -> u64 {
	value: posix.timeval
	posix.gettimeofday(&value, nil)
	return 1_000_000 * u64(value.tv_sec) + u64(value.tv_usec)
}

read_os_page_fault_count :: proc() -> u64 {
	usage: posix.rusage
	posix.getrusage(.SELF, &usage)
	return u64(usage.ru_minflt + usage.ru_majflt)
}

estimate_cpu_timer_freq :: proc() -> u64 {
	MILLISECONDS_TO_WAIT :: 100
	OS_FREQ :: 1_000_000

	cpu_start := read_cpu_timer()
	os_start := read_os_timer()

	os_end: u64 = 0
	os_elapsed: u64 = 0
	os_wait_time: u64 = OS_FREQ * MILLISECONDS_TO_WAIT / 1000

	for os_elapsed < os_wait_time {
		os_end = read_os_timer()
		os_elapsed = os_end - os_start
	}

	cpu_end := read_cpu_timer()
	cpu_elapsed := cpu_end - cpu_start

	cpu_freq: u64 = 0
	if os_elapsed != 0 {
		cpu_freq = OS_FREQ * cpu_elapsed / os_elapsed
	}

	return cpu_freq
}

// FOR WINDOWS
// read_os_timer_freq :: proc() -> u64 {
// 	freq: win32.LARGE_INTEGER
// 	win32.QueryPerformanceFrequency(&freq)
// 	return u64(freq)
// }
// read_os_timer :: proc() -> u64 {
// 	value: win32.LARGE_INTEGER
// 	win32.QueryPerformanceCounter(&value)
// 	return u64(value)
// }
