module ROCm.RocSOLVER
  ( rocsolverSpotrf
  , rocsolverDpotrf
  , rocsolverSposv
  , rocsolverDposv
  , rocsolverSgetrf
  , rocsolverDgetrf
  , rocsolverSgetrs
  , rocsolverDgetrs
  , rocsolverSgesv
  , rocsolverDgesv
  , rocsolverSgeqrf
  , rocsolverDgeqrf
  , rocsolverSorgqr
  , rocsolverDorgqr
  , rocsolverSsyev
  , rocsolverDsyev
  , rocsolverSgesvd
  , rocsolverDgesvd
  , rocsolverSgesdd
  , rocsolverDgesdd
  , rocsolverSgesddBatched
  , rocsolverDgesddBatched
  , rocsolverSgesddStridedBatched
  , rocsolverDgesddStridedBatched
  , rocsolverSgesvdj
  , rocsolverDgesvdj
  , rocsolverSgesvdjBatched
  , rocsolverDgesvdjBatched
  , rocsolverSgesvdjStridedBatched
  , rocsolverDgesvdjStridedBatched
  , rocsolverSgesvdx
  , rocsolverDgesvdx
  , rocsolverSgesvdxBatched
  , rocsolverDgesvdxBatched
  , rocsolverSgesvdxStridedBatched
  , rocsolverDgesvdxStridedBatched
  ) where

