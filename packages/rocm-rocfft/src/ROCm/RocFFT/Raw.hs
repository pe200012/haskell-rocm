{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocFFT.Raw
  ( c_rocfft_setup
  , c_rocfft_cleanup
  , c_rocfft_plan_description_create
  , c_rocfft_plan_description_destroy
  , c_rocfft_plan_description_set_data_layout
  , c_rocfft_plan_description_set_scale_factor
  , c_rocfft_get_version_string
  , c_rocfft_plan_create
  , c_rocfft_plan_destroy
  , c_rocfft_plan_get_work_buffer_size
  , c_rocfft_execution_info_create
  , c_rocfft_execution_info_destroy
  , c_rocfft_execution_info_set_work_buffer
  , c_rocfft_execution_info_set_stream
  , c_rocfft_execution_info_set_load_callback
  , c_rocfft_execution_info_set_store_callback
  , c_rocfft_execute
  ) where

import Foreign.C.Types (CChar, CDouble(..), CInt(..), CSize(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (RocfftExecInfoTag, RocfftPlanDescriptionTag, RocfftPlanTag)
import ROCm.RocFFT.Types
  ( RocfftArrayType(..)
  , RocfftPrecision(..)
  , RocfftResultPlacement(..)
  , RocfftStatus(..)
  , RocfftTransformType(..)
  )

foreign import ccall safe "rocfft_setup"
  c_rocfft_setup :: IO RocfftStatus

foreign import ccall safe "rocfft_cleanup"
  c_rocfft_cleanup :: IO RocfftStatus

foreign import ccall safe "rocfft_plan_description_create"
  c_rocfft_plan_description_create :: Ptr (Ptr RocfftPlanDescriptionTag) -> IO RocfftStatus

foreign import ccall safe "rocfft_plan_description_destroy"
  c_rocfft_plan_description_destroy :: Ptr RocfftPlanDescriptionTag -> IO RocfftStatus

foreign import ccall safe "rocfft_plan_description_set_data_layout"
  c_rocfft_plan_description_set_data_layout ::
    Ptr RocfftPlanDescriptionTag ->
    RocfftArrayType ->
    RocfftArrayType ->
    Ptr CSize ->
    Ptr CSize ->
    CSize ->
    Ptr CSize ->
    CSize ->
    CSize ->
    Ptr CSize ->
    CSize ->
    IO RocfftStatus

foreign import ccall safe "rocfft_plan_description_set_scale_factor"
  c_rocfft_plan_description_set_scale_factor :: Ptr RocfftPlanDescriptionTag -> CDouble -> IO RocfftStatus

foreign import ccall safe "rocfft_get_version_string"
  c_rocfft_get_version_string :: Ptr CChar -> CSize -> IO RocfftStatus

foreign import ccall safe "rocfft_plan_create"
  c_rocfft_plan_create ::
    Ptr (Ptr RocfftPlanTag) ->
    RocfftResultPlacement ->
    RocfftTransformType ->
    RocfftPrecision ->
    CSize ->
    Ptr CSize ->
    CSize ->
    Ptr RocfftPlanDescriptionTag ->
    IO RocfftStatus

foreign import ccall safe "rocfft_plan_destroy"
  c_rocfft_plan_destroy :: Ptr RocfftPlanTag -> IO RocfftStatus

foreign import ccall safe "rocfft_plan_get_work_buffer_size"
  c_rocfft_plan_get_work_buffer_size :: Ptr RocfftPlanTag -> Ptr CSize -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_create"
  c_rocfft_execution_info_create :: Ptr (Ptr RocfftExecInfoTag) -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_destroy"
  c_rocfft_execution_info_destroy :: Ptr RocfftExecInfoTag -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_set_work_buffer"
  c_rocfft_execution_info_set_work_buffer :: Ptr RocfftExecInfoTag -> Ptr () -> CSize -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_set_stream"
  c_rocfft_execution_info_set_stream :: Ptr RocfftExecInfoTag -> Ptr () -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_set_load_callback"
  c_rocfft_execution_info_set_load_callback :: Ptr RocfftExecInfoTag -> Ptr (Ptr ()) -> Ptr (Ptr ()) -> CSize -> IO RocfftStatus

foreign import ccall safe "rocfft_execution_info_set_store_callback"
  c_rocfft_execution_info_set_store_callback :: Ptr RocfftExecInfoTag -> Ptr (Ptr ()) -> Ptr (Ptr ()) -> CSize -> IO RocfftStatus

foreign import ccall safe "rocfft_execute"
  c_rocfft_execute :: Ptr RocfftPlanTag -> Ptr (Ptr ()) -> Ptr (Ptr ()) -> Ptr RocfftExecInfoTag -> IO RocfftStatus
