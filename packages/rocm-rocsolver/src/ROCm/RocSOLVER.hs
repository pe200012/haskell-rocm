module ROCm.RocSOLVER
  ( rocsolverSpotrf
  , rocsolverDpotrf
  , rocsolverSposv
  , rocsolverDposv
  ) where

import Control.Monad (when)
import Foreign.C.Types (CDouble, CFloat)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types (DevicePtr(..), RocblasHandle(..))
import ROCm.RocBLAS.C.Types (RocblasInt)
import ROCm.RocBLAS.Error (checkRocblas)
import ROCm.RocBLAS.Types (RocblasFill)
import ROCm.RocSOLVER.Raw
  ( c_rocsolver_dposv
  , c_rocsolver_dpotrf
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
