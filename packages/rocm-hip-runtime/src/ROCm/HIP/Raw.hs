{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.HIP.Raw
  ( c_hipMalloc
  , c_hipFree
  , c_hipHostMalloc
  , c_hipHostFree
  , c_hipHostRegister
  , c_hipHostUnregister
  , c_hipMemcpy
  , c_hipMemcpyAsync
  , c_hipMemcpyWithStream
  , c_hipMemset
  , c_hipMemsetAsync
  , c_hipDeviceSynchronize
  , c_hipDeviceReset
  , c_hipSetDevice
  , c_hipRuntimeGetVersion
  , c_hipDriverGetVersion
  , c_hipStreamCreate
  , c_hipStreamCreateWithFlags
  , c_hipStreamCreateWithPriority
  , c_hipStreamDestroy
  , c_hipStreamQuery
  , c_hipStreamSynchronize
  , c_hipStreamWaitEvent
  , c_hipEventCreate
  , c_hipEventCreateWithFlags
  , c_hipEventDestroy
  , c_hipEventRecord
  , c_hipEventRecordWithFlags
  , c_hipEventSynchronize
  , c_hipEventQuery
  , c_hipEventElapsedTime
  , c_hipStreamAddCallback
  , mkHipStreamCallback
  , c_hipGetDeviceCount
  , c_hipGetDevice
  , c_hipGetDeviceProperties
  , c_hipModuleLoad
  , c_hipModuleLoadData
  , c_hipModuleUnload
  , c_hipModuleGetFunction
  , c_hipModuleLaunchKernel
  , c_hipGraphCreate
  , c_hipGraphDestroy
  , c_hipGraphInstantiate
  , c_hipGraphExecDestroy
  , c_hipGraphLaunch
  , c_hipGraphAddMemcpyNode1D
  , c_hipGetLastError
  , c_hipPeekAtLastError
  , c_hipGetErrorString
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CChar, CFloat(..), CInt(..), CSize(..), CUInt(..))
import Foreign.Ptr (FunPtr, Ptr)
import ROCm.FFI.Core.Types
  ( HipEventTag
  , HipFunctionTag
  , HipGraphExecTag
  , HipGraphNodeTag
  , HipGraphTag
  , HipModuleTag
  , HipStreamTag
  )
import ROCm.HIP.DeviceProp (HipDeviceProp)
import ROCm.HIP.Types
  ( HipError(..)
  , HipEventFlags(..)
  , HipEventRecordFlags(..)
  , HipHostMallocFlags(..)
  , HipHostRegisterFlags(..)
  , HipMemcpyKind(..)
  , HipStreamFlags(..)
  )

type HipStreamCallbackFun = Ptr HipStreamTag -> HipError -> Ptr () -> IO ()

foreign import ccall safe "hipMalloc"
  c_hipMalloc :: Ptr (Ptr ()) -> CSize -> IO HipError

foreign import ccall safe "hipFree"
  c_hipFree :: Ptr () -> IO HipError

foreign import ccall safe "hipHostMalloc"
  c_hipHostMalloc :: Ptr (Ptr ()) -> CSize -> HipHostMallocFlags -> IO HipError

foreign import ccall safe "hipHostFree"
  c_hipHostFree :: Ptr () -> IO HipError

foreign import ccall safe "hipHostRegister"
  c_hipHostRegister :: Ptr () -> CSize -> HipHostRegisterFlags -> IO HipError

foreign import ccall safe "hipHostUnregister"
  c_hipHostUnregister :: Ptr () -> IO HipError

foreign import ccall safe "hipMemcpy"
  c_hipMemcpy :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> IO HipError

foreign import ccall safe "hipMemcpyAsync"
  c_hipMemcpyAsync :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipMemcpyWithStream"
  c_hipMemcpyWithStream :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipMemset"
  c_hipMemset :: Ptr () -> CInt -> CSize -> IO HipError

foreign import ccall safe "hipMemsetAsync"
  c_hipMemsetAsync :: Ptr () -> CInt -> CSize -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipDeviceSynchronize"
  c_hipDeviceSynchronize :: IO HipError

foreign import ccall safe "hipDeviceReset"
  c_hipDeviceReset :: IO HipError

foreign import ccall safe "hipSetDevice"
  c_hipSetDevice :: CInt -> IO HipError

foreign import ccall unsafe "hipRuntimeGetVersion"
  c_hipRuntimeGetVersion :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipDriverGetVersion"
  c_hipDriverGetVersion :: Ptr CInt -> IO HipError

foreign import ccall safe "hipStreamCreate"
  c_hipStreamCreate :: Ptr (Ptr HipStreamTag) -> IO HipError

foreign import ccall safe "hipStreamCreateWithFlags"
  c_hipStreamCreateWithFlags :: Ptr (Ptr HipStreamTag) -> HipStreamFlags -> IO HipError

foreign import ccall safe "hipStreamCreateWithPriority"
  c_hipStreamCreateWithPriority :: Ptr (Ptr HipStreamTag) -> HipStreamFlags -> CInt -> IO HipError

foreign import ccall safe "hipStreamDestroy"
  c_hipStreamDestroy :: Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipStreamQuery"
  c_hipStreamQuery :: Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipStreamSynchronize"
  c_hipStreamSynchronize :: Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipStreamWaitEvent"
  c_hipStreamWaitEvent :: Ptr HipStreamTag -> Ptr HipEventTag -> CUInt -> IO HipError

foreign import ccall safe "hipEventCreate"
  c_hipEventCreate :: Ptr (Ptr HipEventTag) -> IO HipError

foreign import ccall safe "hipEventCreateWithFlags"
  c_hipEventCreateWithFlags :: Ptr (Ptr HipEventTag) -> HipEventFlags -> IO HipError

foreign import ccall safe "hipEventDestroy"
  c_hipEventDestroy :: Ptr HipEventTag -> IO HipError

foreign import ccall safe "hipEventRecord"
  c_hipEventRecord :: Ptr HipEventTag -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipEventRecordWithFlags"
  c_hipEventRecordWithFlags :: Ptr HipEventTag -> Ptr HipStreamTag -> HipEventRecordFlags -> IO HipError

foreign import ccall safe "hipEventSynchronize"
  c_hipEventSynchronize :: Ptr HipEventTag -> IO HipError

foreign import ccall safe "hipEventQuery"
  c_hipEventQuery :: Ptr HipEventTag -> IO HipError

foreign import ccall safe "hipEventElapsedTime"
  c_hipEventElapsedTime :: Ptr CFloat -> Ptr HipEventTag -> Ptr HipEventTag -> IO HipError

foreign import ccall safe "hipStreamAddCallback"
  c_hipStreamAddCallback :: Ptr HipStreamTag -> FunPtr HipStreamCallbackFun -> Ptr () -> CUInt -> IO HipError

foreign import ccall "wrapper"
  mkHipStreamCallback :: HipStreamCallbackFun -> IO (FunPtr HipStreamCallbackFun)

foreign import ccall unsafe "hipGetDeviceCount"
  c_hipGetDeviceCount :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipGetDevice"
  c_hipGetDevice :: Ptr CInt -> IO HipError

foreign import ccall safe "hipGetDevicePropertiesR0600"
  c_hipGetDeviceProperties :: Ptr HipDeviceProp -> CInt -> IO HipError

foreign import ccall safe "hipModuleLoad"
  c_hipModuleLoad :: Ptr (Ptr HipModuleTag) -> CString -> IO HipError

foreign import ccall safe "hipModuleLoadData"
  c_hipModuleLoadData :: Ptr (Ptr HipModuleTag) -> Ptr () -> IO HipError

foreign import ccall safe "hipModuleUnload"
  c_hipModuleUnload :: Ptr HipModuleTag -> IO HipError

foreign import ccall safe "hipModuleGetFunction"
  c_hipModuleGetFunction :: Ptr (Ptr HipFunctionTag) -> Ptr HipModuleTag -> CString -> IO HipError

foreign import ccall safe "hipModuleLaunchKernel"
  c_hipModuleLaunchKernel ::
    Ptr HipFunctionTag ->
    CUInt ->
    CUInt ->
    CUInt ->
    CUInt ->
    CUInt ->
    CUInt ->
    CUInt ->
    Ptr HipStreamTag ->
    Ptr (Ptr ()) ->
    Ptr (Ptr ()) ->
    IO HipError

foreign import ccall safe "hipGraphCreate"
  c_hipGraphCreate :: Ptr (Ptr HipGraphTag) -> CUInt -> IO HipError

foreign import ccall safe "hipGraphDestroy"
  c_hipGraphDestroy :: Ptr HipGraphTag -> IO HipError

foreign import ccall safe "hipGraphInstantiate"
  c_hipGraphInstantiate ::
    Ptr (Ptr HipGraphExecTag) ->
    Ptr HipGraphTag ->
    Ptr (Ptr HipGraphNodeTag) ->
    Ptr CChar ->
    CSize ->
    IO HipError

foreign import ccall safe "hipGraphExecDestroy"
  c_hipGraphExecDestroy :: Ptr HipGraphExecTag -> IO HipError

foreign import ccall safe "hipGraphLaunch"
  c_hipGraphLaunch :: Ptr HipGraphExecTag -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipGraphAddMemcpyNode1D"
  c_hipGraphAddMemcpyNode1D ::
    Ptr (Ptr HipGraphNodeTag) ->
    Ptr HipGraphTag ->
    Ptr (Ptr HipGraphNodeTag) ->
    CSize ->
    Ptr () ->
    Ptr () ->
    CSize ->
    HipMemcpyKind ->
    IO HipError

foreign import ccall unsafe "hipGetLastError"
  c_hipGetLastError :: IO HipError

foreign import ccall unsafe "hipPeekAtLastError"
  c_hipPeekAtLastError :: IO HipError

foreign import ccall unsafe "hipGetErrorString"
  c_hipGetErrorString :: HipError -> IO CString
