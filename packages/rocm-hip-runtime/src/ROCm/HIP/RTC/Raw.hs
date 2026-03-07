{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.HIP.RTC.Raw
  ( c_hiprtcGetErrorString
  , c_hiprtcVersion
  , c_hiprtcCreateProgram
  , c_hiprtcDestroyProgram
  , c_hiprtcCompileProgram
  , c_hiprtcGetProgramLogSize
  , c_hiprtcGetProgramLog
  , c_hiprtcGetCodeSize
  , c_hiprtcGetCode
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CSize(..))
import Foreign.Ptr (Ptr)
import ROCm.HIP.RTC.Types (HiprtcProgramTag, HiprtcResult(..))

foreign import ccall unsafe "hiprtcGetErrorString"
  c_hiprtcGetErrorString :: HiprtcResult -> IO CString

foreign import ccall safe "hiprtcVersion"
  c_hiprtcVersion :: Ptr CInt -> Ptr CInt -> IO HiprtcResult

foreign import ccall safe "hiprtcCreateProgram"
  c_hiprtcCreateProgram ::
    Ptr (Ptr HiprtcProgramTag) ->
    CString ->
    CString ->
    CInt ->
    Ptr CString ->
    Ptr CString ->
    IO HiprtcResult

foreign import ccall safe "hiprtcDestroyProgram"
  c_hiprtcDestroyProgram :: Ptr (Ptr HiprtcProgramTag) -> IO HiprtcResult

foreign import ccall safe "hiprtcCompileProgram"
  c_hiprtcCompileProgram :: Ptr HiprtcProgramTag -> CInt -> Ptr CString -> IO HiprtcResult

foreign import ccall safe "hiprtcGetProgramLogSize"
  c_hiprtcGetProgramLogSize :: Ptr HiprtcProgramTag -> Ptr CSize -> IO HiprtcResult

foreign import ccall safe "hiprtcGetProgramLog"
  c_hiprtcGetProgramLog :: Ptr HiprtcProgramTag -> CString -> IO HiprtcResult

foreign import ccall safe "hiprtcGetCodeSize"
  c_hiprtcGetCodeSize :: Ptr HiprtcProgramTag -> Ptr CSize -> IO HiprtcResult

foreign import ccall safe "hiprtcGetCode"
  c_hiprtcGetCode :: Ptr HiprtcProgramTag -> CString -> IO HiprtcResult
