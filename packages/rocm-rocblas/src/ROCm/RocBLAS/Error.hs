{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocBLAS.Error
  ( rocblasStatusToString
  , checkRocblas
  ) where

import Foreign.C.String (peekCString)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.RocBLAS.Raw (c_rocblas_status_to_string)
import ROCm.RocBLAS.Types (RocblasStatus(..), pattern RocblasStatusSuccess)

rocblasStatusToString :: RocblasStatus -> IO String
rocblasStatusToString st = c_rocblas_status_to_string st >>= peekCString

checkRocblas :: HasCallStack => String -> RocblasStatus -> IO ()
checkRocblas callName st
  | st == RocblasStatusSuccess = pure ()
  | otherwise = do
      msg <- rocblasStatusToString st
      throwFFIError "rocblas" callName (fromIntegral (unRocblasStatus st)) msg
