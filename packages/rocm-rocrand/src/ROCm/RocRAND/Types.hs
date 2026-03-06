{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocRAND.Types
  ( RocRandStatus(..)
  , pattern RocRandStatusSuccess
  , pattern RocRandStatusVersionMismatch
  , pattern RocRandStatusNotCreated
  , pattern RocRandStatusAllocationFailed
  , pattern RocRandStatusTypeError
  , pattern RocRandStatusOutOfRange
  , pattern RocRandStatusLengthNotMultiple
  , pattern RocRandStatusDoublePrecisionRequired
  , pattern RocRandStatusLaunchFailure
  , pattern RocRandStatusInternalError
  , RocRandRngType(..)
  , pattern RocRandRngPseudoDefault
  , pattern RocRandRngPseudoXorwow
  , pattern RocRandRngPseudoPhilox4x32_10
  ) where

import Foreign.C.Types (CInt)

newtype RocRandStatus = RocRandStatus {unRocRandStatus :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocRandStatusSuccess :: RocRandStatus
pattern RocRandStatusSuccess = RocRandStatus 0

pattern RocRandStatusVersionMismatch :: RocRandStatus
pattern RocRandStatusVersionMismatch = RocRandStatus 100

pattern RocRandStatusNotCreated :: RocRandStatus
pattern RocRandStatusNotCreated = RocRandStatus 101

pattern RocRandStatusAllocationFailed :: RocRandStatus
pattern RocRandStatusAllocationFailed = RocRandStatus 102

pattern RocRandStatusTypeError :: RocRandStatus
pattern RocRandStatusTypeError = RocRandStatus 103

pattern RocRandStatusOutOfRange :: RocRandStatus
pattern RocRandStatusOutOfRange = RocRandStatus 104

pattern RocRandStatusLengthNotMultiple :: RocRandStatus
pattern RocRandStatusLengthNotMultiple = RocRandStatus 105

pattern RocRandStatusDoublePrecisionRequired :: RocRandStatus
pattern RocRandStatusDoublePrecisionRequired = RocRandStatus 106

pattern RocRandStatusLaunchFailure :: RocRandStatus
pattern RocRandStatusLaunchFailure = RocRandStatus 107

pattern RocRandStatusInternalError :: RocRandStatus
pattern RocRandStatusInternalError = RocRandStatus 108

newtype RocRandRngType = RocRandRngType {unRocRandRngType :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocRandRngPseudoDefault :: RocRandRngType
pattern RocRandRngPseudoDefault = RocRandRngType 400

pattern RocRandRngPseudoXorwow :: RocRandRngType
pattern RocRandRngPseudoXorwow = RocRandRngType 401

pattern RocRandRngPseudoPhilox4x32_10 :: RocRandRngType
pattern RocRandRngPseudoPhilox4x32_10 = RocRandRngType 404
