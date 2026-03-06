{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocSOLVER.Raw
  ( c_rocsolver_spotrf
  , c_rocsolver_dpotrf
  , c_rocsolver_sposv
  , c_rocsolver_dposv
  , c_rocsolver_sgetrf
  , c_rocsolver_dgetrf
  , c_rocsolver_sgetrs
  , c_rocsolver_dgetrs
  , c_rocsolver_sgesv
  , c_rocsolver_dgesv
  , c_rocsolver_sgeqrf
  , c_rocsolver_dgeqrf
  , c_rocsolver_sorgqr
  , c_rocsolver_dorgqr
  ) where

import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (RocblasHandleTag)
import ROCm.RocBLAS.C.Types (RocblasInt)
import ROCm.RocBLAS.Types (RocblasFill(..), RocblasOperation(..), RocblasStatus(..))

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

foreign import ccall safe "rocsolver_sgetrf"
  c_rocsolver_sgetrf ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgetrf"
  c_rocsolver_dgetrf ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgetrs"
  c_rocsolver_sgetrs ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgetrs"
  c_rocsolver_dgetrs ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesv"
  c_rocsolver_sgesv ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesv"
  c_rocsolver_dgesv ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgeqrf"
  c_rocsolver_sgeqrf ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgeqrf"
  c_rocsolver_dgeqrf ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sorgqr"
  c_rocsolver_sorgqr ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dorgqr"
  c_rocsolver_dorgqr ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    IO RocblasStatus
