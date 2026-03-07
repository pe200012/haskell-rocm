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
  , rocblasSscal
  , rocblasDscal
  , rocblasScopy
  , rocblasDcopy
  , rocblasSdot
  , rocblasDdot
  , rocblasSasum
  , rocblasDasum
  , rocblasSnrm2
  , rocblasDnrm2
  , rocblasSaxpy
  , rocblasDaxpy

    -- * BLAS2
  , rocblasSgemv
  , rocblasDgemv
  , rocblasSgemvBatched
  , rocblasDgemvBatched
  , rocblasSgemvStridedBatched
  , rocblasDgemvStridedBatched

    -- * BLAS3
  , rocblasSgemm
  , rocblasDgemm
  , rocblasSgemmBatched
  , rocblasDgemmBatched
  , rocblasSgemmStridedBatched
  , rocblasDgemmStridedBatched
  ) where

import Control.Exception (bracket)
import Control.Monad (when)
import Foreign.C.Types (CDouble(..), CFloat(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (peek, poke)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types (DevicePtr(..), HipStream(..), RocblasHandle(..))
import ROCm.RocBLAS.C.Types
import ROCm.RocBLAS.Error (checkRocblas)
import ROCm.RocBLAS.Raw
  ( c_rocblas_create_handle
  , c_rocblas_dasum
  , c_rocblas_daxpy
  , c_rocblas_dcopy
  , c_rocblas_ddot
  , c_rocblas_dgemm
  , c_rocblas_dgemm_batched
  , c_rocblas_dgemm_strided_batched
  , c_rocblas_dgemv
  , c_rocblas_dgemv_batched
  , c_rocblas_dgemv_strided_batched
  , c_rocblas_dnrm2
  , c_rocblas_dscal
  , c_rocblas_destroy_handle
  , c_rocblas_get_pointer_mode
  , c_rocblas_get_stream
  , c_rocblas_initialize
  , c_rocblas_sasum
  , c_rocblas_saxpy
  , c_rocblas_scopy
  , c_rocblas_sdot
  , c_rocblas_sgemm
  , c_rocblas_sgemm_batched
  , c_rocblas_sgemm_strided_batched
  , c_rocblas_sgemv
  , c_rocblas_sgemv_batched
  , c_rocblas_sgemv_strided_batched
  , c_rocblas_set_pointer_mode
  , c_rocblas_set_stream
  , c_rocblas_snrm2
  , c_rocblas_sscal
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

rocblasSscal ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocblasSscal handle n alpha (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasSscal" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasSscal" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha -> do
      poke pAlpha (CFloat alpha)
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_sscal" =<< c_rocblas_sscal h n pAlpha (castPtr x) incx

rocblasDscal ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocblasDscal handle n alpha (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasDscal" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDscal" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha -> do
      poke pAlpha (CDouble alpha)
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_dscal" =<< c_rocblas_dscal h n pAlpha (castPtr x) incx

rocblasScopy ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocblasScopy handle n (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasScopy" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasScopy" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasScopy" "incy must not be 0"
  case handle of
    RocblasHandle h ->
      checkRocblas "rocblas_scopy" =<< c_rocblas_scopy h n (castPtr x) incx (castPtr y) incy

rocblasDcopy ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocblasDcopy handle n (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasDcopy" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDcopy" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDcopy" "incy must not be 0"
  case handle of
    RocblasHandle h ->
      checkRocblas "rocblas_dcopy" =<< c_rocblas_dcopy h n (castPtr x) incx (castPtr y) incy

rocblasSdot ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO Float
rocblasSdot handle n (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasSdot" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasSdot" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasSdot" "incy must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_sdot" =<< c_rocblas_sdot h n (castPtr x) incx (castPtr y) incy pResult
      CFloat result <- peek pResult
      pure result

rocblasDdot ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO Double
rocblasDdot handle n (DevicePtr x) incx (DevicePtr y) incy = do
  when (n < 0) $ throwArgumentError "rocblasDdot" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDdot" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDdot" "incy must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_ddot" =<< c_rocblas_ddot h n (castPtr x) incx (castPtr y) incy pResult
      CDouble result <- peek pResult
      pure result

rocblasSasum ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO Float
rocblasSasum handle n (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasSasum" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasSasum" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_sasum" =<< c_rocblas_sasum h n (castPtr x) incx pResult
      CFloat result <- peek pResult
      pure result

rocblasDasum ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO Double
rocblasDasum handle n (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasDasum" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDasum" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_dasum" =<< c_rocblas_dasum h n (castPtr x) incx pResult
      CDouble result <- peek pResult
      pure result

rocblasSnrm2 ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO Float
rocblasSnrm2 handle n (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasSnrm2" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasSnrm2" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_snrm2" =<< c_rocblas_snrm2 h n (castPtr x) incx pResult
      CFloat result <- peek pResult
      pure result

rocblasDnrm2 ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO Double
rocblasDnrm2 handle n (DevicePtr x) incx = do
  when (n < 0) $ throwArgumentError "rocblasDnrm2" "n must be >= 0"
  when (incx == 0) $ throwArgumentError "rocblasDnrm2" "incx must not be 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pResult -> do
      case handle of
        RocblasHandle h ->
          checkRocblas "rocblas_dnrm2" =<< c_rocblas_dnrm2 h n (castPtr x) incx pResult
      CDouble result <- peek pResult
      pure result

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

rocblasSgemvBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Float ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  Float ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  RocblasInt ->
  IO ()
rocblasSgemvBatched handle trans m n alpha (DevicePtr a) lda (DevicePtr x) incx beta (DevicePtr y) incy batchCount = do
  when (m < 0) $ throwArgumentError "rocblasSgemvBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemvBatched" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemvBatched" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasSgemvBatched" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasSgemvBatched" "incy must not be 0"
  when (batchCount < 0) $ throwArgumentError "rocblasSgemvBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemv_batched" =<< c_rocblas_sgemv_batched h trans m n pAlpha a lda x incx pBeta y incy batchCount

rocblasDgemvBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Double ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  Double ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  RocblasInt ->
  IO ()
rocblasDgemvBatched handle trans m n alpha (DevicePtr a) lda (DevicePtr x) incx beta (DevicePtr y) incy batchCount = do
  when (m < 0) $ throwArgumentError "rocblasDgemvBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemvBatched" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemvBatched" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasDgemvBatched" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDgemvBatched" "incy must not be 0"
  when (batchCount < 0) $ throwArgumentError "rocblasDgemvBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemv_batched" =<< c_rocblas_dgemv_batched h trans m n pAlpha a lda x incx pBeta y incy batchCount

rocblasSgemvStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  RocblasInt ->
  IO ()
rocblasSgemvStridedBatched handle trans m n alpha (DevicePtr a) lda strideA (DevicePtr x) incx strideX beta (DevicePtr y) incy strideY batchCount = do
  when (m < 0) $ throwArgumentError "rocblasSgemvStridedBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemvStridedBatched" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemvStridedBatched" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasSgemvStridedBatched" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasSgemvStridedBatched" "incy must not be 0"
  when (batchCount < 0) $ throwArgumentError "rocblasSgemvStridedBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemv_strided_batched" =<< c_rocblas_sgemv_strided_batched h trans m n pAlpha (castPtr a) lda strideA (castPtr x) incx strideX pBeta (castPtr y) incy strideY batchCount

rocblasDgemvStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  RocblasInt ->
  IO ()
rocblasDgemvStridedBatched handle trans m n alpha (DevicePtr a) lda strideA (DevicePtr x) incx strideX beta (DevicePtr y) incy strideY batchCount = do
  when (m < 0) $ throwArgumentError "rocblasDgemvStridedBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemvStridedBatched" "n must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemvStridedBatched" "lda must be > 0"
  when (incx == 0) $ throwArgumentError "rocblasDgemvStridedBatched" "incx must not be 0"
  when (incy == 0) $ throwArgumentError "rocblasDgemvStridedBatched" "incy must not be 0"
  when (batchCount < 0) $ throwArgumentError "rocblasDgemvStridedBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemv_strided_batched" =<< c_rocblas_dgemv_strided_batched h trans m n pAlpha (castPtr a) lda strideA (castPtr x) incx strideX pBeta (castPtr y) incy strideY batchCount

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

rocblasSgemmBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  Float ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  Float ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  RocblasInt ->
  IO ()
rocblasSgemmBatched handle transA transB m n k alpha (DevicePtr a) lda (DevicePtr b) ldb beta (DevicePtr c) ldc batchCount = do
  when (m < 0) $ throwArgumentError "rocblasSgemmBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemmBatched" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasSgemmBatched" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemmBatched" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasSgemmBatched" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasSgemmBatched" "ldc must be > 0"
  when (batchCount < 0) $ throwArgumentError "rocblasSgemmBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemm_batched" =<< c_rocblas_sgemm_batched h transA transB m n k pAlpha a lda b ldb pBeta c ldc batchCount

rocblasDgemmBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  Double ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  Double ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  RocblasInt ->
  IO ()
rocblasDgemmBatched handle transA transB m n k alpha (DevicePtr a) lda (DevicePtr b) ldb beta (DevicePtr c) ldc batchCount = do
  when (m < 0) $ throwArgumentError "rocblasDgemmBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemmBatched" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasDgemmBatched" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemmBatched" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasDgemmBatched" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasDgemmBatched" "ldc must be > 0"
  when (batchCount < 0) $ throwArgumentError "rocblasDgemmBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemm_batched" =<< c_rocblas_dgemm_batched h transA transB m n k pAlpha a lda b ldb pBeta c ldc batchCount

rocblasSgemmStridedBatched ::
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
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  RocblasInt ->
  IO ()
rocblasSgemmStridedBatched handle transA transB m n k alpha (DevicePtr a) lda strideA (DevicePtr b) ldb strideB beta (DevicePtr c) ldc strideC batchCount = do
  when (m < 0) $ throwArgumentError "rocblasSgemmStridedBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasSgemmStridedBatched" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasSgemmStridedBatched" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasSgemmStridedBatched" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasSgemmStridedBatched" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasSgemmStridedBatched" "ldc must be > 0"
  when (batchCount < 0) $ throwArgumentError "rocblasSgemmStridedBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CFloat alpha)
        poke pBeta (CFloat beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_sgemm_strided_batched" =<< c_rocblas_sgemm_strided_batched h transA transB m n k pAlpha (castPtr a) lda strideA (castPtr b) ldb strideB pBeta (castPtr c) ldc strideC batchCount

rocblasDgemmStridedBatched ::
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
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  RocblasInt ->
  IO ()
rocblasDgemmStridedBatched handle transA transB m n k alpha (DevicePtr a) lda strideA (DevicePtr b) ldb strideB beta (DevicePtr c) ldc strideC batchCount = do
  when (m < 0) $ throwArgumentError "rocblasDgemmStridedBatched" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocblasDgemmStridedBatched" "n must be >= 0"
  when (k < 0) $ throwArgumentError "rocblasDgemmStridedBatched" "k must be >= 0"
  when (lda <= 0) $ throwArgumentError "rocblasDgemmStridedBatched" "lda must be > 0"
  when (ldb <= 0) $ throwArgumentError "rocblasDgemmStridedBatched" "ldb must be > 0"
  when (ldc <= 0) $ throwArgumentError "rocblasDgemmStridedBatched" "ldc must be > 0"
  when (batchCount < 0) $ throwArgumentError "rocblasDgemmStridedBatched" "batchCount must be >= 0"
  withRocblasPointerMode handle RocblasPointerModeHost $
    alloca $ \pAlpha ->
      alloca $ \pBeta -> do
        poke pAlpha (CDouble alpha)
        poke pBeta (CDouble beta)
        case handle of
          RocblasHandle h ->
            checkRocblas "rocblas_dgemm_strided_batched" =<< c_rocblas_dgemm_strided_batched h transA transB m n k pAlpha (castPtr a) lda strideA (castPtr b) ldb strideB pBeta (castPtr c) ldc strideC batchCount
