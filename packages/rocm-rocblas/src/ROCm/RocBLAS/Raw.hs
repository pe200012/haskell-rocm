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
  , c_rocblas_saxpy
  , c_rocblas_daxpy

    -- * BLAS3
  , c_rocblas_sgemm
  , c_rocblas_dgemm
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (HipStreamTag, RocblasHandleTag)
import ROCm.RocBLAS.C.Types (RocblasInt)
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
