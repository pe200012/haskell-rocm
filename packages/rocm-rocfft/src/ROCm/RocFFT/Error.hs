{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocFFT.Error
  ( rocfftStatusToString
  , checkRocfft
  ) where

import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.RocFFT.Types
  ( RocfftStatus(..)
  , pattern RocfftStatusFailure
  , pattern RocfftStatusInvalidArgValue
  , pattern RocfftStatusInvalidArrayType
  , pattern RocfftStatusInvalidDimensions
  , pattern RocfftStatusInvalidDistance
  , pattern RocfftStatusInvalidOffset
  , pattern RocfftStatusInvalidStrides
  , pattern RocfftStatusInvalidWorkBuffer
  , pattern RocfftStatusSuccess
  )

rocfftStatusToString :: RocfftStatus -> String
rocfftStatusToString st
  | st == RocfftStatusSuccess = "rocfft_status_success"
  | st == RocfftStatusFailure = "rocfft_status_failure"
  | st == RocfftStatusInvalidArgValue = "rocfft_status_invalid_arg_value"
  | st == RocfftStatusInvalidDimensions = "rocfft_status_invalid_dimensions"
  | st == RocfftStatusInvalidArrayType = "rocfft_status_invalid_array_type"
  | st == RocfftStatusInvalidStrides = "rocfft_status_invalid_strides"
  | st == RocfftStatusInvalidDistance = "rocfft_status_invalid_distance"
  | st == RocfftStatusInvalidOffset = "rocfft_status_invalid_offset"
  | st == RocfftStatusInvalidWorkBuffer = "rocfft_status_invalid_work_buffer"
  | otherwise = "rocfft_status(" <> show (unRocfftStatus st) <> ")"

checkRocfft :: HasCallStack => String -> RocfftStatus -> IO ()
checkRocfft callName st
  | st == RocfftStatusSuccess = pure ()
  | otherwise = throwFFIError "rocfft" callName (fromIntegral (unRocfftStatus st)) (rocfftStatusToString st)
