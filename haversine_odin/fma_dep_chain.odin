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
