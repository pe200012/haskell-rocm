module ROCm.FFI.Core.Types
  ( -- * HIP
    HipStreamTag
  , HipStream(..)
  , HipEventTag
  , HipEvent(..)

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
  deriving (Eq, Ord, Show)

data HipEventTag
newtype HipEvent = HipEvent (Ptr HipEventTag)
  deriving (Eq, Ord, Show)

-- Pointer wrappers -----------------------------------------------------------

newtype DevicePtr a = DevicePtr (Ptr a)
  deriving (Eq, Ord, Show)

newtype HostPtr a = HostPtr (Ptr a)
  deriving (Eq, Ord, Show)

newtype PinnedHostPtr a = PinnedHostPtr (Ptr a)
  deriving (Eq, Ord, Show)

-- rocBLAS --------------------------------------------------------------------

data RocblasHandleTag
newtype RocblasHandle = RocblasHandle (Ptr RocblasHandleTag)
  deriving (Eq, Ord, Show)

-- rocRAND --------------------------------------------------------------------

data RocRandGeneratorTag
newtype RocRandGenerator = RocRandGenerator (Ptr RocRandGeneratorTag)
  deriving (Eq, Ord, Show)

-- rocSPARSE ------------------------------------------------------------------

data RocsparseHandleTag
newtype RocsparseHandle = RocsparseHandle (Ptr RocsparseHandleTag)
  deriving (Eq, Ord, Show)

data RocsparseMatDescrTag
newtype RocsparseMatDescr = RocsparseMatDescr (Ptr RocsparseMatDescrTag)
  deriving (Eq, Ord, Show)

-- rocFFT ---------------------------------------------------------------------

data RocfftPlanTag
newtype RocfftPlan = RocfftPlan (Ptr RocfftPlanTag)
  deriving (Eq, Ord, Show)

data RocfftPlanDescriptionTag
newtype RocfftPlanDescription = RocfftPlanDescription (Ptr RocfftPlanDescriptionTag)
  deriving (Eq, Ord, Show)

data RocfftExecInfoTag
newtype RocfftExecInfo = RocfftExecInfo (Ptr RocfftExecInfoTag)
  deriving (Eq, Ord, Show)
