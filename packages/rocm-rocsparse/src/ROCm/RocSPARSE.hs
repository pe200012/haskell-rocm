module ROCm.RocSPARSE
  ( module ROCm.RocSPARSE.C.Types
  , module ROCm.RocSPARSE.Types
  , module ROCm.RocSPARSE.Error
  , rocsparseCreateHandle
  , rocsparseDestroyHandle
  , withRocsparseHandle
  , rocsparseSetStream
  , rocsparseGetVersion
  , rocsparseCreateMatDescr
  , rocsparseDestroyMatDescr
  , withRocsparseMatDescr
  , rocsparseSetMatIndexBase
  , rocsparseSetMatType
  , rocsparseScsrmv
  , rocsparseDcsrmv
  ) where

import Control.Exception (bracket)
import Control.Monad (when)
import Foreign.C.Types (CDouble(..), CFloat(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (nullPtr)
import Foreign.Storable (peek, poke)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types
  ( DevicePtr(..)
  , HipStream(..)
  , RocsparseHandle(..)
  , RocsparseMatDescr(..)
  )
import ROCm.RocSPARSE.C.Types
import ROCm.RocSPARSE.Error (checkRocsparse)
import ROCm.RocSPARSE.Raw
  ( c_rocsparse_create_handle
  , c_rocsparse_create_mat_descr
  , c_rocsparse_dcsrmv
  , c_rocsparse_destroy_handle
  , c_rocsparse_destroy_mat_descr
  , c_rocsparse_get_version
  , c_rocsparse_scsrmv
  , c_rocsparse_set_mat_index_base
  , c_rocsparse_set_mat_type
  , c_rocsparse_set_stream
  )
import ROCm.RocSPARSE.Types

rocsparseCreateHandle :: HasCallStack => IO RocsparseHandle
rocsparseCreateHandle =
  alloca $ \pHandle -> do
    checkRocsparse "rocsparse_create_handle" =<< c_rocsparse_create_handle pHandle
    RocsparseHandle <$> peek pHandle

rocsparseDestroyHandle :: HasCallStack => RocsparseHandle -> IO ()
rocsparseDestroyHandle (RocsparseHandle h) =
  checkRocsparse "rocsparse_destroy_handle" =<< c_rocsparse_destroy_handle h

withRocsparseHandle :: HasCallStack => (RocsparseHandle -> IO a) -> IO a
withRocsparseHandle = bracket rocsparseCreateHandle rocsparseDestroyHandle

rocsparseSetStream :: HasCallStack => RocsparseHandle -> HipStream -> IO ()
rocsparseSetStream (RocsparseHandle h) (HipStream s) =
  checkRocsparse "rocsparse_set_stream" =<< c_rocsparse_set_stream h s

rocsparseGetVersion :: HasCallStack => RocsparseHandle -> IO Int
rocsparseGetVersion (RocsparseHandle h) =
  alloca $ \pVersion -> do
    checkRocsparse "rocsparse_get_version" =<< c_rocsparse_get_version h pVersion
    fromIntegral <$> peek pVersion

rocsparseCreateMatDescr :: HasCallStack => IO RocsparseMatDescr
rocsparseCreateMatDescr =
  alloca $ \pDescr -> do
    checkRocsparse "rocsparse_create_mat_descr" =<< c_rocsparse_create_mat_descr pDescr
    RocsparseMatDescr <$> peek pDescr

rocsparseDestroyMatDescr :: HasCallStack => RocsparseMatDescr -> IO ()
rocsparseDestroyMatDescr (RocsparseMatDescr d) =
  checkRocsparse "rocsparse_destroy_mat_descr" =<< c_rocsparse_destroy_mat_descr d

withRocsparseMatDescr :: HasCallStack => (RocsparseMatDescr -> IO a) -> IO a
withRocsparseMatDescr = bracket rocsparseCreateMatDescr rocsparseDestroyMatDescr

rocsparseSetMatIndexBase :: HasCallStack => RocsparseMatDescr -> RocsparseIndexBase -> IO ()
rocsparseSetMatIndexBase (RocsparseMatDescr d) base =
  checkRocsparse "rocsparse_set_mat_index_base" =<< c_rocsparse_set_mat_index_base d base

rocsparseSetMatType :: HasCallStack => RocsparseMatDescr -> RocsparseMatrixType -> IO ()
rocsparseSetMatType (RocsparseMatDescr d) ty =
  checkRocsparse "rocsparse_set_mat_type" =<< c_rocsparse_set_mat_type d ty

rocsparseScsrmv ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseOperation ->
  RocsparseInt ->
  RocsparseInt ->
  RocsparseInt ->
  Float ->
  RocsparseMatDescr ->
  DevicePtr CFloat ->
  DevicePtr RocsparseInt ->
  DevicePtr RocsparseInt ->
  DevicePtr CFloat ->
  Float ->
  DevicePtr CFloat ->
  IO ()
rocsparseScsrmv (RocsparseHandle h) trans m n nnz alpha (RocsparseMatDescr descr) (DevicePtr csrVal) (DevicePtr csrRowPtr) (DevicePtr csrColInd) (DevicePtr x) beta (DevicePtr y) = do
  when (m < 0) $ throwArgumentError "rocsparseScsrmv" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsparseScsrmv" "n must be >= 0"
  when (nnz < 0) $ throwArgumentError "rocsparseScsrmv" "nnz must be >= 0"
  alloca $ \pAlpha ->
    alloca $ \pBeta -> do
      poke pAlpha (CFloat alpha)
      poke pBeta (CFloat beta)
      checkRocsparse "rocsparse_scsrmv" =<< c_rocsparse_scsrmv h trans m n nnz pAlpha descr csrVal csrRowPtr csrColInd nullPtr x pBeta y

rocsparseDcsrmv ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseOperation ->
  RocsparseInt ->
  RocsparseInt ->
  RocsparseInt ->
  Double ->
  RocsparseMatDescr ->
  DevicePtr CDouble ->
  DevicePtr RocsparseInt ->
  DevicePtr RocsparseInt ->
  DevicePtr CDouble ->
  Double ->
  DevicePtr CDouble ->
  IO ()
rocsparseDcsrmv (RocsparseHandle h) trans m n nnz alpha (RocsparseMatDescr descr) (DevicePtr csrVal) (DevicePtr csrRowPtr) (DevicePtr csrColInd) (DevicePtr x) beta (DevicePtr y) = do
  when (m < 0) $ throwArgumentError "rocsparseDcsrmv" "m must be >= 0"
  when (n < 0) $ throwArgumentError "rocsparseDcsrmv" "n must be >= 0"
  when (nnz < 0) $ throwArgumentError "rocsparseDcsrmv" "nnz must be >= 0"
  alloca $ \pAlpha ->
    alloca $ \pBeta -> do
      poke pAlpha (CDouble alpha)
      poke pBeta (CDouble beta)
      checkRocsparse "rocsparse_dcsrmv" =<< c_rocsparse_dcsrmv h trans m n nnz pAlpha descr csrVal csrRowPtr csrColInd nullPtr x pBeta y
