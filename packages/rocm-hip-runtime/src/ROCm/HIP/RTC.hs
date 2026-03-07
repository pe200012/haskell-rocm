{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.RTC
  ( module ROCm.HIP.RTC.Types
  , module ROCm.HIP.RTC.Error
  , hiprtcVersion
  , hiprtcCreateProgram
  , hiprtcDestroyProgram
  , withHiprtcProgram
  , hiprtcCompileProgram
  , hiprtcGetProgramLog
  , hiprtcGetCode
  ) where

import Control.Exception (bracket)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.ByteString (ByteString)
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt(..), CSize(..))
import Foreign.Marshal.Alloc (alloca, allocaBytes)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (nullPtr)
import Foreign.Storable (peek, poke)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.HIP.RTC.Error (checkHiprtc, hiprtcResultString)
import ROCm.HIP.RTC.Raw
  ( c_hiprtcCompileProgram
  , c_hiprtcCreateProgram
  , c_hiprtcDestroyProgram
  , c_hiprtcGetCode
  , c_hiprtcGetCodeSize
  , c_hiprtcGetProgramLog
  , c_hiprtcGetProgramLogSize
  , c_hiprtcVersion
  )
import ROCm.HIP.RTC.Types (HiprtcProgram(..), HiprtcProgramTag, HiprtcResult(..), pattern HiprtcSuccess)

hiprtcVersion :: HasCallStack => IO (Int, Int)
hiprtcVersion =
  alloca $ \pMajor ->
    alloca $ \pMinor -> do
      checkHiprtc "hiprtcVersion" =<< c_hiprtcVersion pMajor pMinor
      major <- fromIntegral <$> (peek pMajor :: IO CInt)
      minor <- fromIntegral <$> (peek pMinor :: IO CInt)
      pure (major, minor)

hiprtcCreateProgram :: HasCallStack => String -> String -> IO HiprtcProgram
hiprtcCreateProgram src name =
  alloca $ \pProg ->
    withCString src $ \cSrc ->
      withCString name $ \cName -> do
        checkHiprtc "hiprtcCreateProgram" =<< c_hiprtcCreateProgram pProg cSrc cName 0 nullPtr nullPtr
        HiprtcProgram <$> peek pProg

hiprtcDestroyProgram :: HasCallStack => HiprtcProgram -> IO ()
hiprtcDestroyProgram (HiprtcProgram prog) =
  alloca $ \pProg -> do
    poke pProg prog
    checkHiprtc "hiprtcDestroyProgram" =<< c_hiprtcDestroyProgram pProg

withHiprtcProgram :: HasCallStack => String -> String -> (HiprtcProgram -> IO a) -> IO a
withHiprtcProgram src name = bracket (hiprtcCreateProgram src name) hiprtcDestroyProgram

hiprtcCompileProgram :: HasCallStack => HiprtcProgram -> [String] -> IO ()
hiprtcCompileProgram prog@(HiprtcProgram rawProg) options =
  withManyCString options $ \cOptions -> do
    status <-
      if null cOptions
        then c_hiprtcCompileProgram rawProg 0 nullPtr
        else withArray cOptions $ \pOptions ->
          c_hiprtcCompileProgram rawProg (fromIntegral (length cOptions)) pOptions
    if status == HiprtcSuccess
      then pure ()
      else do
        msg <- hiprtcResultString status
        logText <- safeHiprtcProgramLog prog
        throwFFIError
          "hiprtc"
          "hiprtcCompileProgram"
          (fromIntegral (unHiprtcResult status))
          (if null logText then msg else msg <> "\n" <> logText)

hiprtcGetProgramLog :: HasCallStack => HiprtcProgram -> IO String
hiprtcGetProgramLog (HiprtcProgram prog) =
  alloca $ \pSize -> do
    checkHiprtc "hiprtcGetProgramLogSize" =<< c_hiprtcGetProgramLogSize prog pSize
    CSize size <- peek pSize
    if size <= 1
      then pure ""
      else allocaBytes (fromIntegral size) $ \buf -> do
        checkHiprtc "hiprtcGetProgramLog" =<< c_hiprtcGetProgramLog prog buf
        BSC.unpack <$> BS.packCStringLen (buf, fromIntegral (size - 1))

hiprtcGetCode :: HasCallStack => HiprtcProgram -> IO ByteString
hiprtcGetCode (HiprtcProgram prog) =
  alloca $ \pSize -> do
    checkHiprtc "hiprtcGetCodeSize" =<< c_hiprtcGetCodeSize prog pSize
    CSize size <- peek pSize
    allocaBytes (fromIntegral size) $ \buf -> do
      checkHiprtc "hiprtcGetCode" =<< c_hiprtcGetCode prog buf
      BS.packCStringLen (buf, fromIntegral size)

safeHiprtcProgramLog :: HiprtcProgram -> IO String
safeHiprtcProgramLog prog =
  hiprtcGetProgramLog prog

withManyCString :: [String] -> ([CString] -> IO a) -> IO a
withManyCString [] k = k []
withManyCString (x : xs) k =
  withCString x $ \cx ->
    withManyCString xs $ \cxs ->
      k (cx : cxs)
