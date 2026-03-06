{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.HIP.Raw
  ( c_hipMalloc
  , c_hipFree
  , c_hipHostMalloc
  , c_hipHostFree
  , c_hipMemcpy
  , c_hipMemcpyAsync
  , c_hipMemcpyWithStream
  , c_hipDeviceSynchronize
  , c_hipStreamCreate
  , c_hipStreamDestroy
  , c_hipStreamSynchronize
  , c_hipEventCreate
  , c_hipEventDestroy
  , c_hipEventRecord
  , c_hipEventSynchronize
  , c_hipEventQuery
  , c_hipEventElapsedTime
  , c_hipStreamAddCallback
  , mkHipStreamCallback
  , c_hipGetDeviceCount
  , c_hipGetDevice
  , c_hipGetDeviceProperties
  , c_hipGetLastError
  , c_hipPeekAtLastError
  , c_hipGetErrorString
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CFloat(..), CInt(..), CSize(..), CUInt(..))
import Foreign.Ptr (FunPtr, Ptr)
import ROCm.FFI.Core.Types (HipEventTag, HipStreamTag)
import ROCm.HIP.DeviceProp (HipDeviceProp)
import ROCm.HIP.Types (HipError(..), HipHostMallocFlags(..), HipMemcpyKind(..))


type HipStreamCallbackFun = Ptr HipStreamTag -> HipError -> Ptr () -> IO ()

foreign import ccall safe "hipMalloc"
  c_hipMalloc :: Ptr (Ptr ()) -> CSize -> IO HipError

foreign import ccall safe "hipFree"
  c_hipFree :: Ptr () -> IO HipError

foreign import ccall safe "hipHostMalloc"
  c_hipHostMalloc :: Ptr (Ptr ()) -> CSize -> HipHostMallocFlags -> IO HipError

foreign import ccall safe "hipHostFree"
  c_hipHostFree :: Ptr () -> IO HipError

foreign import ccall safe "hipMemcpy"
  c_hipMemcpy :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> IO HipError

foreign import ccall safe "hipMemcpyAsync"
  c_hipMemcpyAsync :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipMemcpyWithStream"
  c_hipMemcpyWithStream :: Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipDeviceSynchronize"
  c_hipDeviceSynchronize :: IO HipError

foreign import ccall safe "hipStreamCreate"
  c_hipStreamCreate :: Ptr (Ptr HipStreamTag) -> IO HipError

foreign import ccall safe "hipStreamDestroy"
  c_hipStreamDestroy :: Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipStreamSynchronize"
  c_hipStreamSynchronize :: Ptr HipStreamTag -> IO HipError

foreign import ccall safe "hipEventCreate"
  c_hipEventCreate :: Ptr (Ptr HipEventTag) -> IO HipError

foreign import ccall safe "hipEventDestroy"
  c_hipEventDestroy :: Ptr HipEventTag -> IO HipError

foreign import ccall safe "hipEventRecord"
  c_hipEventRecord :: Ptr HipEventTag -> Ptr HipStreamTag -> IO HipError

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

foreign import ccall safe "hipGetDeviceCount"
  c_hipGetDeviceCount :: Ptr CInt -> IO HipError

foreign import ccall safe "hipGetDevice"
  c_hipGetDevice :: Ptr CInt -> IO HipError

foreign import ccall safe "hipGetDeviceProperties"
  c_hipGetDeviceProperties :: Ptr HipDeviceProp -> CInt -> IO HipError

foreign import ccall unsafe "hipGetLastError"
  c_hipGetLastError :: IO HipError

foreign import ccall unsafe "hipPeekAtLastError"
  c_hipPeekAtLastError :: IO HipError

foreign import ccall unsafe "hipGetErrorString"
  c_hipGetErrorString :: HipError -> IO CString
