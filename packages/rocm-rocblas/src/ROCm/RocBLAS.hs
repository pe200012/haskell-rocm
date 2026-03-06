module ROCm.RocBLAS
  ( module ROCm.RocBLAS.Types
  , module ROCm.RocBLAS.C.Types
  , module ROCm.RocBLAS.Error

    -- * Handle
  , rocblasInitialize
  , rocblasCreateHandle
  , rocblasDestroyHandle
  , withRocblasHandle

    -- * Stream
  , rocblasSetStream
  , rocblasGetStream

    -- * Pointer mode
  , rocblasSetPointerMode
  , rocblasGetPointerMode
  , withRocblasPointerMode

    -- * BLAS1
  , rocblasSaxpy
  , rocblasDaxpy

    -- * BLAS2
  , rocblasSgemv
  , rocblasDgemv

    -- * BLAS3
  , rocblasSgemm
  , rocblasDgemm
  ) where

import Control.Exception (bracket)
import Control.Monad (when)
import Foreign.C.Types (CDouble(..), CFloat(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (castPtr)
import Foreign.Storable (peek, poke)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types (DevicePtr(..), HipStream(..), RocblasHandle(..))
import ROCm.RocBLAS.C.Types
import ROCm.RocBLAS.Error (checkRocblas)
import ROCm.RocBLAS.Raw
  ( c_rocblas_create_handle
  , c_rocblas_initialize
  , c_rocblas_daxpy
  , c_rocblas_dgemm
  , c_rocblas_dgemv
  , c_rocblas_destroy_handle
  , c_rocblas_get_pointer_mode
  , c_rocblas_get_stream
  , c_rocblas_saxpy
  , c_rocblas_sgemv
  , c_rocblas_set_pointer_mode
  , c_rocblas_set_stream
  , c_rocblas_sgemm
  )
import ROCm.RocBLAS.Types

-- Handle --------------------------------------------------------------------

rocblasInitialize :: IO ()
rocblasInitialize = c_rocblas_initialize

rocblasCreateHandle :: HasCallStack => IO RocblasHandle
rocblasCreateHandle =
  alloca $ \pHandle -> do
    checkRocblas "rocblas_create_handle" =<< c_rocblas_create_handle pHandle
    RocblasHandle <$> peek pHandle

rocblasDestroyHandle :: HasCallStack => RocblasHandle -> IO ()
rocblasDestroyHandle (RocblasHandle h) = checkRocblas "rocblas_destroy_handle" =<< c_rocblas_destroy_handle h

withRocblasHandle :: HasCallStack => (RocblasHandle -> IO a) -> IO a
withRocblasHandle = bracket rocblasCreateHandle rocblasDestroyHandle

-- Stream --------------------------------------------------------------------

rocblasSetStream :: HasCallStack => RocblasHandle -> HipStream -> IO ()
rocblasSetStream (RocblasHandle h) (HipStream s) = checkRocblas "rocblas_set_stream" =<< c_rocblas_set_stream h s

rocblasGetStream :: HasCallStack => RocblasHandle -> IO HipStream
rocblasGetStream (RocblasHandle h) =
  alloca $ \pStream -> do
    checkRocblas "rocblas_get_stream" =<< c_rocblas_get_stream h pStream
    HipStream <$> peek pStream

-- Pointer mode --------------------------------------------------------------

rocblasSetPointerMode :: HasCallStack => RocblasHandle -> RocblasPointerMode -> IO ()
rocblasSetPointerMode (RocblasHandle h) mode = checkRocblas "rocblas_set_pointer_mode" =<< c_rocblas_set_pointer_mode h mode

rocblasGetPointerMode :: HasCallStack => RocblasHandle -> IO RocblasPointerMode
rocblasGetPointerMode (RocblasHandle h) =
  alloca $ \pMode -> do
    checkRocblas "rocblas_get_pointer_mode" =<< c_rocblas_get_pointer_mode h pMode
    peek pMode

withRocblasPointerMode :: HasCallStack => RocblasHandle -> RocblasPointerMode -> IO a -> IO a
withRocblasPointerMode h newMode action =
  bracket
    (rocblasGetPointerMode h <* rocblasSetPointerMode h newMode)
    (rocblasSetPointerMode h)
    (const action)

-- BLAS1 ---------------------------------------------------------------------

rocblasSaxpy ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocblasSaxpy handle n alpha (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasSaxpy" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasSaxpy" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasSaxpy" "incy must not be 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha -> do
      poke pAlpha (CFloat alpha)
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_saxpy" =<< c_rocblas_saxpy h n pAlpha (castPtr x) incx (castPtr y) incy

rocblasDaxpy ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocblasDaxpy handle n alpha (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasDaxpy" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDaxpy" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDaxpy" "incy must not be 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha -> do
      poke pAlpha (CDouble alpha)
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_daxpy" =<< c_rocblas_daxpy h n pAlpha (castPtr x) incx (castPtr y) incy

-- BLAS2 ---------------------------------------------------------------------

rocblasSgemv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocblasSgemv handle trans m n alpha (DevicePtr a) lda (DevicePtr x) incx beta (DevicePtr y) incy = do
  when (m < 0) $ throwArgumentError "rocblasSgemv" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemv" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemv" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasSgemv" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasSgemv" "incy must not be 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemv" =<< c_rocblas_sgemv h trans m n pAlpha (castPtr a) lda (castPtr x) incx pBeta (castPtr y) incy

rocblasDgemv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocblasDgemv handle trans m n alpha (DevicePtr a) lda (DevicePtr x) incx beta (DevicePtr y) incy = do
  when (m < 0) $ throwArgumentError "rocblasDgemv" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemv" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemv" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasDgemv" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDgemv" "incy must not be 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemv" =<< c_rocblas_dgemv h trans m n pAlpha (castPtr a) lda (castPtr x) incx pBeta (castPtr y) incy

-- BLAS3 ---------------------------------------------------------------------

rocblasSgemm ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocblasSgemm handle transA transB m n k alpha (DevicePtr a) lda (DevicePtr b) ldb beta (DevicePtr c) ldc = do
  when (m < 0) $ throwArgumentError "rocblasSgemm" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemm" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasSgemm" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemm" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasSgemm" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasSgemm" "ldc must be > 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemm" =<<
              c_rocblas_sgemm
                h
                transA
                transB
                m
                n
                k
                pAlpha
                (castPtr a)
                lda
                (castPtr b)
                ldb
                pBeta
                (castPtr c)
                ldc

rocblasDgemm ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocblasDgemm handle transA transB m n k alpha (DevicePtr a) lda (DevicePtr b) ldb beta (DevicePtr c) ldc = do
  when (m < 0) $ throwArgumentError "rocblasDgemm" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemm" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasDgemm" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemm" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasDgemm" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasDgemm" "ldc must be > 0"

  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemm" =<<
              c_rocblas_dgemm
                h
                transA
                transB
                m
                n
                k
                pAlpha
                (castPtr a)
                lda
                (castPtr b)
                ldb
                pBeta
                (castPtr c)
                ldc
