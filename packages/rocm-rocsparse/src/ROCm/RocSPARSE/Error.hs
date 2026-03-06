{-# LANGUAGE PatternSynonyms #-}

module ROCm.RocSPARSE.Error
  ( rocsparseStatusToString
  , checkRocsparse
  ) where

import Foreign.C.String (peekCString)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwFFIError)
import ROCm.RocSPARSE.Raw (c_rocsparse_get_status_description, c_rocsparse_get_status_name)
import ROCm.RocSPARSE.Types (RocsparseStatus(..), pattern RocsparseStatusSuccess)

rocsparseStatusToString :: RocsparseStatus -> IO String
rocsparseStatusToString st = do
  name <- c_rocsparse_get_status_name st >>= peekCString
  desc <- c_rocsparse_get_status_description st >>= peekCString
  pure $ if null desc then name else name <> ": " <> desc

checkRocsparse :: HasCallStack => String -> RocsparseStatus -> IO ()
checkRocsparse callName st
  | st == RocsparseStatusSuccess = pure ()
  | otherwise = do
      msg <- rocsparseStatusToString st
      throwFFIError "rocsparse" callName (fromIntegral (unRocsparseStatus st)) msg
