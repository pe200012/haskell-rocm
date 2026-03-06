{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocRAND.Error
  ( rocRandStatusToString
  , checkRocRand
  ) where

import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.RocRAND.Types
  ( RocRandStatus(..)
  , pattern RocRandStatusAllocationFailed
  , pattern RocRandStatusDoublePrecisionRequired
  , pattern RocRandStatusInternalError
  , pattern RocRandStatusLaunchFailure
  , pattern RocRandStatusLengthNotMultiple
  , pattern RocRandStatusNotCreated
  , pattern RocRandStatusOutOfRange
  , pattern RocRandStatusSuccess
  , pattern RocRandStatusTypeError
  , pattern RocRandStatusVersionMismatch
  )

rocRandStatusToString :: RocRandStatus -> String
rocRandStatusToString st
  | st == RocRandStatusSuccess = "ROCRAND_STATUS_SUCCESS"
  | st == RocRandStatusVersionMismatch = "ROCRAND_STATUS_VERSION_MISMATCH"
  | st == RocRandStatusNotCreated = "ROCRAND_STATUS_NOT_CREATED"
  | st == RocRandStatusAllocationFailed = "ROCRAND_STATUS_ALLOCATION_FAILED"
  | st == RocRandStatusTypeError = "ROCRAND_STATUS_TYPE_ERROR"
  | st == RocRandStatusOutOfRange = "ROCRAND_STATUS_OUT_OF_RANGE"
  | st == RocRandStatusLengthNotMultiple = "ROCRAND_STATUS_LENGTH_NOT_MULTIPLE"
  | st == RocRandStatusDoublePrecisionRequired = "ROCRAND_STATUS_DOUBLE_PRECISION_REQUIRED"
  | st == RocRandStatusLaunchFailure = "ROCRAND_STATUS_LAUNCH_FAILURE"
  | st == RocRandStatusInternalError = "ROCRAND_STATUS_INTERNAL_ERROR"
  | otherwise = "ROCRAND_STATUS(" <> show (unRocRandStatus st) <> ")"

checkRocRand :: HasCallStack => String -> RocRandStatus -> IO ()
checkRocRand callName st
  | st == RocRandStatusSuccess = pure ()
  | otherwise = throwFFIError "rocrand" callName (fromIntegral (unRocRandStatus st)) (rocRandStatusToString st)
