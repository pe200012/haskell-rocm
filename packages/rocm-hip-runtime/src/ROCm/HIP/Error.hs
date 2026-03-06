{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.Error
  ( hipErrorString
  , checkHip
  ) where

import Foreign.C.String (peekCString)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.HIP.Raw (c_hipGetErrorString)
import ROCm.HIP.Types (HipError(..), pattern HipSuccess)

hipErrorString :: HipError -> IO String
hipErrorString e = c_hipGetErrorString e >>= peekCString

checkHip :: HasCallStack => String -> HipError -> IO ()
checkHip callName err
  | err == HipSuccess = pure ()
  | otherwise = do
      msg <- hipErrorString err
      throwFFIError "hip" callName (fromIntegral (unHipError err)) msg
