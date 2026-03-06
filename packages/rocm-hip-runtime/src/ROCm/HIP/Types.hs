{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.Types
  ( HipError(..)
  , pattern HipSuccess
  , pattern HipErrorInvalidValue
  , pattern HipErrorNotReady
  , HipHostMallocFlags(..)
  , pattern HipHostMallocDefault
  , pattern HipHostMallocPortable
  , pattern HipHostMallocMapped
  , pattern HipHostMallocWriteCombined
  , pattern HipHostMallocUncached
  , pattern HipHostMallocNumaUser
  , pattern HipHostMallocCoherent
  , pattern HipHostMallocNonCoherent
  , HipMemcpyKind(..)
  , pattern HipMemcpyHostToHost
  , pattern HipMemcpyHostToDevice
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyDeviceToDevice
  , pattern HipMemcpyDefault
  , pattern HipMemcpyDeviceToDeviceNoCU
  ) where

import Data.Bits (Bits)
import Foreign.C.Types (CInt, CUInt)

newtype HipError = HipError {unHipError :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern HipSuccess :: HipError
pattern HipSuccess = HipError 0

pattern HipErrorInvalidValue :: HipError
pattern HipErrorInvalidValue = HipError 1

pattern HipErrorNotReady :: HipError
pattern HipErrorNotReady = HipError 600

newtype HipHostMallocFlags = HipHostMallocFlags {unHipHostMallocFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipHostMallocDefault :: HipHostMallocFlags
pattern HipHostMallocDefault = HipHostMallocFlags 0

pattern HipHostMallocPortable :: HipHostMallocFlags
pattern HipHostMallocPortable = HipHostMallocFlags 0x1

pattern HipHostMallocMapped :: HipHostMallocFlags
pattern HipHostMallocMapped = HipHostMallocFlags 0x2

pattern HipHostMallocWriteCombined :: HipHostMallocFlags
pattern HipHostMallocWriteCombined = HipHostMallocFlags 0x4

pattern HipHostMallocUncached :: HipHostMallocFlags
pattern HipHostMallocUncached = HipHostMallocFlags 0x10000000

pattern HipHostMallocNumaUser :: HipHostMallocFlags
pattern HipHostMallocNumaUser = HipHostMallocFlags 0x20000000

pattern HipHostMallocCoherent :: HipHostMallocFlags
pattern HipHostMallocCoherent = HipHostMallocFlags 0x40000000

pattern HipHostMallocNonCoherent :: HipHostMallocFlags
pattern HipHostMallocNonCoherent = HipHostMallocFlags 0x80000000

newtype HipMemcpyKind = HipMemcpyKind {unHipMemcpyKind :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern HipMemcpyHostToHost :: HipMemcpyKind
pattern HipMemcpyHostToHost = HipMemcpyKind 0

pattern HipMemcpyHostToDevice :: HipMemcpyKind
pattern HipMemcpyHostToDevice = HipMemcpyKind 1

pattern HipMemcpyDeviceToHost :: HipMemcpyKind
pattern HipMemcpyDeviceToHost = HipMemcpyKind 2

pattern HipMemcpyDeviceToDevice :: HipMemcpyKind
pattern HipMemcpyDeviceToDevice = HipMemcpyKind 3

pattern HipMemcpyDefault :: HipMemcpyKind
pattern HipMemcpyDefault = HipMemcpyKind 4

pattern HipMemcpyDeviceToDeviceNoCU :: HipMemcpyKind
pattern HipMemcpyDeviceToDeviceNoCU = HipMemcpyKind 1024

{-# COMPLETE
  HipMemcpyHostToHost
  , HipMemcpyHostToDevice
  , HipMemcpyDeviceToHost
  , HipMemcpyDeviceToDevice
  , HipMemcpyDefault
  , HipMemcpyDeviceToDeviceNoCU
  , HipMemcpyKind
  #-}
