{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocSPARSE.Raw
  ( c_rocsparse_create_handle
  , c_rocsparse_destroy_handle
  , c_rocsparse_set_stream
  , c_rocsparse_get_version
  , c_rocsparse_create_mat_descr
  , c_rocsparse_destroy_mat_descr
  , c_rocsparse_set_mat_index_base
  , c_rocsparse_set_mat_type
  , c_rocsparse_destroy_error
  , c_rocsparse_get_status_name
  , c_rocsparse_get_status_description
  , c_rocsparse_scsrmv
  , c_rocsparse_dcsrmv
  , c_rocsparse_create_csr_descr
  , c_rocsparse_destroy_spmat_descr
  , c_rocsparse_create_dnvec_descr
  , c_rocsparse_destroy_dnvec_descr
  , c_rocsparse_create_spmv_descr
  , c_rocsparse_destroy_spmv_descr
  , c_rocsparse_spmv_set_input
  , c_rocsparse_v2_spmv_buffer_size
  , c_rocsparse_v2_spmv
  ) where

import Data.Int (Int64)
import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..), CSize(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types
  ( HipStreamTag
  , RocsparseDnVecDescrTag
  , RocsparseHandleTag
  , RocsparseMatDescrTag
  , RocsparseSpMVDescrTag
  , RocsparseSpMatDescrTag
  )
import ROCm.RocSPARSE.C.Types (RocsparseInt)
import ROCm.RocSPARSE.Types
  ( RocsparseDataType(..)
  , RocsparseIndexBase(..)
  , RocsparseIndexType(..)
  , RocsparseMatrixType(..)
  , RocsparseOperation(..)
  , RocsparseSpMVInput(..)
  , RocsparseStatus(..)
  , RocsparseV2SpMVStage(..)
  )

foreign import ccall safe "rocsparse_create_handle"
  c_rocsparse_create_handle :: Ptr (Ptr RocsparseHandleTag) -> IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_handle"
  c_rocsparse_destroy_handle :: Ptr RocsparseHandleTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_set_stream"
  c_rocsparse_set_stream :: Ptr RocsparseHandleTag -> Ptr HipStreamTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_get_version"
  c_rocsparse_get_version :: Ptr RocsparseHandleTag -> Ptr CInt -> IO RocsparseStatus

foreign import ccall safe "rocsparse_create_mat_descr"
  c_rocsparse_create_mat_descr :: Ptr (Ptr RocsparseMatDescrTag) -> IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_mat_descr"
  c_rocsparse_destroy_mat_descr :: Ptr RocsparseMatDescrTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_set_mat_index_base"
  c_rocsparse_set_mat_index_base :: Ptr RocsparseMatDescrTag -> RocsparseIndexBase -> IO RocsparseStatus

foreign import ccall safe "rocsparse_set_mat_type"
  c_rocsparse_set_mat_type :: Ptr RocsparseMatDescrTag -> RocsparseMatrixType -> IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_error"
  c_rocsparse_destroy_error :: Ptr () -> IO RocsparseStatus

foreign import ccall unsafe "rocsparse_get_status_name"
  c_rocsparse_get_status_name :: RocsparseStatus -> IO CString

foreign import ccall unsafe "rocsparse_get_status_description"
  c_rocsparse_get_status_description :: RocsparseStatus -> IO CString

foreign import ccall safe "rocsparse_scsrmv"
  c_rocsparse_scsrmv ::
    Ptr RocsparseHandleTag ->
    RocsparseOperation ->
    RocsparseInt ->
    RocsparseInt ->
    RocsparseInt ->
    Ptr CFloat ->
    Ptr RocsparseMatDescrTag ->
    Ptr CFloat ->
    Ptr RocsparseInt ->
    Ptr RocsparseInt ->
    Ptr () ->
    Ptr CFloat ->
    Ptr CFloat ->
    Ptr CFloat ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_dcsrmv"
  c_rocsparse_dcsrmv ::
    Ptr RocsparseHandleTag ->
    RocsparseOperation ->
    RocsparseInt ->
    RocsparseInt ->
    RocsparseInt ->
    Ptr CDouble ->
    Ptr RocsparseMatDescrTag ->
    Ptr CDouble ->
    Ptr RocsparseInt ->
    Ptr RocsparseInt ->
    Ptr () ->
    Ptr CDouble ->
    Ptr CDouble ->
    Ptr CDouble ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_create_csr_descr"
  c_rocsparse_create_csr_descr ::
    Ptr (Ptr RocsparseSpMatDescrTag) ->
    Int64 ->
    Int64 ->
    Int64 ->
    Ptr () ->
    Ptr () ->
    Ptr () ->
    RocsparseIndexType ->
    RocsparseIndexType ->
    RocsparseIndexBase ->
    RocsparseDataType ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_spmat_descr"
  c_rocsparse_destroy_spmat_descr :: Ptr RocsparseSpMatDescrTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_create_dnvec_descr"
  c_rocsparse_create_dnvec_descr ::
    Ptr (Ptr RocsparseDnVecDescrTag) ->
    Int64 ->
    Ptr () ->
    RocsparseDataType ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_dnvec_descr"
  c_rocsparse_destroy_dnvec_descr :: Ptr RocsparseDnVecDescrTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_create_spmv_descr"
  c_rocsparse_create_spmv_descr :: Ptr (Ptr RocsparseSpMVDescrTag) -> IO RocsparseStatus

foreign import ccall safe "rocsparse_destroy_spmv_descr"
  c_rocsparse_destroy_spmv_descr :: Ptr RocsparseSpMVDescrTag -> IO RocsparseStatus

foreign import ccall safe "rocsparse_spmv_set_input"
  c_rocsparse_spmv_set_input ::
    Ptr RocsparseHandleTag ->
    Ptr RocsparseSpMVDescrTag ->
    RocsparseSpMVInput ->
    Ptr () ->
    CSize ->
    Ptr () ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_v2_spmv_buffer_size"
  c_rocsparse_v2_spmv_buffer_size ::
    Ptr RocsparseHandleTag ->
    Ptr RocsparseSpMVDescrTag ->
    Ptr RocsparseSpMatDescrTag ->
    Ptr RocsparseDnVecDescrTag ->
    Ptr RocsparseDnVecDescrTag ->
    RocsparseV2SpMVStage ->
    Ptr CSize ->
    Ptr () ->
    IO RocsparseStatus

foreign import ccall safe "rocsparse_v2_spmv"
  c_rocsparse_v2_spmv ::
    Ptr RocsparseHandleTag ->
    Ptr RocsparseSpMVDescrTag ->
    Ptr () ->
    Ptr RocsparseSpMatDescrTag ->
    Ptr RocsparseDnVecDescrTag ->
    Ptr () ->
    Ptr RocsparseDnVecDescrTag ->
    RocsparseV2SpMVStage ->
    CSize ->
    Ptr () ->
    Ptr () ->
    IO RocsparseStatus