import Control.Monad (when)
import Foreign.C.Types (CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types (DevicePtr(..), RocblasHandle(..))
import ROCm.RocBLAS.C.Types (RocblasInt, RocblasStride)
import ROCm.RocBLAS.Error (checkRocblas)
import ROCm.RocBLAS.Types (RocblasEvect, RocblasFill, RocblasOperation, RocblasSrange(..), RocblasSvect(..), RocblasWorkmode)
import ROCm.RocSOLVER.Raw
  ( c_rocsolver_dgeqrf
  , c_rocsolver_dgesdd
  , c_rocsolver_dgesdd_batched
  , c_rocsolver_dgesdd_strided_batched
  , c_rocsolver_dgesv
  , c_rocsolver_dgesvd
  , c_rocsolver_dgesvdj
  , c_rocsolver_dgesvdj_batched
  , c_rocsolver_dgesvdj_strided_batched
  , c_rocsolver_dgesvdx
  , c_rocsolver_dgesvdx_batched
  , c_rocsolver_dgesvdx_strided_batched
  , c_rocsolver_dgetrf
  , c_rocsolver_dgetrs
  , c_rocsolver_dorgqr
  , c_rocsolver_dposv
  , c_rocsolver_dpotrf
  , c_rocsolver_dsyev
  , c_rocsolver_sgeqrf
  , c_rocsolver_sgesdd
  , c_rocsolver_sgesdd_batched
  , c_rocsolver_sgesdd_strided_batched
  , c_rocsolver_sgesv
  , c_rocsolver_sgesvd
  , c_rocsolver_sgesvdj
  , c_rocsolver_sgesvdj_batched
  , c_rocsolver_sgesvdj_strided_batched
  , c_rocsolver_sgesvdx
  , c_rocsolver_sgesvdx_batched
  , c_rocsolver_sgesvdx_strided_batched
  , c_rocsolver_sgetrf
  , c_rocsolver_sgetrs
  , c_rocsolver_sorgqr
  , c_rocsolver_sposv
  , c_rocsolver_spotrf
  , c_rocsolver_ssyev
  )

rocsolverSpotrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasFill ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSpotrf (RocblasHandle h) uplo n (DevicePtr a) lda (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverSpotrf" "n must be >= 0"
  when (lda < n) $ throwArgumentError "rocsolverSpotrf" "lda must be >= n"
  checkRocblas "rocsolver_spotrf" =<< c_rocsolver_spotrf h uplo n a lda info

rocsolverDpotrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasFill ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDpotrf (RocblasHandle h) uplo n (DevicePtr a) lda (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverDpotrf" "n must be >= 0"
  when (lda < n) $ throwArgumentError "rocsolverDpotrf" "lda must be >= n"
  checkRocblas "rocsolver_dpotrf" =<< c_rocsolver_dpotrf h uplo n a lda info

rocsolverSposv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasFill ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSposv (RocblasHandle h) uplo n nrhs (DevicePtr a) lda (DevicePtr b) ldb (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverSposv" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverSposv" "nrhs must be >= 0"
  when (lda < n) $ throwArgumentError "rocsolverSposv" "lda must be >= n"
  when (ldb < n) $ throwArgumentError "rocsolverSposv" "ldb must be >= n"
  checkRocblas "rocsolver_sposv" =<< c_rocsolver_sposv h uplo n nrhs a lda b ldb info

rocsolverDposv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasFill ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDposv (RocblasHandle h) uplo n nrhs (DevicePtr a) lda (DevicePtr b) ldb (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverDposv" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverDposv" "nrhs must be >= 0"
  when (lda < n) $ throwArgumentError "rocsolverDposv" "lda must be >= n"
  when (ldb < n) $ throwArgumentError "rocsolverDposv" "ldb must be >= n"
  checkRocblas "rocsolver_dposv" =<< c_rocsolver_dposv h uplo n nrhs a lda b ldb info

rocsolverSgetrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgetrf (RocblasHandle h) m n (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr info) = do
  when (m < 0) $ throwArgumentError "rocsolverSgetrf" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverSgetrf" "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError "rocsolverSgetrf" "lda must be >= max 1 m"
  checkRocblas "rocsolver_sgetrf" =<< c_rocsolver_sgetrf h m n a lda ipiv info

rocsolverDgetrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgetrf (RocblasHandle h) m n (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr info) = do
  when (m < 0) $ throwArgumentError "rocsolverDgetrf" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverDgetrf" "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError "rocsolverDgetrf" "lda must be >= max 1 m"
  checkRocblas "rocsolver_dgetrf" =<< c_rocsolver_dgetrf h m n a lda ipiv info

rocsolverSgetrs ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  IO ()
rocsolverSgetrs (RocblasHandle h) trans n nrhs (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr b) ldb = do
  when (n < 0) $ throwArgumentError "rocsolverSgetrs" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverSgetrs" "nrhs must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverSgetrs" "lda must be >= max 1 n"
  when (ldb < max 1 n) $ throwArgumentError "rocsolverSgetrs" "ldb must be >= max 1 n"
  checkRocblas "rocsolver_sgetrs" =<< c_rocsolver_sgetrs h trans n nrhs a lda ipiv b ldb

rocsolverDgetrs ::
  HasCallStack =>
  RocblasHandle ->
  RocblasOperation ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  IO ()
rocsolverDgetrs (RocblasHandle h) trans n nrhs (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr b) ldb = do
  when (n < 0) $ throwArgumentError "rocsolverDgetrs" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverDgetrs" "nrhs must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverDgetrs" "lda must be >= max 1 n"
  when (ldb < max 1 n) $ throwArgumentError "rocsolverDgetrs" "ldb must be >= max 1 n"
  checkRocblas "rocsolver_dgetrs" =<< c_rocsolver_dgetrs h trans n nrhs a lda ipiv b ldb

rocsolverSgesv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgesv (RocblasHandle h) n nrhs (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr b) ldb (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverSgesv" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverSgesv" "nrhs must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverSgesv" "lda must be >= max 1 n"
  when (ldb < max 1 n) $ throwArgumentError "rocsolverSgesv" "ldb must be >= max 1 n"
  checkRocblas "rocsolver_sgesv" =<< c_rocsolver_sgesv h n nrhs a lda ipiv b ldb info

rocsolverDgesv ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgesv (RocblasHandle h) n nrhs (DevicePtr a) lda (DevicePtr ipiv) (DevicePtr b) ldb (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverDgesv" "n must be >= 0"
  when (nrhs < 0) $ throwArgumentError "rocsolverDgesv" "nrhs must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverDgesv" "lda must be >= max 1 n"
  when (ldb < max 1 n) $ throwArgumentError "rocsolverDgesv" "ldb must be >= max 1 n"
  checkRocblas "rocsolver_dgesv" =<< c_rocsolver_dgesv h n nrhs a lda ipiv b ldb info

rocsolverSgeqrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  IO ()
rocsolverSgeqrf (RocblasHandle h) m n (DevicePtr a) lda (DevicePtr tau) = do
  when (m < 0) $ throwArgumentError "rocsolverSgeqrf" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverSgeqrf" "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError "rocsolverSgeqrf" "lda must be >= max 1 m"
  checkRocblas "rocsolver_sgeqrf" =<< c_rocsolver_sgeqrf h m n a lda tau

rocsolverDgeqrf ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  IO ()
rocsolverDgeqrf (RocblasHandle h) m n (DevicePtr a) lda (DevicePtr tau) = do
  when (m < 0) $ throwArgumentError "rocsolverDgeqrf" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverDgeqrf" "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError "rocsolverDgeqrf" "lda must be >= max 1 m"
  checkRocblas "rocsolver_dgeqrf" =<< c_rocsolver_dgeqrf h m n a lda tau

rocsolverSorgqr ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  IO ()
rocsolverSorgqr (RocblasHandle h) m n k (DevicePtr a) lda (DevicePtr tau) = do
  when (m < 0) $ throwArgumentError "rocsolverSorgqr" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverSorgqr" "n must be >= 0"
  when (n > m) $ throwArgumentError "rocsolverSorgqr" "n must be <= m"
  when (k < 0 || k > n) $ throwArgumentError "rocsolverSorgqr" "k must satisfy 0 <= k <= n"
  when (lda < max 1 m) $ throwArgumentError "rocsolverSorgqr" "lda must be >= max 1 m"
  checkRocblas "rocsolver_sorgqr" =<< c_rocsolver_sorgqr h m n k a lda tau

rocsolverDorgqr ::
  HasCallStack =>
  RocblasHandle ->
  RocblasInt ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  IO ()
rocsolverDorgqr (RocblasHandle h) m n k (DevicePtr a) lda (DevicePtr tau) = do
  when (m < 0) $ throwArgumentError "rocsolverDorgqr" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsolverDorgqr" "n must be >= 0"
  when (n > m) $ throwArgumentError "rocsolverDorgqr" "n must be <= m"
  when (k < 0 || k > n) $ throwArgumentError "rocsolverDorgqr" "k must satisfy 0 <= k <= n"
  when (lda < max 1 m) $ throwArgumentError "rocsolverDorgqr" "lda must be >= max 1 m"
  checkRocblas "rocsolver_dorgqr" =<< c_rocsolver_dorgqr h m n k a lda tau

rocsolverSsyev ::
  HasCallStack =>
  RocblasHandle ->
  RocblasEvect ->
  RocblasFill ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  DevicePtr CFloat ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSsyev (RocblasHandle h) evect uplo n (DevicePtr a) lda (DevicePtr d) (DevicePtr e) (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverSsyev" "n must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverSsyev" "lda must be >= max 1 n"
  checkRocblas "rocsolver_ssyev" =<< c_rocsolver_ssyev h evect uplo n a lda d e info

rocsolverDsyev ::
  HasCallStack =>
  RocblasHandle ->
  RocblasEvect ->
  RocblasFill ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  DevicePtr CDouble ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDsyev (RocblasHandle h) evect uplo n (DevicePtr a) lda (DevicePtr d) (DevicePtr e) (DevicePtr info) = do
  when (n < 0) $ throwArgumentError "rocsolverDsyev" "n must be >= 0"
  when (lda < max 1 n) $ throwArgumentError "rocsolverDsyev" "lda must be >= max 1 n"
  checkRocblas "rocsolver_dsyev" =<< c_rocsolver_dsyev h evect uplo n a lda d e info

rocsolverSgesvd ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasWorkmode ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgesvd (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr e) fastAlg (DevicePtr info) = do
  validateGesvdArgs "rocsolverSgesvd" leftSvect rightSvect m n lda ldu ldv
  checkRocblas "rocsolver_sgesvd" =<< c_rocsolver_sgesvd h leftSvect rightSvect m n a lda s u ldu v ldv e fastAlg info

rocsolverDgesvd ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasWorkmode ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgesvd (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr e) fastAlg (DevicePtr info) = do
  validateGesvdArgs "rocsolverDgesvd" leftSvect rightSvect m n lda ldu ldv
  checkRocblas "rocsolver_dgesvd" =<< c_rocsolver_dgesvd h leftSvect rightSvect m n a lda s u ldu v ldv e fastAlg info

rocsolverSgesdd ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgesdd (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr info) = do
  validateGesddArgs "rocsolverSgesdd" leftSvect rightSvect m n lda ldu ldv
  checkRocblas "rocsolver_sgesdd" =<< c_rocsolver_sgesdd h leftSvect rightSvect m n a lda s u ldu v ldv info

rocsolverDgesdd ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgesdd (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr info) = do
  validateGesddArgs "rocsolverDgesdd" leftSvect rightSvect m n lda ldu ldv
  checkRocblas "rocsolver_dgesdd" =<< c_rocsolver_dgesdd h leftSvect rightSvect m n a lda s u ldu v ldv info

rocsolverSgesddBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesddBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr aPtrs) lda (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesddBatchedArgs "rocsolverSgesddBatched" leftSvect rightSvect m n lda ldu ldv batchCount
  checkRocblas "rocsolver_sgesdd_batched" =<< c_rocsolver_sgesdd_batched h leftSvect rightSvect m n aPtrs lda s strideS u ldu strideU v ldv strideV info batchCount

rocsolverDgesddBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesddBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr aPtrs) lda (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesddBatchedArgs "rocsolverDgesddBatched" leftSvect rightSvect m n lda ldu ldv batchCount
  checkRocblas "rocsolver_dgesdd_batched" =<< c_rocsolver_dgesdd_batched h leftSvect rightSvect m n aPtrs lda s strideS u ldu strideU v ldv strideV info batchCount

rocsolverSgesddStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesddStridedBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda strideA (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesddStridedBatchedArgs "rocsolverSgesddStridedBatched" leftSvect rightSvect m n lda ldu ldv batchCount
  checkRocblas "rocsolver_sgesdd_strided_batched" =<< c_rocsolver_sgesdd_strided_batched h leftSvect rightSvect m n a lda strideA s strideS u ldu strideU v ldv strideV info batchCount

rocsolverDgesddStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesddStridedBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda strideA (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesddStridedBatchedArgs "rocsolverDgesddStridedBatched" leftSvect rightSvect m n lda ldu ldv batchCount
  checkRocblas "rocsolver_dgesdd_strided_batched" =<< c_rocsolver_dgesdd_strided_batched h leftSvect rightSvect m n a lda strideA s strideS u ldu strideU v ldv strideV info batchCount

rocsolverSgesvdj ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgesvdj (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr info) = do
  validateGesvdjArgs "rocsolverSgesvdj" leftSvect rightSvect m n lda maxSweeps ldu ldv
  checkRocblas "rocsolver_sgesvdj" =<< c_rocsolver_sgesvdj h leftSvect rightSvect m n a lda (CFloat abstol) residual maxSweeps nSweeps s u ldu v ldv info

rocsolverDgesvdj ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgesvdj (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr info) = do
  validateGesvdjArgs "rocsolverDgesvdj" leftSvect rightSvect m n lda maxSweeps ldu ldv
  checkRocblas "rocsolver_dgesvdj" =<< c_rocsolver_dgesvdj h leftSvect rightSvect m n a lda (CDouble abstol) residual maxSweeps nSweeps s u ldu v ldv info

rocsolverSgesvdjBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesvdjBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr aPtrs) lda abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesvdjBatchedArgs "rocsolverSgesvdjBatched" leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount
  checkRocblas "rocsolver_sgesvdj_batched" =<< c_rocsolver_sgesvdj_batched h leftSvect rightSvect m n aPtrs lda (CFloat abstol) residual maxSweeps nSweeps s strideS u ldu strideU v ldv strideV info batchCount

rocsolverDgesvdjBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesvdjBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr aPtrs) lda abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesvdjBatchedArgs "rocsolverDgesvdjBatched" leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount
  checkRocblas "rocsolver_dgesvdj_batched" =<< c_rocsolver_dgesvdj_batched h leftSvect rightSvect m n aPtrs lda (CDouble abstol) residual maxSweeps nSweeps s strideS u ldu strideU v ldv strideV info batchCount

rocsolverSgesvdjStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  Float ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesvdjStridedBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda strideA abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesvdjStridedBatchedArgs "rocsolverSgesvdjStridedBatched" leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount
  checkRocblas "rocsolver_sgesvdj_strided_batched" =<< c_rocsolver_sgesvdj_strided_batched h leftSvect rightSvect m n a lda strideA (CFloat abstol) residual maxSweeps nSweeps s strideS u ldu strideU v ldv strideV info batchCount

rocsolverDgesvdjStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  Double ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesvdjStridedBatched (RocblasHandle h) leftSvect rightSvect m n (DevicePtr a) lda strideA abstol (DevicePtr residual) maxSweeps (DevicePtr nSweeps) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr info) batchCount = do
  validateGesvdjStridedBatchedArgs "rocsolverDgesvdjStridedBatched" leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount
  checkRocblas "rocsolver_dgesvdj_strided_batched" =<< c_rocsolver_dgesvdj_strided_batched h leftSvect rightSvect m n a lda strideA (CDouble abstol) residual maxSweeps nSweeps s strideS u ldu strideU v ldv strideV info batchCount

rocsolverSgesvdx ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  Float ->
  Float ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverSgesvdx (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr a) lda vl vu il iu (DevicePtr nsv) (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr ifail) (DevicePtr info) = do
  validateGesvdxArgs "rocsolverSgesvdx" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv
  checkRocblas "rocsolver_sgesvdx" =<< c_rocsolver_sgesvdx h leftSvect rightSvect srange m n a lda (CFloat vl) (CFloat vu) il iu nsv s u ldu v ldv ifail info

rocsolverDgesvdx ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  Double ->
  Double ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr RocblasInt ->
  IO ()
rocsolverDgesvdx (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr a) lda vl vu il iu (DevicePtr nsv) (DevicePtr s) (DevicePtr u) ldu (DevicePtr v) ldv (DevicePtr ifail) (DevicePtr info) = do
  validateGesvdxArgs "rocsolverDgesvdx" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv
  checkRocblas "rocsolver_dgesvdx" =<< c_rocsolver_dgesvdx h leftSvect rightSvect srange m n a lda (CDouble vl) (CDouble vu) il iu nsv s u ldu v ldv ifail info

rocsolverSgesvdxBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CFloat) ->
  RocblasInt ->
  Float ->
  Float ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesvdxBatched (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr aPtrs) lda vl vu il iu (DevicePtr nsv) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr ifail) strideF (DevicePtr info) batchCount = do
  validateGesvdxBatchedArgs "rocsolverSgesvdxBatched" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount
  checkRocblas "rocsolver_sgesvdx_batched" =<< c_rocsolver_sgesvdx_batched h leftSvect rightSvect srange m n aPtrs lda (CFloat vl) (CFloat vu) il iu nsv s strideS u ldu strideU v ldv strideV ifail strideF info batchCount

rocsolverDgesvdxBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr (Ptr CDouble) ->
  RocblasInt ->
  Double ->
  Double ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesvdxBatched (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr aPtrs) lda vl vu il iu (DevicePtr nsv) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr ifail) strideF (DevicePtr info) batchCount = do
  validateGesvdxBatchedArgs "rocsolverDgesvdxBatched" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount
  checkRocblas "rocsolver_dgesvdx_batched" =<< c_rocsolver_dgesvdx_batched h leftSvect rightSvect srange m n aPtrs lda (CDouble vl) (CDouble vu) il iu nsv s strideS u ldu strideU v ldv strideV ifail strideF info batchCount

rocsolverSgesvdxStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  Float ->
  Float ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CFloat ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CFloat ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverSgesvdxStridedBatched (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr a) lda strideA vl vu il iu (DevicePtr nsv) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr ifail) strideF (DevicePtr info) batchCount = do
  validateGesvdxStridedBatchedArgs "rocsolverSgesvdxStridedBatched" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount
  checkRocblas "rocsolver_sgesvdx_strided_batched" =<< c_rocsolver_sgesvdx_strided_batched h leftSvect rightSvect srange m n a lda strideA (CFloat vl) (CFloat vu) il iu nsv s strideS u ldu strideU v ldv strideV ifail strideF info batchCount

rocsolverDgesvdxStridedBatched ::
  HasCallStack =>
  RocblasHandle ->
  RocblasSvect ->
  RocblasSvect ->
  RocblasSrange ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  Double ->
  Double ->
  RocblasInt ->
  RocblasInt ->
  DevicePtr RocblasInt ->
  DevicePtr CDouble ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr CDouble ->
  RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasStride ->
  DevicePtr RocblasInt ->
  RocblasInt ->
  IO ()
rocsolverDgesvdxStridedBatched (RocblasHandle h) leftSvect rightSvect srange m n (DevicePtr a) lda strideA vl vu il iu (DevicePtr nsv) (DevicePtr s) strideS (DevicePtr u) ldu strideU (DevicePtr v) ldv strideV (DevicePtr ifail) strideF (DevicePtr info) batchCount = do
  validateGesvdxStridedBatchedArgs "rocsolverDgesvdxStridedBatched" leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount
  checkRocblas "rocsolver_dgesvdx_strided_batched" =<< c_rocsolver_dgesvdx_strided_batched h leftSvect rightSvect srange m n a lda strideA (CDouble vl) (CDouble vu) il iu nsv s strideS u ldu strideU v ldv strideV ifail strideF info batchCount

validateGesvdArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdArgs callName leftSvect rightSvect m n lda ldu ldv = do
  let k = min m n
      isAll sv = sv == RocblasSvect 191
      isSingular sv = sv == RocblasSvect 192
      isOverwrite sv = sv == RocblasSvect 193
  when (m < 0) $ throwArgumentError callName "m must be >= 0"
  when (n < 0) $ throwArgumentError callName "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError callName "lda must be >= max 1 m"
  when (isOverwrite leftSvect && isOverwrite rightSvect) $ throwArgumentError callName "left_svect and right_svect cannot both be overwrite"
  when ((isAll leftSvect || isSingular leftSvect) && ldu < max 1 m) $ throwArgumentError callName "ldu must be >= max 1 m when left_svect is all or singular"
  when (not (isAll leftSvect || isSingular leftSvect) && ldu < 1) $ throwArgumentError callName "ldu must be >= 1"
  when (isAll rightSvect && ldv < max 1 n) $ throwArgumentError callName "ldv must be >= max 1 n when right_svect is all"
  when (isSingular rightSvect && ldv < max 1 k) $ throwArgumentError callName "ldv must be >= max 1 (min m n) when right_svect is singular"
  when (not (isAll rightSvect || isSingular rightSvect) && ldv < 1) $ throwArgumentError callName "ldv must be >= 1"

validateGesddArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesddArgs callName leftSvect rightSvect m n lda ldu ldv = do
  let k = min m n
      isAll sv = sv == RocblasSvect 191
      isSingular sv = sv == RocblasSvect 192
      isOverwrite sv = sv == RocblasSvect 193
  when (m < 0) $ throwArgumentError callName "m must be >= 0"
  when (n < 0) $ throwArgumentError callName "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError callName "lda must be >= max 1 m"
  when (isOverwrite leftSvect) $ throwArgumentError callName "left_svect overwrite is not supported by gesdd"
  when (isOverwrite rightSvect) $ throwArgumentError callName "right_svect overwrite is not supported by gesdd"
  when ((isAll leftSvect || isSingular leftSvect) && ldu < max 1 m) $ throwArgumentError callName "ldu must be >= max 1 m when left_svect is all or singular"
  when (not (isAll leftSvect || isSingular leftSvect) && ldu < 1) $ throwArgumentError callName "ldu must be >= 1"
  when (isAll rightSvect && ldv < max 1 n) $ throwArgumentError callName "ldv must be >= max 1 n when right_svect is all"
  when (isSingular rightSvect && ldv < max 1 k) $ throwArgumentError callName "ldv must be >= max 1 (min m n) when right_svect is singular"
  when (not (isAll rightSvect || isSingular rightSvect) && ldv < 1) $ throwArgumentError callName "ldv must be >= 1"

validateGesddBatchedArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesddBatchedArgs callName leftSvect rightSvect m n lda ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesddArgs callName leftSvect rightSvect m n lda ldu ldv

validateGesddStridedBatchedArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesddStridedBatchedArgs callName leftSvect rightSvect m n lda ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesddArgs callName leftSvect rightSvect m n lda ldu ldv

validateGesvdjArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdjArgs callName leftSvect rightSvect m n lda maxSweeps ldu ldv = do
  let k = min m n
      isAll sv = sv == RocblasSvect 191
      isSingular sv = sv == RocblasSvect 192
      isOverwrite sv = sv == RocblasSvect 193
  when (m < 0) $ throwArgumentError callName "m must be >= 0"
  when (n < 0) $ throwArgumentError callName "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError callName "lda must be >= max 1 m"
  when (maxSweeps <= 0) $ throwArgumentError callName "max_sweeps must be > 0"
  when (isOverwrite leftSvect) $ throwArgumentError callName "left_svect overwrite is not supported by gesvdj"
  when (isOverwrite rightSvect) $ throwArgumentError callName "right_svect overwrite is not supported by gesvdj"
  when ((isAll leftSvect || isSingular leftSvect) && ldu < max 1 m) $ throwArgumentError callName "ldu must be >= max 1 m when left_svect is all or singular"
  when (not (isAll leftSvect || isSingular leftSvect) && ldu < 1) $ throwArgumentError callName "ldu must be >= 1"
  when (isAll rightSvect && ldv < max 1 n) $ throwArgumentError callName "ldv must be >= max 1 n when right_svect is all"
  when (isSingular rightSvect && ldv < max 1 k) $ throwArgumentError callName "ldv must be >= max 1 (min m n) when right_svect is singular"
  when (not (isAll rightSvect || isSingular rightSvect) && ldv < 1) $ throwArgumentError callName "ldv must be >= 1"

validateGesvdjBatchedArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdjBatchedArgs callName leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesvdjArgs callName leftSvect rightSvect m n lda maxSweeps ldu ldv

validateGesvdjStridedBatchedArgs :: HasCallStack => String -> RocblasSvect -> RocblasSvect -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdjStridedBatchedArgs callName leftSvect rightSvect m n lda maxSweeps ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesvdjArgs callName leftSvect rightSvect m n lda maxSweeps ldu ldv

validateGesvdxArgs :: (HasCallStack, Ord a, Num a) => String -> RocblasSvect -> RocblasSvect -> RocblasSrange -> RocblasInt -> RocblasInt -> RocblasInt -> a -> a -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdxArgs callName leftSvect rightSvect srange m n lda vl vu il iu ldu ldv = do
  let k = min m n
      isSingular sv = sv == RocblasSvect 192
      isNone sv = sv == RocblasSvect 194
      isAllRange sr = sr == RocblasSrange 261
      isValueRange sr = sr == RocblasSrange 262
      isIndexRange sr = sr == RocblasSrange 263
      expectedNsv = if isIndexRange srange then max 0 (iu - il + 1) else k
  when (m < 0) $ throwArgumentError callName "m must be >= 0"
  when (n < 0) $ throwArgumentError callName "n must be >= 0"
  when (lda < max 1 m) $ throwArgumentError callName "lda must be >= max 1 m"
  when (not (isSingular leftSvect || isNone leftSvect)) $ throwArgumentError callName "left_svect must be singular or none"
  when (not (isSingular rightSvect || isNone rightSvect)) $ throwArgumentError callName "right_svect must be singular or none"
  when (isSingular leftSvect && ldu < max 1 m) $ throwArgumentError callName "ldu must be >= max 1 m when left_svect is singular"
  when (isNone leftSvect && ldu < 1) $ throwArgumentError callName "ldu must be >= 1"
  when (isSingular rightSvect && ldv < max 1 expectedNsv) $ throwArgumentError callName "ldv must be >= expected nsv when right_svect is singular"
  when (isNone rightSvect && ldv < 1) $ throwArgumentError callName "ldv must be >= 1"
  when (not (isAllRange srange || isValueRange srange || isIndexRange srange)) $ throwArgumentError callName "srange must be all, value, or index"
  when (isValueRange srange && (vl < 0 || vl >= vu)) $ throwArgumentError callName "value range requires 0 <= vl < vu"
  when (isIndexRange srange && k == 0 && (il /= 1 || iu /= 0)) $ throwArgumentError callName "for empty matrices, index range requires il == 1 and iu == 0"
  when (isIndexRange srange && k > 0 && (il < 1 || il > iu || iu > k)) $ throwArgumentError callName "index range requires 1 <= il <= iu <= min(m,n)"

validateGesvdxBatchedArgs :: (HasCallStack, Ord a, Num a) => String -> RocblasSvect -> RocblasSvect -> RocblasSrange -> RocblasInt -> RocblasInt -> RocblasInt -> a -> a -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdxBatchedArgs callName leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesvdxArgs callName leftSvect rightSvect srange m n lda vl vu il iu ldu ldv

validateGesvdxStridedBatchedArgs :: (HasCallStack, Ord a, Num a) => String -> RocblasSvect -> RocblasSvect -> RocblasSrange -> RocblasInt -> RocblasInt -> RocblasInt -> a -> a -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> RocblasInt -> IO ()
validateGesvdxStridedBatchedArgs callName leftSvect rightSvect srange m n lda vl vu il iu ldu ldv batchCount = do
  when (batchCount < 0) $ throwArgumentError callName "batch_count must be >= 0"
  validateGesvdxArgs callName leftSvect rightSvect srange m n lda vl vu il iu ldu ldv
