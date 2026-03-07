{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocBLAS.Raw
  ( c_rocblas_initialize
  , c_rocblas_create_handle
  , c_rocblas_destroy_handle
  , c_rocblas_set_stream
  , c_rocblas_get_stream
  , c_rocblas_set_pointer_mode
  , c_rocblas_get_pointer_mode
  , c_rocblas_status_to_string

    -- * BLAS1
  , c_rocblas_sscal
  , c_rocblas_dscal
  , c_rocblas_scopy
  , c_rocblas_dcopy
  , c_rocblas_sdot
  , c_rocblas_ddot
  , c_rocblas_sasum
  , c_rocblas_dasum
  , c_rocblas_snrm2
  , c_rocblas_dnrm2
  , c_rocblas_saxpy
  , c_rocblas_daxpy

    -- * BLAS2
  , c_rocblas_sgemv
  , c_rocblas_dgemv
  , c_rocblas_sgemv_batched
  , c_rocblas_dgemv_batched
  , c_rocblas_sgemv_strided_batched
  , c_rocblas_dgemv_strided_batched

    -- * BLAS3
  , c_rocblas_sgemm
  , c_rocblas_dgemm
  , c_rocblas_sgemm_batched
  , c_rocblas_dgemm_batched
  , c_rocblas_sgemm_strided_batched
  , c_rocblas_dgemm_strided_batched
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (HipStreamTag, RocblasHandleTag)
import ROCm.RocBLAS.C.Types (RocblasInt, RocblasStride)
import ROCm.RocBLAS.Types (RocblasOperation(..), RocblasPointerMode(..), RocblasStatus(..))

foreign import ccall safe "rocblas_initialize"
  c_rocblas_initialize :: IO ()

foreign import ccall safe "rocblas_create_handle"
  c_rocblas_create_handle :: Ptr (Ptr RocblasHandleTag) -> IO RocblasStatus

foreign import ccall safe "rocblas_destroy_handle"
  c_rocblas_destroy_handle :: Ptr RocblasHandleTag -> IO RocblasStatus

foreign import ccall safe "rocblas_set_stream"
  c_rocblas_set_stream :: Ptr RocblasHandleTag -> Ptr HipStreamTag -> IO RocblasStatus

foreign import ccall safe "rocblas_get_stream"
  c_rocblas_get_stream :: Ptr RocblasHandleTag -> Ptr (Ptr HipStreamTag) -> IO RocblasStatus

foreign import ccall safe "rocblas_set_pointer_mode"
  c_rocblas_set_pointer_mode :: Ptr RocblasHandleTag -> RocblasPointerMode -> IO RocblasStatus

foreign import ccall safe "rocblas_get_pointer_mode"
  c_rocblas_get_pointer_mode :: Ptr RocblasHandleTag -> Ptr RocblasPointerMode -> IO RocblasStatus

foreign import ccall unsafe "rocblas_status_to_string"
  c_rocblas_status_to_string :: RocblasStatus -> IO CString

-- BLAS1 ---------------------------------------------------------------------

foreign import ccall safe "rocblas_sscal"
  c_rocblas_sscal ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dscal"
  c_rocblas_dscal ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_scopy"
  c_rocblas_scopy ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dcopy"
  c_rocblas_dcopy ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sdot"
  c_rocblas_sdot ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    IO RocblasStatus

foreign import ccall safe "rocblas_ddot"
  c_rocblas_ddot ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sasum"
  c_rocblas_sasum ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dasum"
  c_rocblas_dasum ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    IO RocblasStatus

foreign import ccall safe "rocblas_snrm2"
  c_rocblas_snrm2 ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dnrm2"
  c_rocblas_dnrm2 ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    IO RocblasStatus

foreign import ccall safe "rocblas_saxpy"
  c_rocblas_saxpy ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_daxpy"
  c_rocblas_daxpy ::
    Ptr RocblasHandleTag ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

-- BLAS2 ---------------------------------------------------------------------

foreign import ccall safe "rocblas_sgemv"
  c_rocblas_sgemv ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemv"
  c_rocblas_dgemv ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sgemv_batched"
  c_rocblas_sgemv_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemv_batched"
  c_rocblas_dgemv_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sgemv_strided_batched"
  c_rocblas_sgemv_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemv_strided_batched"
  c_rocblas_dgemv_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    RocblasInt ->
    IO RocblasStatus

-- BLAS3 ---------------------------------------------------------------------

foreign import ccall safe "rocblas_sgemm"
  c_rocblas_sgemm ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemm"
  c_rocblas_dgemm ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sgemm_batched"
  c_rocblas_sgemm_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr (Ptr CFloat) ->
    RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemm_batched"
  c_rocblas_dgemm_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr (Ptr CDouble) ->
    RocblasInt ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_sgemm_strided_batched"
  c_rocblas_sgemm_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    Ptr CFloat ->
    Ptr CFloat ->
    RocblasInt ->
    RocblasStride ->
    RocblasInt ->
    IO RocblasStatus

foreign import ccall safe "rocblas_dgemm_strided_batched"
  c_rocblas_dgemm_strided_batched ::
    Ptr RocblasHandleTag ->
    RocblasOperation ->
    RocblasOperation ->
    RocblasInt ->
    RocblasInt ->
    RocblasInt ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    Ptr CDouble ->
    Ptr CDouble ->
    RocblasInt ->
    RocblasStride ->
    RocblasInt ->
    IO RocblasStatus
