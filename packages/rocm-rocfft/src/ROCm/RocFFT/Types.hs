{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocFFT.Types
  ( RocfftStatus(..)
  , pattern RocfftStatusSuccess
  , pattern RocfftStatusFailure
  , pattern RocfftStatusInvalidArgValue
  , pattern RocfftStatusInvalidDimensions
  , pattern RocfftStatusInvalidArrayType
  , pattern RocfftStatusInvalidStrides
  , pattern RocfftStatusInvalidDistance
  , pattern RocfftStatusInvalidOffset
  , pattern RocfftStatusInvalidWorkBuffer
  , RocfftResultPlacement(..)
  , pattern RocfftPlacementInplace
  , pattern RocfftPlacementNotInplace
  , RocfftTransformType(..)
  , pattern RocfftTransformTypeComplexForward
  , pattern RocfftTransformTypeComplexInverse
  , pattern RocfftTransformTypeRealForward
  , pattern RocfftTransformTypeRealInverse
  , RocfftPrecision(..)
  , pattern RocfftPrecisionSingle
  , pattern RocfftPrecisionDouble
  , pattern RocfftPrecisionHalf
  , RocfftArrayType(..)
  , pattern RocfftArrayTypeComplexInterleaved
  , pattern RocfftArrayTypeComplexPlanar
  , pattern RocfftArrayTypeReal
  , pattern RocfftArrayTypeHermitianInterleaved
  , pattern RocfftArrayTypeHermitianPlanar
  , pattern RocfftArrayTypeUnset
  ) where

import Foreign.C.Types (CInt)

newtype RocfftStatus = RocfftStatus {unRocfftStatus :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocfftStatusSuccess :: RocfftStatus
pattern RocfftStatusSuccess = RocfftStatus 0

pattern RocfftStatusFailure :: RocfftStatus
pattern RocfftStatusFailure = RocfftStatus 1

pattern RocfftStatusInvalidArgValue :: RocfftStatus
pattern RocfftStatusInvalidArgValue = RocfftStatus 2

pattern RocfftStatusInvalidDimensions :: RocfftStatus
pattern RocfftStatusInvalidDimensions = RocfftStatus 3

pattern RocfftStatusInvalidArrayType :: RocfftStatus
pattern RocfftStatusInvalidArrayType = RocfftStatus 4

pattern RocfftStatusInvalidStrides :: RocfftStatus
pattern RocfftStatusInvalidStrides = RocfftStatus 5

pattern RocfftStatusInvalidDistance :: RocfftStatus
pattern RocfftStatusInvalidDistance = RocfftStatus 6

pattern RocfftStatusInvalidOffset :: RocfftStatus
pattern RocfftStatusInvalidOffset = RocfftStatus 7

pattern RocfftStatusInvalidWorkBuffer :: RocfftStatus
pattern RocfftStatusInvalidWorkBuffer = RocfftStatus 8

newtype RocfftResultPlacement = RocfftResultPlacement {unRocfftResultPlacement :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocfftPlacementInplace :: RocfftResultPlacement
pattern RocfftPlacementInplace = RocfftResultPlacement 0

pattern RocfftPlacementNotInplace :: RocfftResultPlacement
pattern RocfftPlacementNotInplace = RocfftResultPlacement 1

newtype RocfftTransformType = RocfftTransformType {unRocfftTransformType :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocfftTransformTypeComplexForward :: RocfftTransformType
pattern RocfftTransformTypeComplexForward = RocfftTransformType 0

pattern RocfftTransformTypeComplexInverse :: RocfftTransformType
pattern RocfftTransformTypeComplexInverse = RocfftTransformType 1

pattern RocfftTransformTypeRealForward :: RocfftTransformType
pattern RocfftTransformTypeRealForward = RocfftTransformType 2

pattern RocfftTransformTypeRealInverse :: RocfftTransformType
pattern RocfftTransformTypeRealInverse = RocfftTransformType 3

newtype RocfftPrecision = RocfftPrecision {unRocfftPrecision :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocfftPrecisionSingle :: RocfftPrecision
pattern RocfftPrecisionSingle = RocfftPrecision 0

pattern RocfftPrecisionDouble :: RocfftPrecision
pattern RocfftPrecisionDouble = RocfftPrecision 1

pattern RocfftPrecisionHalf :: RocfftPrecision
pattern RocfftPrecisionHalf = RocfftPrecision 2

newtype RocfftArrayType = RocfftArrayType {unRocfftArrayType :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocfftArrayTypeComplexInterleaved :: RocfftArrayType
pattern RocfftArrayTypeComplexInterleaved = RocfftArrayType 0

pattern RocfftArrayTypeComplexPlanar :: RocfftArrayType
pattern RocfftArrayTypeComplexPlanar = RocfftArrayType 1

pattern RocfftArrayTypeReal :: RocfftArrayType
pattern RocfftArrayTypeReal = RocfftArrayType 2

pattern RocfftArrayTypeHermitianInterleaved :: RocfftArrayType
pattern RocfftArrayTypeHermitianInterleaved = RocfftArrayType 3

pattern RocfftArrayTypeHermitianPlanar :: RocfftArrayType
pattern RocfftArrayTypeHermitianPlanar = RocfftArrayType 4

pattern RocfftArrayTypeUnset :: RocfftArrayType
pattern RocfftArrayTypeUnset = RocfftArrayType 5
