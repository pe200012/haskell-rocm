{-# LANGUAGE ForeignFunctionInterface #-}

module RocRandHeaderConstants
  ( rocrandStatusSuccessHeader
  , rocrandStatusVersionMismatchHeader
  , rocrandStatusNotCreatedHeader
  , rocrandStatusAllocationFailedHeader
  , rocrandStatusTypeErrorHeader
  , rocrandStatusOutOfRangeHeader
  , rocrandStatusLengthNotMultipleHeader
  , rocrandStatusDoublePrecisionRequiredHeader
  , rocrandStatusLaunchFailureHeader
  , rocrandStatusInternalErrorHeader
  , rocrandRngPseudoDefaultHeader
  , rocrandRngPseudoXorwowHeader
  , rocrandRngPseudoPhilox4x32_10Header
  ) where

import Foreign.C.Types (CInt(..))

foreign import ccall unsafe "hs_rocrand_status_success"
  rocrandStatusSuccessHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_version_mismatch"
  rocrandStatusVersionMismatchHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_not_created"
  rocrandStatusNotCreatedHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_allocation_failed"
  rocrandStatusAllocationFailedHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_type_error"
  rocrandStatusTypeErrorHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_out_of_range"
  rocrandStatusOutOfRangeHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_length_not_multiple"
  rocrandStatusLengthNotMultipleHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_double_precision_required"
  rocrandStatusDoublePrecisionRequiredHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_launch_failure"
  rocrandStatusLaunchFailureHeader :: CInt

foreign import ccall unsafe "hs_rocrand_status_internal_error"
  rocrandStatusInternalErrorHeader :: CInt

foreign import ccall unsafe "hs_rocrand_rng_pseudo_default"
  rocrandRngPseudoDefaultHeader :: CInt

foreign import ccall unsafe "hs_rocrand_rng_pseudo_xorwow"
  rocrandRngPseudoXorwowHeader :: CInt

foreign import ccall unsafe "hs_rocrand_rng_pseudo_philox4x32_10"
  rocrandRngPseudoPhilox4x32_10Header :: CInt
