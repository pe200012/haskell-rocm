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
  , rocsparseCreateCsrDescr
  , rocsparseDestroySpMatDescr
  , withRocsparseCsrDescr
  , rocsparseCreateDnVecDescr
  , rocsparseDestroyDnVecDescr
  , withRocsparseDnVecDescr
  , rocsparseCreateSpMVDescr
  , rocsparseDestroySpMVDescr
  , withRocsparseSpMVDescr
  , rocsparseConfigureSV2SpMV
  , rocsparseConfigureDV2SpMV
  , rocsparseSV2SpMVBufferSize
  , rocsparseDV2SpMVBufferSize
  , rocsparseSV2SpMV
  , rocsparseDV2SpMV
  ) where

import Control.Exception (bracket, finally)
import Control.Monad (when)
import Data.Int (Int64)
import Foreign.C.Types (CDouble(..), CFloat(..), CInt, CSize)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import Foreign.Storable (peek, poke, sizeOf)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types
  ( DevicePtr(..)
  , HipStream(..)
  , RocsparseDnVecDescr(..)
  , RocsparseHandle(..)
  , RocsparseMatDescr(..)
  , RocsparseSpMVDescr(..)
  , RocsparseSpMatDescr(..)
  )
import ROCm.RocSPARSE.C.Types
import ROCm.RocSPARSE.Error (checkRocsparse)
import ROCm.RocSPARSE.Raw
  ( c_rocsparse_create_csr_descr
  , c_rocsparse_create_dnvec_descr
  , c_rocsparse_create_handle
  , c_rocsparse_create_mat_descr
  , c_rocsparse_create_spmv_descr
  , c_rocsparse_dcsrmv
  , c_rocsparse_destroy_dnvec_descr
  , c_rocsparse_destroy_error
  , c_rocsparse_destroy_handle
  , c_rocsparse_destroy_mat_descr
  , c_rocsparse_destroy_spmat_descr
  , c_rocsparse_destroy_spmv_descr
  , c_rocsparse_get_version
  , c_rocsparse_scsrmv
  , c_rocsparse_set_mat_index_base
  , c_rocsparse_set_mat_type
  , c_rocsparse_set_stream
  , c_rocsparse_spmv_set_input
  , c_rocsparse_v2_spmv
  , c_rocsparse_v2_spmv_buffer_size
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

rocsparseCreateCsrDescr ::
  HasCallStack =>
  Int64 ->
  Int64 ->
  Int64 ->
  DevicePtr rowPtrTy ->
  DevicePtr colIndTy ->
  DevicePtr valTy ->
  RocsparseIndexType ->
  RocsparseIndexType ->
  RocsparseIndexBase ->
  RocsparseDataType ->
  IO RocsparseSpMatDescr
rocsparseCreateCsrDescr rows cols nnz (DevicePtr rowPtr) (DevicePtr colInd) (DevicePtr vals) rowPtrType colIndType idxBase dataType = do
  when (rows < 0) $ throwArgumentError "rocsparseCreateCsrDescr" "rows must be >= 0"
  when (cols < 0) $ throwArgumentError "rocsparseCreateCsrDescr" "cols must be >= 0"
  when (nnz < 0) $ throwArgumentError "rocsparseCreateCsrDescr" "nnz must be >= 0"
  alloca $ \pDescr -> do
    checkRocsparse "rocsparse_create_csr_descr" =<< c_rocsparse_create_csr_descr pDescr rows cols nnz (castPtr rowPtr) (castPtr colInd) (castPtr vals) rowPtrType colIndType idxBase dataType
    RocsparseSpMatDescr <$> peek pDescr

rocsparseDestroySpMatDescr :: HasCallStack => RocsparseSpMatDescr -> IO ()
rocsparseDestroySpMatDescr (RocsparseSpMatDescr descr) =
  checkRocsparse "rocsparse_destroy_spmat_descr" =<< c_rocsparse_destroy_spmat_descr descr

withRocsparseCsrDescr ::
  HasCallStack =>
  Int64 ->
  Int64 ->
  Int64 ->
  DevicePtr rowPtrTy ->
  DevicePtr colIndTy ->
  DevicePtr valTy ->
  RocsparseIndexType ->
  RocsparseIndexType ->
  RocsparseIndexBase ->
  RocsparseDataType ->
  (RocsparseSpMatDescr -> IO a) ->
  IO a
withRocsparseCsrDescr rows cols nnz rowPtr colInd vals rowPtrType colIndType idxBase dataType =
  bracket
    (rocsparseCreateCsrDescr rows cols nnz rowPtr colInd vals rowPtrType colIndType idxBase dataType)
    rocsparseDestroySpMatDescr

rocsparseCreateDnVecDescr ::
  HasCallStack =>
  Int64 ->
  DevicePtr valTy ->
  RocsparseDataType ->
  IO RocsparseDnVecDescr
rocsparseCreateDnVecDescr size (DevicePtr vals) dataType = do
  when (size < 0) $ throwArgumentError "rocsparseCreateDnVecDescr" "size must be >= 0"
  alloca $ \pDescr -> do
    checkRocsparse "rocsparse_create_dnvec_descr" =<< c_rocsparse_create_dnvec_descr pDescr size (castPtr vals) dataType
    RocsparseDnVecDescr <$> peek pDescr

rocsparseDestroyDnVecDescr :: HasCallStack => RocsparseDnVecDescr -> IO ()
rocsparseDestroyDnVecDescr (RocsparseDnVecDescr descr) =
  checkRocsparse "rocsparse_destroy_dnvec_descr" =<< c_rocsparse_destroy_dnvec_descr descr

withRocsparseDnVecDescr ::
  HasCallStack =>
  Int64 ->
  DevicePtr valTy ->
  RocsparseDataType ->
  (RocsparseDnVecDescr -> IO a) ->
  IO a
withRocsparseDnVecDescr size vals dataType =
  bracket (rocsparseCreateDnVecDescr size vals dataType) rocsparseDestroyDnVecDescr

rocsparseCreateSpMVDescr :: HasCallStack => IO RocsparseSpMVDescr
rocsparseCreateSpMVDescr =
  alloca $ \pDescr -> do
    checkRocsparse "rocsparse_create_spmv_descr" =<< c_rocsparse_create_spmv_descr pDescr
    RocsparseSpMVDescr <$> peek pDescr

rocsparseDestroySpMVDescr :: HasCallStack => RocsparseSpMVDescr -> IO ()
rocsparseDestroySpMVDescr (RocsparseSpMVDescr descr) =
  checkRocsparse "rocsparse_destroy_spmv_descr" =<< c_rocsparse_destroy_spmv_descr descr

withRocsparseSpMVDescr :: HasCallStack => (RocsparseSpMVDescr -> IO a) -> IO a
withRocsparseSpMVDescr = bracket rocsparseCreateSpMVDescr rocsparseDestroySpMVDescr

rocsparseConfigureSV2SpMV ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseOperation ->
  IO ()
rocsparseConfigureSV2SpMV handle spmvDescr trans =
  configureV2SpMV handle spmvDescr trans RocsparseDataTypeF32R

rocsparseConfigureDV2SpMV ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseOperation ->
  IO ()
rocsparseConfigureDV2SpMV handle spmvDescr trans =
  configureV2SpMV handle spmvDescr trans RocsparseDataTypeF64R

rocsparseSV2SpMVBufferSize ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  RocsparseDnVecDescr ->
  RocsparseV2SpMVStage ->
  IO CSize
rocsparseSV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr stage =
  rocsparseV2SpMVBufferSizeInternal handle spmvDescr aDescr xDescr yDescr stage

rocsparseDV2SpMVBufferSize ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  RocsparseDnVecDescr ->
  RocsparseV2SpMVStage ->
  IO CSize
rocsparseDV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr stage =
  rocsparseV2SpMVBufferSizeInternal handle spmvDescr aDescr xDescr yDescr stage

rocsparseSV2SpMV ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  RocsparseDnVecDescr ->
  Float ->
  Float ->
  RocsparseV2SpMVStage ->
  CSize ->
  Maybe (DevicePtr ()) ->
  IO ()
rocsparseSV2SpMV handle spmvDescr aDescr xDescr yDescr alpha beta stage bufferBytes mBuffer = do
  tempBuffer <- requireTempBuffer "rocsparseSV2SpMV" bufferBytes mBuffer
  alloca $ \pAlpha ->
    alloca $ \pBeta -> do
      poke pAlpha (CFloat alpha)
      poke pBeta (CFloat beta)
      rocsparseV2SpMVInternal handle spmvDescr (castPtr pAlpha) aDescr xDescr (castPtr pBeta) yDescr stage bufferBytes tempBuffer

rocsparseDV2SpMV ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  RocsparseDnVecDescr ->
  Double ->
  Double ->
  RocsparseV2SpMVStage ->
  CSize ->
  Maybe (DevicePtr ()) ->
  IO ()
rocsparseDV2SpMV handle spmvDescr aDescr xDescr yDescr alpha beta stage bufferBytes mBuffer = do
  tempBuffer <- requireTempBuffer "rocsparseDV2SpMV" bufferBytes mBuffer
  alloca $ \pAlpha ->
    alloca $ \pBeta -> do
      poke pAlpha (CDouble alpha)
      poke pBeta (CDouble beta)
      rocsparseV2SpMVInternal handle spmvDescr (castPtr pAlpha) aDescr xDescr (castPtr pBeta) yDescr stage bufferBytes tempBuffer

configureV2SpMV ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseOperation ->
  RocsparseDataType ->
  IO ()
configureV2SpMV handle spmvDescr trans dataType = do
  setSpMVInputCInt "alg" handle spmvDescr RocsparseSpMVInputAlg (unRocsparseSpMVAlg RocsparseSpMVAlgCsrRowsplit)
  setSpMVInputCInt "operation" handle spmvDescr RocsparseSpMVInputOperation (unRocsparseOperation trans)
  setSpMVInputCInt "scalar_datatype" handle spmvDescr RocsparseSpMVInputScalarDataType (unRocsparseDataType dataType)
  setSpMVInputCInt "compute_datatype" handle spmvDescr RocsparseSpMVInputComputeDataType (unRocsparseDataType dataType)

setSpMVInputCInt ::
  HasCallStack =>
  String ->
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMVInput ->
  CInt ->
  IO ()
setSpMVInputCInt label (RocsparseHandle h) (RocsparseSpMVDescr descr) input value =
  withRocsparseErrorSlot $ \pErr ->
    alloca $ \pValue -> do
      poke pValue value
      checkRocsparse ("rocsparse_spmv_set_input(" <> label <> ")") =<< c_rocsparse_spmv_set_input h descr input (castPtr pValue) (fromIntegral (sizeOf value)) pErr

rocsparseV2SpMVBufferSizeInternal ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  RocsparseDnVecDescr ->
  RocsparseV2SpMVStage ->
  IO CSize
rocsparseV2SpMVBufferSizeInternal (RocsparseHandle h) (RocsparseSpMVDescr spmvDescr) (RocsparseSpMatDescr aDescr) (RocsparseDnVecDescr xDescr) (RocsparseDnVecDescr yDescr) stage =
  withRocsparseErrorSlot $ \pErr ->
    alloca $ \pBytes -> do
      checkRocsparse "rocsparse_v2_spmv_buffer_size" =<< c_rocsparse_v2_spmv_buffer_size h spmvDescr aDescr xDescr yDescr stage pBytes pErr
      peek pBytes

rocsparseV2SpMVInternal ::
  HasCallStack =>
  RocsparseHandle ->
  RocsparseSpMVDescr ->
  Ptr () ->
  RocsparseSpMatDescr ->
  RocsparseDnVecDescr ->
  Ptr () ->
  RocsparseDnVecDescr ->
  RocsparseV2SpMVStage ->
  CSize ->
  Ptr () ->
  IO ()
rocsparseV2SpMVInternal (RocsparseHandle h) (RocsparseSpMVDescr spmvDescr) alphaPtr (RocsparseSpMatDescr aDescr) (RocsparseDnVecDescr xDescr) betaPtr (RocsparseDnVecDescr yDescr) stage bufferBytes tempBuffer =
  withRocsparseErrorSlot $ \pErr ->
    checkRocsparse "rocsparse_v2_spmv" =<< c_rocsparse_v2_spmv h spmvDescr alphaPtr aDescr xDescr betaPtr yDescr stage bufferBytes tempBuffer pErr

withRocsparseErrorSlot :: HasCallStack => (Ptr () -> IO a) -> IO a
withRocsparseErrorSlot action =
  alloca $ \pErr -> do
    poke pErr nullPtr
    action (castPtr pErr)
      `finally` do
        err <- peek pErr
        when (err /= nullPtr) $ do
          checkRocsparse "rocsparse_destroy_error" =<< c_rocsparse_destroy_error err

requireTempBuffer ::
  HasCallStack =>
  String ->
  CSize ->
  Maybe (DevicePtr ()) ->
  IO (Ptr ())
requireTempBuffer callName bufferBytes mBuffer
  | bufferBytes == 0 = pure (maybe nullPtr (\(DevicePtr p) -> p) mBuffer)
  | otherwise =
      case mBuffer of
        Just (DevicePtr p) -> pure p
        Nothing -> throwArgumentError callName "temp buffer is required when buffer size is non-zero"
