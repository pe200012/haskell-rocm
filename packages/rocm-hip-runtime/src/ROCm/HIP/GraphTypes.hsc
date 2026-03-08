{-# LANGUAGE CPP #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.GraphTypes
  ( HipHostNodeFun
  , HipHostNodeParams(..)
  , HipMemsetParams(..)
  , HipStreamCaptureMode(..)
  , pattern HipStreamCaptureModeGlobal
  , pattern HipStreamCaptureModeThreadLocal
  , pattern HipStreamCaptureModeRelaxed
  , HipStreamCaptureStatus(..)
  , pattern HipStreamCaptureStatusNone
  , pattern HipStreamCaptureStatusActive
  , pattern HipStreamCaptureStatusInvalidated
  , HipGraphInstantiateFlags(..)
  , pattern HipGraphInstantiateFlagAutoFreeOnLaunch
  , pattern HipGraphInstantiateFlagUpload
  , pattern HipGraphInstantiateFlagDeviceLaunch
  , pattern HipGraphInstantiateFlagUseNodePriority
  , HipGraphExecUpdateResult(..)
  , pattern HipGraphExecUpdateSuccess
  , pattern HipGraphExecUpdateError
  , pattern HipGraphExecUpdateErrorTopologyChanged
  , pattern HipGraphExecUpdateErrorNodeTypeChanged
  , pattern HipGraphExecUpdateErrorFunctionChanged
  , pattern HipGraphExecUpdateErrorParametersChanged
  , pattern HipGraphExecUpdateErrorNotSupported
  , pattern HipGraphExecUpdateErrorUnsupportedFunctionChange
  , HipGraphDebugDotFlags(..)
  , pattern HipGraphDebugDotFlagsVerbose
  , pattern HipGraphDebugDotFlagsKernelNodeParams
  , pattern HipGraphDebugDotFlagsMemcpyNodeParams
  , pattern HipGraphDebugDotFlagsMemsetNodeParams
  , pattern HipGraphDebugDotFlagsHostNodeParams
  , pattern HipGraphDebugDotFlagsEventNodeParams
  , pattern HipGraphDebugDotFlagsExtSemasSignalNodeParams
  , pattern HipGraphDebugDotFlagsExtSemasWaitNodeParams
  , pattern HipGraphDebugDotFlagsKernelNodeAttributes
  , pattern HipGraphDebugDotFlagsHandles
  , HipGraphExecUpdateInfo(..)
  ) where

#include <hip/hip_runtime_api.h>

import Data.Bits (Bits)
import Data.Word (Word32, Word64)
import Foreign.C.Types (CInt, CUInt, CSize)
import Foreign.Ptr (FunPtr, Ptr)
import Foreign.Storable (Storable(..), peekByteOff, pokeByteOff)
import ROCm.FFI.Core.Types (HipGraphNode)

type HipHostNodeFun = Ptr () -> IO ()

data HipHostNodeParams = HipHostNodeParams
  { hipHostNodeFn :: !(FunPtr HipHostNodeFun)
  , hipHostNodeUserData :: !(Ptr ())
  }
  deriving stock (Eq, Show)

instance Storable HipHostNodeParams where
  sizeOf _ = #{size hipHostNodeParams}
  alignment _ = #{alignment hipHostNodeParams}

  peek p = do
    fn <- peekByteOff p #{offset hipHostNodeParams, fn}
    userData <- peekByteOff p #{offset hipHostNodeParams, userData}
    pure HipHostNodeParams {hipHostNodeFn = fn, hipHostNodeUserData = userData}

  poke p params = do
    pokeByteOff p #{offset hipHostNodeParams, fn} (hipHostNodeFn params)
    pokeByteOff p #{offset hipHostNodeParams, userData} (hipHostNodeUserData params)

data HipMemsetParams = HipMemsetParams
  { hipMemsetDst :: !(Ptr ())
  , hipMemsetElementSize :: !Word32
  , hipMemsetHeight :: !CSize
  , hipMemsetPitch :: !CSize
  , hipMemsetValue :: !Word32
  , hipMemsetWidth :: !CSize
  }
  deriving stock (Eq, Show)

instance Storable HipMemsetParams where
  sizeOf _ = #{size hipMemsetParams}
  alignment _ = #{alignment hipMemsetParams}

  peek p = do
    dst <- peekByteOff p #{offset hipMemsetParams, dst}
    elementSize <- peekByteOff p #{offset hipMemsetParams, elementSize}
    height <- peekByteOff p #{offset hipMemsetParams, height}
    pitch <- peekByteOff p #{offset hipMemsetParams, pitch}
    value <- peekByteOff p #{offset hipMemsetParams, value}
    width <- peekByteOff p #{offset hipMemsetParams, width}
    pure
      HipMemsetParams
        { hipMemsetDst = dst
        , hipMemsetElementSize = elementSize
        , hipMemsetHeight = height
        , hipMemsetPitch = pitch
        , hipMemsetValue = value
        , hipMemsetWidth = width
        }

  poke p params = do
    pokeByteOff p #{offset hipMemsetParams, dst} (hipMemsetDst params)
    pokeByteOff p #{offset hipMemsetParams, elementSize} (hipMemsetElementSize params)
    pokeByteOff p #{offset hipMemsetParams, height} (hipMemsetHeight params)
    pokeByteOff p #{offset hipMemsetParams, pitch} (hipMemsetPitch params)
    pokeByteOff p #{offset hipMemsetParams, value} (hipMemsetValue params)
    pokeByteOff p #{offset hipMemsetParams, width} (hipMemsetWidth params)

newtype HipStreamCaptureMode = HipStreamCaptureMode {unHipStreamCaptureMode :: CInt}
  deriving newtype (Eq, Ord, Show)

pattern HipStreamCaptureModeGlobal :: HipStreamCaptureMode
pattern HipStreamCaptureModeGlobal = HipStreamCaptureMode #{const hipStreamCaptureModeGlobal}

pattern HipStreamCaptureModeThreadLocal :: HipStreamCaptureMode
pattern HipStreamCaptureModeThreadLocal = HipStreamCaptureMode #{const hipStreamCaptureModeThreadLocal}

pattern HipStreamCaptureModeRelaxed :: HipStreamCaptureMode
pattern HipStreamCaptureModeRelaxed = HipStreamCaptureMode #{const hipStreamCaptureModeRelaxed}

newtype HipStreamCaptureStatus = HipStreamCaptureStatus {unHipStreamCaptureStatus :: CInt}
  deriving newtype (Eq, Ord, Show, Storable)

pattern HipStreamCaptureStatusNone :: HipStreamCaptureStatus
pattern HipStreamCaptureStatusNone = HipStreamCaptureStatus #{const hipStreamCaptureStatusNone}

pattern HipStreamCaptureStatusActive :: HipStreamCaptureStatus
pattern HipStreamCaptureStatusActive = HipStreamCaptureStatus #{const hipStreamCaptureStatusActive}

pattern HipStreamCaptureStatusInvalidated :: HipStreamCaptureStatus
pattern HipStreamCaptureStatusInvalidated = HipStreamCaptureStatus #{const hipStreamCaptureStatusInvalidated}

newtype HipGraphInstantiateFlags = HipGraphInstantiateFlags {unHipGraphInstantiateFlags :: Word64}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipGraphInstantiateFlagAutoFreeOnLaunch :: HipGraphInstantiateFlags
pattern HipGraphInstantiateFlagAutoFreeOnLaunch = HipGraphInstantiateFlags #{const hipGraphInstantiateFlagAutoFreeOnLaunch}

pattern HipGraphInstantiateFlagUpload :: HipGraphInstantiateFlags
pattern HipGraphInstantiateFlagUpload = HipGraphInstantiateFlags #{const hipGraphInstantiateFlagUpload}

pattern HipGraphInstantiateFlagDeviceLaunch :: HipGraphInstantiateFlags
pattern HipGraphInstantiateFlagDeviceLaunch = HipGraphInstantiateFlags #{const hipGraphInstantiateFlagDeviceLaunch}

pattern HipGraphInstantiateFlagUseNodePriority :: HipGraphInstantiateFlags
pattern HipGraphInstantiateFlagUseNodePriority = HipGraphInstantiateFlags #{const hipGraphInstantiateFlagUseNodePriority}

newtype HipGraphExecUpdateResult = HipGraphExecUpdateResult {unHipGraphExecUpdateResult :: CInt}
  deriving newtype (Eq, Ord, Show, Storable)

pattern HipGraphExecUpdateSuccess :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateSuccess = HipGraphExecUpdateResult #{const hipGraphExecUpdateSuccess}

pattern HipGraphExecUpdateError :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateError = HipGraphExecUpdateResult #{const hipGraphExecUpdateError}

pattern HipGraphExecUpdateErrorTopologyChanged :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorTopologyChanged = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorTopologyChanged}

