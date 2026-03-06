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
  , c_rocsparse_get_status_name
  , c_rocsparse_get_status_description
  , c_rocsparse_scsrmv
  , c_rocsparse_dcsrmv
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CDouble(..), CFloat(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (HipStreamTag, RocsparseHandleTag, RocsparseMatDescrTag)
import ROCm.RocSPARSE.C.Types (RocsparseInt)
import ROCm.RocSPARSE.Types
  ( RocsparseIndexBase(..)
  , RocsparseMatrixType(..)
  , RocsparseOperation(..)
  , RocsparseStatus(..)
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
