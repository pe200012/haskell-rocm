#include <rocrand/rocrand.h>

extern "C" int hs_rocrand_status_success(void) {
  return ROCRAND_STATUS_SUCCESS;
}

extern "C" int hs_rocrand_status_version_mismatch(void) {
  return ROCRAND_STATUS_VERSION_MISMATCH;
}

extern "C" int hs_rocrand_status_not_created(void) {
  return ROCRAND_STATUS_NOT_CREATED;
}

extern "C" int hs_rocrand_status_allocation_failed(void) {
  return ROCRAND_STATUS_ALLOCATION_FAILED;
}

extern "C" int hs_rocrand_status_type_error(void) {
  return ROCRAND_STATUS_TYPE_ERROR;
}

extern "C" int hs_rocrand_status_out_of_range(void) {
  return ROCRAND_STATUS_OUT_OF_RANGE;
}

extern "C" int hs_rocrand_status_length_not_multiple(void) {
  return ROCRAND_STATUS_LENGTH_NOT_MULTIPLE;
}

extern "C" int hs_rocrand_status_double_precision_required(void) {
  return ROCRAND_STATUS_DOUBLE_PRECISION_REQUIRED;
}

extern "C" int hs_rocrand_status_launch_failure(void) {
  return ROCRAND_STATUS_LAUNCH_FAILURE;
}

extern "C" int hs_rocrand_status_internal_error(void) {
  return ROCRAND_STATUS_INTERNAL_ERROR;
}

extern "C" int hs_rocrand_rng_pseudo_default(void) {
  return ROCRAND_RNG_PSEUDO_DEFAULT;
}

extern "C" int hs_rocrand_rng_pseudo_xorwow(void) {
  return ROCRAND_RNG_PSEUDO_XORWOW;
}

extern "C" int hs_rocrand_rng_pseudo_philox4x32_10(void) {
  return ROCRAND_RNG_PSEUDO_PHILOX4_32_10;
}