pattern HipGraphExecUpdateErrorNodeTypeChanged :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorNodeTypeChanged = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorNodeTypeChanged}

pattern HipGraphExecUpdateErrorFunctionChanged :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorFunctionChanged = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorFunctionChanged}

pattern HipGraphExecUpdateErrorParametersChanged :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorParametersChanged = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorParametersChanged}

pattern HipGraphExecUpdateErrorNotSupported :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorNotSupported = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorNotSupported}

pattern HipGraphExecUpdateErrorUnsupportedFunctionChange :: HipGraphExecUpdateResult
pattern HipGraphExecUpdateErrorUnsupportedFunctionChange = HipGraphExecUpdateResult #{const hipGraphExecUpdateErrorUnsupportedFunctionChange}

newtype HipGraphDebugDotFlags = HipGraphDebugDotFlags {unHipGraphDebugDotFlags :: CUInt}
  deriving newtype (Eq, Ord, Show, Bits)

pattern HipGraphDebugDotFlagsVerbose :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsVerbose = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsVerbose}

pattern HipGraphDebugDotFlagsKernelNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsKernelNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsKernelNodeParams}

pattern HipGraphDebugDotFlagsMemcpyNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsMemcpyNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsMemcpyNodeParams}

pattern HipGraphDebugDotFlagsMemsetNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsMemsetNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsMemsetNodeParams}

pattern HipGraphDebugDotFlagsHostNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsHostNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsHostNodeParams}

pattern HipGraphDebugDotFlagsEventNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsEventNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsEventNodeParams}

pattern HipGraphDebugDotFlagsExtSemasSignalNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsExtSemasSignalNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsExtSemasSignalNodeParams}

pattern HipGraphDebugDotFlagsExtSemasWaitNodeParams :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsExtSemasWaitNodeParams = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsExtSemasWaitNodeParams}

pattern HipGraphDebugDotFlagsKernelNodeAttributes :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsKernelNodeAttributes = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsKernelNodeAttributes}

pattern HipGraphDebugDotFlagsHandles :: HipGraphDebugDotFlags
pattern HipGraphDebugDotFlagsHandles = HipGraphDebugDotFlags #{const hipGraphDebugDotFlagsHandles}

data HipGraphExecUpdateInfo = HipGraphExecUpdateInfo
  { hipGraphExecUpdateErrorNode :: !(Maybe HipGraphNode)
  , hipGraphExecUpdateResult :: !HipGraphExecUpdateResult
  }
  deriving stock (Eq, Show)
