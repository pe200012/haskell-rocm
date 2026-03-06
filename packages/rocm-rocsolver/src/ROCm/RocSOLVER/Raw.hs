{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocSOLVER.Raw
  ( c_rocsolver_spotrf
  , c_rocsolver_dpotrf
  , c_rocsolver_sposv
  , c_rocsolver_dposv
  ) where

import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (RocblasHandleTag)
import ROCm.RocBLAS.C.Types (RocblasInt)
import ROCm.RocBLAS.Types (RocblasFill(..), RocblasStatus(..))

foreign import ccall safe "rocsolver_spotrf"
  c_rocsolver_spotrf ::
    Ptr RocblasHandleTag ->
    RocblasFill ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dpotrf"
  c_rocsolver_dpotrf ::
    Ptr RocblasHandleTag ->
    RocblasFill ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sposv"
  c_rocsolver_sposv ::
    Ptr RocblasHandleTag ->
    RocblasFill ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dposv"
  c_rocsolver_dposv ::
    Ptr RocblasHandleTag ->
    RocblasFill ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus
