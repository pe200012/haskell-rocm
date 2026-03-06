{-# LANGUAGE CApiFFI #-}

module ROCm.RocSPARSE.C.Types
  ( RocsparseInt
  ) where

#include <rocsparse/rocsparse.h>

import Data.Int (Int32, Int64)

-- | Corresponds to @rocsparse_int@.
--
-- Uses hsc2hs so the binding follows LP64 / ILP64 builds.
type RocsparseInt = #{type rocsparse_int}
