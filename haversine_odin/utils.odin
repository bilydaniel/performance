package haversine
import "base:intrinsics"

pretend_to_read :: proc(value: $T) {
	v := value
	intrinsics.volatile_store(&v, v)
}

pretend_to_write :: proc(ptr: ^$T) {
	ptr^ = intrinsics.volatile_load(ptr)
}
