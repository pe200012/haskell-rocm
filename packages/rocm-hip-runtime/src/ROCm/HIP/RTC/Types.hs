{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.RTC.Types
  ( HiprtcResult(..)
  , pattern HiprtcSuccess
  , HiprtcProgramTag
  , HiprtcProgram(..)
  ) where

import Foreign.C.Types (CInt)
import Foreign.Ptr (Ptr)

newtype HiprtcResult = HiprtcResult {unHiprtcResult :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern HiprtcSuccess :: HiprtcResult
pattern HiprtcSuccess = HiprtcResult 0

data HiprtcProgramTag
newtype HiprtcProgram = HiprtcProgram (Ptr HiprtcProgramTag)
  deriving newtype (Eq, Ord, Show)
