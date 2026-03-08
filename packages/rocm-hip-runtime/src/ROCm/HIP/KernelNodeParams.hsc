{-# LANGUAGE CPP #-}
{-# LANGUAGE DerivingStrategies #-}

module ROCm.HIP.KernelNodeParams
  ( HipKernelNodeParams(..)
  ) where

#include <hip/hip_runtime_api.h>

import Data.Word (Word32)
import Foreign.Ptr (Ptr)
import Foreign.Storable (Storable(..), peekByteOff, pokeByteOff)
import ROCm.HIP.Types (HipDim3, HipFunctionAddress)

data HipKernelNodeParams = HipKernelNodeParams
  { hipKernelNodeBlockDim :: !HipDim3
  , hipKernelNodeExtra :: !(Ptr (Ptr ()))
  , hipKernelNodeFunc :: !HipFunctionAddress
  , hipKernelNodeGridDim :: !HipDim3
  , hipKernelNodeKernelParams :: !(Ptr (Ptr ()))
  , hipKernelNodeSharedMemBytes :: !Word32
  }
  deriving stock (Eq, Show)

instance Storable HipKernelNodeParams where
  sizeOf _ = #{size hipKernelNodeParams}
  alignment _ = #{alignment hipKernelNodeParams}

  peek p = do
    blockDim <- peekByteOff p #{offset hipKernelNodeParams, blockDim}
    extra <- peekByteOff p #{offset hipKernelNodeParams, extra}
    func <- peekByteOff p #{offset hipKernelNodeParams, func}
    gridDim <- peekByteOff p #{offset hipKernelNodeParams, gridDim}
    kernelParams <- peekByteOff p #{offset hipKernelNodeParams, kernelParams}
    sharedMemBytes <- peekByteOff p #{offset hipKernelNodeParams, sharedMemBytes}
    pure
      HipKernelNodeParams
        { hipKernelNodeBlockDim = blockDim
        , hipKernelNodeExtra = extra
        , hipKernelNodeFunc = func
        , hipKernelNodeGridDim = gridDim
        , hipKernelNodeKernelParams = kernelParams
        , hipKernelNodeSharedMemBytes = sharedMemBytes
        }

  poke p params = do
    pokeByteOff p #{offset hipKernelNodeParams, blockDim} (hipKernelNodeBlockDim params)
    pokeByteOff p #{offset hipKernelNodeParams, extra} (hipKernelNodeExtra params)
    pokeByteOff p #{offset hipKernelNodeParams, func} (hipKernelNodeFunc params)
    pokeByteOff p #{offset hipKernelNodeParams, gridDim} (hipKernelNodeGridDim params)
    pokeByteOff p #{offset hipKernelNodeParams, kernelParams} (hipKernelNodeKernelParams params)
    pokeByteOff p #{offset hipKernelNodeParams, sharedMemBytes} (hipKernelNodeSharedMemBytes params)
