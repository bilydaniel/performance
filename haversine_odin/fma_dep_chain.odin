package haversine

fma_dep_chain :: proc(chain_count, chain_length: u64) {
	for chain_index: u64 = 0; chain_index < chain_count; chain_index += 1 {
		X2: f64 = 0
		M: f64 = 0
		R0: f64 = 0

		pretend_to_write(&X2)
		pretend_to_write(&M)
		pretend_to_write(&R0)

		for i: u64 = 0; i < chain_length; i += 8 {
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
			R0 = fma(R0, X2, M)
		}

		pretend_to_read(&R0)
	}
}

fma_dep_chain_interleaved :: proc(chain_count, chain_length: u64) {
	for chain_index: u64 = 0; chain_index < chain_count; chain_index += 8 {
		X2: f64 = 0
		M: f64 = 0
		R0: f64 = 0
		R1: f64 = 0
		R2: f64 = 0
		R3: f64 = 0
		R4: f64 = 0
		R5: f64 = 0
		R6: f64 = 0
		R7: f64 = 0

		pretend_to_write(&X2)
		pretend_to_write(&M)
		pretend_to_write(&R0)
		pretend_to_write(&R1)
		pretend_to_write(&R2)
		pretend_to_write(&R3)
		pretend_to_write(&R4)
		pretend_to_write(&R6)
		pretend_to_write(&R7)

		for i: u64 = 0; i < chain_length; i += 1 {
			R0 = fma(R0, X2, M)
			R1 = fma(R1, X2, M)
			R2 = fma(R2, X2, M)
			R3 = fma(R3, X2, M)
			R4 = fma(R4, X2, M)
			R5 = fma(R5, X2, M)
			R6 = fma(R6, X2, M)
			R7 = fma(R7, X2, M)
		}

		pretend_to_read(&R0)
		pretend_to_read(&R1)
		pretend_to_read(&R2)
		pretend_to_read(&R3)
		pretend_to_read(&R4)
		pretend_to_read(&R6)
		pretend_to_read(&R7)
	}
}
