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
  , RocblasSvect(..)
  , pattern RocblasSvectAll
  , pattern RocblasSvectSingular
  , pattern RocblasSvectOverwrite
  , pattern RocblasSvectNone
  , RocblasWorkmode(..)
  , pattern RocblasOutOfPlace
  , pattern RocblasInPlace
  , RocblasSrange(..)
  , pattern RocblasSrangeAll
  , pattern RocblasSrangeValue
  , pattern RocblasSrangeIndex
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

newtype RocblasSvect = RocblasSvect {unRocblasSvect :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasSvectAll :: RocblasSvect
pattern RocblasSvectAll = RocblasSvect 191

pattern RocblasSvectSingular :: RocblasSvect
pattern RocblasSvectSingular = RocblasSvect 192

pattern RocblasSvectOverwrite :: RocblasSvect
pattern RocblasSvectOverwrite = RocblasSvect 193

pattern RocblasSvectNone :: RocblasSvect
pattern RocblasSvectNone = RocblasSvect 194

newtype RocblasWorkmode = RocblasWorkmode {unRocblasWorkmode :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasOutOfPlace :: RocblasWorkmode
pattern RocblasOutOfPlace = RocblasWorkmode 201

pattern RocblasInPlace :: RocblasWorkmode
pattern RocblasInPlace = RocblasWorkmode 202

newtype RocblasSrange = RocblasSrange {unRocblasSrange :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocblasSrangeAll :: RocblasSrange
pattern RocblasSrangeAll = RocblasSrange 261

pattern RocblasSrangeValue :: RocblasSrange
pattern RocblasSrangeValue = RocblasSrange 262

pattern RocblasSrangeIndex :: RocblasSrange
pattern RocblasSrangeIndex = RocblasSrange 263

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
