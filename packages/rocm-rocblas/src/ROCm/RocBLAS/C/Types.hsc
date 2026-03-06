{-# LANGUAGE CApiFFI #-}

module ROCm.RocBLAS.C.Types
  ( RocblasInt
  , RocblasStride
  ) where

#include <rocblas/rocblas.h>

import Data.Int (Int32, Int64)

-- | Corresponds to @rocblas_int@ (int32 in LP64 builds, int64 in ILP64 builds).
--
-- We use hsc2hs to follow the C headers.
type RocblasInt = #{type rocblas_int}

-- | Corresponds to @rocblas_stride@.
type RocblasStride = #{type rocblas_stride}
