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
  , c_rocsolver_ssyev
  , c_rocsolver_dsyev
  , c_rocsolver_sgesvd
  , c_rocsolver_dgesvd
  , c_rocsolver_sgesdd
  , c_rocsolver_dgesdd
  , c_rocsolver_sgesdd_batched
  , c_rocsolver_dgesdd_batched
  , c_rocsolver_sgesdd_strided_batched
  , c_rocsolver_dgesdd_strided_batched
  , c_rocsolver_sgesvdj
  , c_rocsolver_dgesvdj
  , c_rocsolver_sgesvdj_batched
  , c_rocsolver_dgesvdj_batched
  , c_rocsolver_sgesvdj_strided_batched
  , c_rocsolver_dgesvdj_strided_batched
  , c_rocsolver_sgesvdx
  , c_rocsolver_dgesvdx
  , c_rocsolver_sgesvdx_batched
  , c_rocsolver_dgesvdx_batched
  , c_rocsolver_sgesvdx_strided_batched
  , c_rocsolver_dgesvdx_strided_batched
  ) where

import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (RocblasHandleTag)
import ROCm.RocBLAS.C.Types (RocblasInt, RocblasStride)
import ROCm.RocBLAS.Types (RocblasEvect(..), RocblasFill(..), RocblasOperation(..), RocblasSrange(..), RocblasStatus(..), RocblasSvect(..), RocblasWorkmode(..))

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

foreign import ccall safe "rocsolver_ssyev"
  c_rocsolver_ssyev ::
    Ptr RocblasHandleTag ->
    RocblasEvect ->
    RocblasFill ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dsyev"
  c_rocsolver_dsyev ::
    Ptr RocblasHandleTag ->
    RocblasEvect ->
    RocblasFill ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvd"
  c_rocsolver_sgesvd ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasWorkmode ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvd"
  c_rocsolver_dgesvd ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasWorkmode ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesdd"
  c_rocsolver_sgesdd ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesdd"
  c_rocsolver_dgesdd ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesdd_batched"
  c_rocsolver_sgesdd_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesdd_batched"
  c_rocsolver_dgesdd_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesdd_strided_batched"
  c_rocsolver_sgesdd_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesdd_strided_batched"
  c_rocsolver_dgesdd_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdj"
  c_rocsolver_sgesvdj ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdj"
  c_rocsolver_dgesvdj ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdj_batched"
  c_rocsolver_sgesvdj_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdj_batched"
  c_rocsolver_dgesvdj_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdj_strided_batched"
  c_rocsolver_sgesvdj_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdj_strided_batched"
  c_rocsolver_dgesvdj_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdx"
  c_rocsolver_sgesvdx ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    CFloat ->
    CFloat ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdx"
  c_rocsolver_dgesvdx ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    CDouble ->
    CDouble ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdx_batched"
  c_rocsolver_sgesvdx_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    CFloat ->
    CFloat ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdx_batched"
  c_rocsolver_dgesvdx_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    CDouble ->
    CDouble ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_sgesvdx_strided_batched"
  c_rocsolver_sgesvdx_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    CFloat ->
    CFloat ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CFloat ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocsolver_dgesvdx_strided_batched"
  c_rocsolver_dgesvdx_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasSvect ->
    RocblasSvect ->
    RocblasSrange ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    CDouble ->
    CDouble ->
    RocblasInt ->
    RocblasInt ->
    Ptr RocblasInt ->
    Ptr CDouble ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasStride ->
    Ptr RocblasInt ->
    RocblasInt ->
    IO RocblasStatus
