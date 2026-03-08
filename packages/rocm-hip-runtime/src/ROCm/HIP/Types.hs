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
  , HipHostRegisterFlags(..)
  , pattern HipHostRegisterDefault
  , pattern HipHostRegisterPortable
  , pattern HipHostRegisterMapped
  , pattern HipHostRegisterIoMemory
  , pattern HipHostRegisterReadOnly
  , HipStreamFlags(..)
  , pattern HipStreamDefault
  , pattern HipStreamNonBlocking
  , HipEventFlags(..)
  , pattern HipEventDefault
  , pattern HipEventBlockingSync
  , pattern HipEventDisableTiming
  , pattern HipEventInterprocess
  , HipEventRecordFlags(..)
  , pattern HipEventRecordDefault
  , pattern HipEventRecordExternal
  , HipMemcpyKind(..)
  , pattern HipMemcpyHostToHost
  , HipFunctionAddress(..)
  , HipDim3(..)
  , pattern HipMemcpyHostToDevice
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyDeviceToDevice
  , pattern HipMemcpyDefault
  , pattern HipMemcpyDeviceToDeviceNoCU
  ) where

import Data.Bits (Bits)
import Data.Word (Word32)
import Foreign.C.Types (CInt, CUInt)
import Foreign.Ptr (Ptr)
import Foreign.Storable (Storable(..), peekByteOff, pokeByteOff)

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

newtype HipHostRegisterFlags = HipHostRegisterFlags {unHipHostRegisterFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipHostRegisterDefault :: HipHostRegisterFlags
pattern HipHostRegisterDefault = HipHostRegisterFlags 0x0

pattern HipHostRegisterPortable :: HipHostRegisterFlags
pattern HipHostRegisterPortable = HipHostRegisterFlags 0x1

pattern HipHostRegisterMapped :: HipHostRegisterFlags
pattern HipHostRegisterMapped = HipHostRegisterFlags 0x2

pattern HipHostRegisterIoMemory :: HipHostRegisterFlags
pattern HipHostRegisterIoMemory = HipHostRegisterFlags 0x4

pattern HipHostRegisterReadOnly :: HipHostRegisterFlags
pattern HipHostRegisterReadOnly = HipHostRegisterFlags 0x08

newtype HipStreamFlags = HipStreamFlags {unHipStreamFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipStreamDefault :: HipStreamFlags
pattern HipStreamDefault = HipStreamFlags 0x00

pattern HipStreamNonBlocking :: HipStreamFlags
pattern HipStreamNonBlocking = HipStreamFlags 0x01

newtype HipEventFlags = HipEventFlags {unHipEventFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipEventDefault :: HipEventFlags
pattern HipEventDefault = HipEventFlags 0x0

pattern HipEventBlockingSync :: HipEventFlags
pattern HipEventBlockingSync = HipEventFlags 0x1

pattern HipEventDisableTiming :: HipEventFlags
pattern HipEventDisableTiming = HipEventFlags 0x2

pattern HipEventInterprocess :: HipEventFlags
pattern HipEventInterprocess = HipEventFlags 0x4

newtype HipEventRecordFlags = HipEventRecordFlags {unHipEventRecordFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipEventRecordDefault :: HipEventRecordFlags
pattern HipEventRecordDefault = HipEventRecordFlags 0x00

pattern HipEventRecordExternal :: HipEventRecordFlags
pattern HipEventRecordExternal = HipEventRecordFlags 0x01

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

newtype HipFunctionAddress = HipFunctionAddress {unHipFunctionAddress :: Ptr ()}
  deriving newtype (Eq, Ord, Show, Storable)

{-# COMPLETE
  HipMemcpyHostToHost
  , HipMemcpyHostToDevice
  , HipMemcpyDeviceToHost
  , HipMemcpyDeviceToDevice
  , HipMemcpyDefault
  , HipMemcpyDeviceToDeviceNoCU
  , HipMemcpyKind
  #-}

data HipDim3 = HipDim3
  { hipDim3X :: !Word32
  , hipDim3Y :: !Word32
  , hipDim3Z :: !Word32
  }
  deriving stock (Eq, Ord, Show)

instance Storable HipDim3 where
  sizeOf _ = 12
  alignment _ = alignment (undefined :: Word32)

  peek p = do
    x <- peekByteOff p 0
    y <- peekByteOff p 4
    z <- peekByteOff p 8
    pure (HipDim3 x y z)

  poke p (HipDim3 x y z) = do
    pokeByteOff p 0 x
    pokeByteOff p 4 y
    pokeByteOff p 8 z
