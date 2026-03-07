{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.RTC.Error
  ( hiprtcResultString
  , checkHiprtc
  ) where

import Foreign.C.String (peekCString)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.HIP.RTC.Raw (c_hiprtcGetErrorString)
import ROCm.HIP.RTC.Types (HiprtcResult(..), pattern HiprtcSuccess)

hiprtcResultString :: HiprtcResult -> IO String
hiprtcResultString r = c_hiprtcGetErrorString r >>= peekCString

checkHiprtc :: HasCallStack => String -> HiprtcResult -> IO ()
checkHiprtc callName st
  | st == HiprtcSuccess = pure ()
  | otherwise = do
      msg <- hiprtcResultString st
      throwFFIError "hiprtc" callName (fromIntegral (unHiprtcResult st)) msg
