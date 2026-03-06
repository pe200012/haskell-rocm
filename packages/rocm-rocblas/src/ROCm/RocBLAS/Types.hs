{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocBLAS.Types
  ( RocblasStatus(..)
  , pattern RocblasStatusSuccess
  , RocblasPointerMode(..)
  , pattern RocblasPointerModeHost
  , pattern RocblasPointerModeDevice
  , RocblasFill(..)
  , pattern RocblasFillUpper
  , pattern RocblasFillLower
  , RocblasEvect(..)
  , pattern RocblasEvectOriginal
  , pattern RocblasEvectTridiagonal
  , pattern RocblasEvectNone
  , RocblasOperation(..)
  , pattern RocblasOperationNone
  , pattern RocblasOperationTranspose
  , pattern RocblasOperationConjugateTranspose
  ) where

import Foreign.C.Types (CInt)
import Foreign.Storable (Storable)

newtype RocblasStatus = RocblasStatus {unRocblasStatus :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasStatusSuccess :: RocblasStatus
pattern RocblasStatusSuccess = RocblasStatus 0

newtype RocblasPointerMode = RocblasPointerMode {unRocblasPointerMode :: CInt}
  deriving newtype (Eq, Ord, Show, Storable)

pattern RocblasPointerModeHost :: RocblasPointerMode
pattern RocblasPointerModeHost = RocblasPointerMode 0

pattern RocblasPointerModeDevice :: RocblasPointerMode
pattern RocblasPointerModeDevice = RocblasPointerMode 1

newtype RocblasFill = RocblasFill {unRocblasFill :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasFillUpper :: RocblasFill
pattern RocblasFillUpper = RocblasFill 121

pattern RocblasFillLower :: RocblasFill
pattern RocblasFillLower = RocblasFill 122

newtype RocblasEvect = RocblasEvect {unRocblasEvect :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasEvectOriginal :: RocblasEvect
pattern RocblasEvectOriginal = RocblasEvect 211

pattern RocblasEvectTridiagonal :: RocblasEvect
pattern RocblasEvectTridiagonal = RocblasEvect 212

pattern RocblasEvectNone :: RocblasEvect
pattern RocblasEvectNone = RocblasEvect 213

newtype RocblasOperation = RocblasOperation {unRocblasOperation :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasOperationNone :: RocblasOperation
pattern RocblasOperationNone = RocblasOperation 111

pattern RocblasOperationTranspose :: RocblasOperation
pattern RocblasOperationTranspose = RocblasOperation 112

pattern RocblasOperationConjugateTranspose :: RocblasOperation
pattern RocblasOperationConjugateTranspose = RocblasOperation 113
