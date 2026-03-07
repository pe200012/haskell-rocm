{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module ROCm.FFI.Core.Types
  ( -- * HIP
    HipStreamTag
  , HipStream(..)
  , HipEventTag
  , HipEvent(..)
  , HipModuleTag
  , HipModule(..)
  , HipFunctionTag
  , HipFunction(..)
  , HipGraphTag
  , HipGraph(..)
  , HipGraphNodeTag
  , HipGraphNode(..)
  , HipGraphExecTag
  , HipGraphExec(..)

    -- * Pointer wrappers
  , DevicePtr(..)
  , HostPtr(..)
  , PinnedHostPtr(..)

    -- * rocBLAS
  , RocblasHandleTag
  , RocblasHandle(..)

    -- * rocRAND
  , RocRandGeneratorTag
  , RocRandGenerator(..)

    -- * rocSPARSE
  , RocsparseHandleTag
  , RocsparseHandle(..)
  , RocsparseMatDescrTag
  , RocsparseMatDescr(..)
  , RocsparseSpMatDescrTag
  , RocsparseSpMatDescr(..)
  , RocsparseDnVecDescrTag
  , RocsparseDnVecDescr(..)
  , RocsparseSpMVDescrTag
  , RocsparseSpMVDescr(..)

    -- * rocFFT
  , RocfftPlanTag
  , RocfftPlan(..)
  , RocfftPlanDescriptionTag
  , RocfftPlanDescription(..)
  , RocfftExecInfoTag
  , RocfftExecInfo(..)
  ) where

import Foreign.Ptr (Ptr)

-- HIP -----------------------------------------------------------------------

data HipStreamTag
newtype HipStream = HipStream (Ptr HipStreamTag)
  deriving newtype (Eq, Ord, Show)

data HipEventTag
newtype HipEvent = HipEvent (Ptr HipEventTag)
  deriving newtype (Eq, Ord, Show)

data HipModuleTag
newtype HipModule = HipModule (Ptr HipModuleTag)
  deriving newtype (Eq, Ord, Show)

data HipFunctionTag
newtype HipFunction = HipFunction (Ptr HipFunctionTag)
  deriving newtype (Eq, Ord, Show)

data HipGraphTag
newtype HipGraph = HipGraph (Ptr HipGraphTag)
  deriving newtype (Eq, Ord, Show)

data HipGraphNodeTag
newtype HipGraphNode = HipGraphNode (Ptr HipGraphNodeTag)
  deriving newtype (Eq, Ord, Show)

data HipGraphExecTag
newtype HipGraphExec = HipGraphExec (Ptr HipGraphExecTag)
  deriving newtype (Eq, Ord, Show)

-- Pointer wrappers -----------------------------------------------------------

newtype DevicePtr a = DevicePtr (Ptr a)
  deriving newtype (Eq, Ord, Show)

newtype HostPtr a = HostPtr (Ptr a)
  deriving newtype (Eq, Ord, Show)

newtype PinnedHostPtr a = PinnedHostPtr (Ptr a)
  deriving newtype (Eq, Ord, Show)

-- rocBLAS --------------------------------------------------------------------

data RocblasHandleTag
newtype RocblasHandle = RocblasHandle (Ptr RocblasHandleTag)
  deriving newtype (Eq, Ord, Show)

-- rocRAND --------------------------------------------------------------------

data RocRandGeneratorTag
newtype RocRandGenerator = RocRandGenerator (Ptr RocRandGeneratorTag)
  deriving newtype (Eq, Ord, Show)

-- rocSPARSE ------------------------------------------------------------------

data RocsparseHandleTag
newtype RocsparseHandle = RocsparseHandle (Ptr RocsparseHandleTag)
  deriving newtype (Eq, Ord, Show)

data RocsparseMatDescrTag
newtype RocsparseMatDescr = RocsparseMatDescr (Ptr RocsparseMatDescrTag)
  deriving newtype (Eq, Ord, Show)

data RocsparseSpMatDescrTag
newtype RocsparseSpMatDescr = RocsparseSpMatDescr (Ptr RocsparseSpMatDescrTag)
  deriving newtype (Eq, Ord, Show)

data RocsparseDnVecDescrTag
newtype RocsparseDnVecDescr = RocsparseDnVecDescr (Ptr RocsparseDnVecDescrTag)
  deriving newtype (Eq, Ord, Show)

data RocsparseSpMVDescrTag
newtype RocsparseSpMVDescr = RocsparseSpMVDescr (Ptr RocsparseSpMVDescrTag)
  deriving newtype (Eq, Ord, Show)

-- rocFFT ---------------------------------------------------------------------

data RocfftPlanTag
newtype RocfftPlan = RocfftPlan (Ptr RocfftPlanTag)
  deriving newtype (Eq, Ord, Show)

data RocfftPlanDescriptionTag
newtype RocfftPlanDescription = RocfftPlanDescription (Ptr RocfftPlanDescriptionTag)
  deriving newtype (Eq, Ord, Show)

data RocfftExecInfoTag
newtype RocfftExecInfo = RocfftExecInfo (Ptr RocfftExecInfoTag)
  deriving newtype (Eq, Ord, Show)
