{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocSPARSE.Types
  ( RocsparseStatus(..)
  , pattern RocsparseStatusSuccess
  , pattern RocsparseStatusInvalidHandle
  , pattern RocsparseStatusNotImplemented
  , pattern RocsparseStatusInvalidPointer
  , pattern RocsparseStatusInvalidSize
  , pattern RocsparseStatusMemoryError
  , pattern RocsparseStatusInternalError
  , pattern RocsparseStatusInvalidValue
  , pattern RocsparseStatusArchMismatch
  , pattern RocsparseStatusNotInitialized
  , RocsparseOperation(..)
  , pattern RocsparseOperationNone
  , pattern RocsparseOperationTranspose
  , pattern RocsparseOperationConjugateTranspose
  , RocsparseIndexBase(..)
  , pattern RocsparseIndexBaseZero
  , pattern RocsparseIndexBaseOne
  , RocsparseMatrixType(..)
  , pattern RocsparseMatrixTypeGeneral
  , pattern RocsparseMatrixTypeSymmetric
  , pattern RocsparseMatrixTypeHermitian
  , pattern RocsparseMatrixTypeTriangular
  ) where

import Foreign.C.Types (CInt)

newtype RocsparseStatus = RocsparseStatus {unRocsparseStatus :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocsparseStatusSuccess :: RocsparseStatus
pattern RocsparseStatusSuccess = RocsparseStatus 0

pattern RocsparseStatusInvalidHandle :: RocsparseStatus
pattern RocsparseStatusInvalidHandle = RocsparseStatus 1

pattern RocsparseStatusNotImplemented :: RocsparseStatus
pattern RocsparseStatusNotImplemented = RocsparseStatus 2

pattern RocsparseStatusInvalidPointer :: RocsparseStatus
pattern RocsparseStatusInvalidPointer = RocsparseStatus 3

pattern RocsparseStatusInvalidSize :: RocsparseStatus
pattern RocsparseStatusInvalidSize = RocsparseStatus 4

pattern RocsparseStatusMemoryError :: RocsparseStatus
pattern RocsparseStatusMemoryError = RocsparseStatus 5

pattern RocsparseStatusInternalError :: RocsparseStatus
pattern RocsparseStatusInternalError = RocsparseStatus 6

pattern RocsparseStatusInvalidValue :: RocsparseStatus
pattern RocsparseStatusInvalidValue = RocsparseStatus 7

pattern RocsparseStatusArchMismatch :: RocsparseStatus
pattern RocsparseStatusArchMismatch = RocsparseStatus 8

pattern RocsparseStatusNotInitialized :: RocsparseStatus
pattern RocsparseStatusNotInitialized = RocsparseStatus 10

newtype RocsparseOperation = RocsparseOperation {unRocsparseOperation :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocsparseOperationNone :: RocsparseOperation
pattern RocsparseOperationNone = RocsparseOperation 111

pattern RocsparseOperationTranspose :: RocsparseOperation
pattern RocsparseOperationTranspose = RocsparseOperation 112

pattern RocsparseOperationConjugateTranspose :: RocsparseOperation
pattern RocsparseOperationConjugateTranspose = RocsparseOperation 113

newtype RocsparseIndexBase = RocsparseIndexBase {unRocsparseIndexBase :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocsparseIndexBaseZero :: RocsparseIndexBase
pattern RocsparseIndexBaseZero = RocsparseIndexBase 0

pattern RocsparseIndexBaseOne :: RocsparseIndexBase
pattern RocsparseIndexBaseOne = RocsparseIndexBase 1

newtype RocsparseMatrixType = RocsparseMatrixType {unRocsparseMatrixType :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern RocsparseMatrixTypeGeneral :: RocsparseMatrixType
pattern RocsparseMatrixTypeGeneral = RocsparseMatrixType 0

pattern RocsparseMatrixTypeSymmetric :: RocsparseMatrixType
pattern RocsparseMatrixTypeSymmetric = RocsparseMatrixType 1

pattern RocsparseMatrixTypeHermitian :: RocsparseMatrixType
pattern RocsparseMatrixTypeHermitian = RocsparseMatrixType 2

pattern RocsparseMatrixTypeTriangular :: RocsparseMatrixType
pattern RocsparseMatrixTypeTriangular = RocsparseMatrixType 3
