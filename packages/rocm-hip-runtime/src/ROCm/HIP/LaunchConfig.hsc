{-# LANGUAGE CPP #-}
{-# LANGUAGE DerivingStrategies #-}

module ROCm.HIP.LaunchConfig
  ( HipLaunchConfig(..)
  ) where

#include <hip/hip_runtime_api.h>

import Data.Word (Word32)
import Foreign.C.Types (CSize)
import Foreign.Ptr (Ptr, nullPtr)
import Foreign.Storable (Storable(..), peekByteOff, pokeByteOff)
import ROCm.FFI.Core.Types (HipStream(..), HipStreamTag)
import ROCm.HIP.Types (HipDim3)

data HipLaunchConfig = HipLaunchConfig
  { hipLaunchConfigGridDim :: !HipDim3
  , hipLaunchConfigBlockDim :: !HipDim3
  , hipLaunchConfigDynamicSmemBytes :: !CSize
  , hipLaunchConfigStream :: !(Maybe HipStream)
  , hipLaunchConfigAttrs :: !(Ptr ())
  , hipLaunchConfigNumAttrs :: !Word32
  }
  deriving stock (Eq, Show)

instance Storable HipLaunchConfig where
  sizeOf _ = #{size hipLaunchConfig_t}
  alignment _ = #{alignment hipLaunchConfig_t}

  peek p = do
    gridDim <- peekByteOff p #{offset hipLaunchConfig_t, gridDim}
    blockDim <- peekByteOff p #{offset hipLaunchConfig_t, blockDim}
    dynamicSmemBytes <- peekByteOff p #{offset hipLaunchConfig_t, dynamicSmemBytes}
    streamPtr <- peekByteOff p #{offset hipLaunchConfig_t, stream} :: IO (Ptr HipStreamTag)
    attrs <- peekByteOff p #{offset hipLaunchConfig_t, attrs}
    numAttrs <- peekByteOff p #{offset hipLaunchConfig_t, numAttrs}
    pure
      HipLaunchConfig
        { hipLaunchConfigGridDim = gridDim
        , hipLaunchConfigBlockDim = blockDim
        , hipLaunchConfigDynamicSmemBytes = dynamicSmemBytes
        , hipLaunchConfigStream = if streamPtr == nullPtr then Nothing else Just (HipStream streamPtr)
        , hipLaunchConfigAttrs = attrs
        , hipLaunchConfigNumAttrs = numAttrs
        }

  poke p config = do
    pokeByteOff p #{offset hipLaunchConfig_t, gridDim} (hipLaunchConfigGridDim config)
    pokeByteOff p #{offset hipLaunchConfig_t, blockDim} (hipLaunchConfigBlockDim config)
    pokeByteOff p #{offset hipLaunchConfig_t, dynamicSmemBytes} (hipLaunchConfigDynamicSmemBytes config)
    pokeByteOff p #{offset hipLaunchConfig_t, stream} (maybe nullPtr (\(HipStream s) -> s) (hipLaunchConfigStream config) :: Ptr HipStreamTag)
    pokeByteOff p #{offset hipLaunchConfig_t, attrs} (hipLaunchConfigAttrs config)
    pokeByteOff p #{offset hipLaunchConfig_t, numAttrs} (hipLaunchConfigNumAttrs config)
