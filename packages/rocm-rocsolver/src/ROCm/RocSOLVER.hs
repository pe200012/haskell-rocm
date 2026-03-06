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
  ) where

import Control.Monad (when)
import Foreign.C.Types (CDouble, CFloat)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types (DevicePtr(..), RocblasHandle(..))
import ROCm.RocBLAS.C.Types (RocblasInt)
import ROCm.RocBLAS.Error (checkRocblas)
import ROCm.RocBLAS.Types (RocblasFill, RocblasOperation)
import ROCm.RocSOLVER.Raw
  ( c_rocsolver_dgeqrf
  , c_rocsolver_dgesv
  , c_rocsolver_dgetrf
  , c_rocsolver_dgetrs
  , c_rocsolver_dorgqr
  , c_rocsolver_dposv
  , c_rocsolver_dpotrf
  , c_rocsolver_sgeqrf
  , c_rocsolver_sgesv
  , c_rocsolver_sgetrf
  , c_rocsolver_sgetrs
  , c_rocsolver_sorgqr
  , c_rocsolver_sposv
  , c_rocsolver_spotrf
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
