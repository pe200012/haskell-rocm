module ROCm.RocFFT
  ( module ROCm.RocFFT.Types
  , module ROCm.RocFFT.Error

    -- * Global setup
  , rocfftSetup
  , rocfftCleanup
  , withRocfft

    -- * Plans
  , rocfftPlanDescriptionCreate
  , rocfftPlanDescriptionDestroy
  , withRocfftPlanDescription
  , rocfftPlanDescriptionSetDataLayout
  , rocfftPlanDescriptionSetScaleFactor
  , rocfftGetVersionString
  , rocfftPlanCreate
  , rocfftPlanDestroy
  , withRocfftPlan
  , rocfftPlanGetWorkBufferSize
  , rocfftPlanGetPrint

    -- * Execution info
  , rocfftExecutionInfoCreate
  , rocfftExecutionInfoDestroy
  , withRocfftExecutionInfo
  , rocfftExecutionInfoSetWorkBuffer
  , rocfftExecutionInfoSetStream
  , rocfftExecutionInfoSetLoadCallback
  , rocfftExecutionInfoSetStoreCallback

    -- * Execute
  , rocfftExecute
  ) where

import Control.Exception (bracket, bracket_)
import Data.List.NonEmpty (nonEmpty)
import Foreign.C.String (peekCString)
import Foreign.C.Types (CChar, CDouble(..), CSize)
import Foreign.Marshal.Alloc (alloca, allocaBytes)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import Foreign.Storable (peek)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Exception (throwArgumentError)
import ROCm.FFI.Core.Types
  ( DevicePtr(..)
  , HipStream(..)
  , RocfftExecInfo(..)
  , RocfftPlan(..)
  , RocfftPlanDescription(..)
  )
import ROCm.RocFFT.Error (checkRocfft)
import ROCm.RocFFT.Raw
  ( c_rocfft_cleanup
  , c_rocfft_plan_description_create
  , c_rocfft_plan_description_destroy
  , c_rocfft_plan_description_set_data_layout
  , c_rocfft_plan_description_set_scale_factor
  , c_rocfft_get_version_string
  , c_rocfft_execute
  , c_rocfft_execution_info_create
  , c_rocfft_execution_info_destroy
  , c_rocfft_execution_info_set_load_callback
  , c_rocfft_execution_info_set_store_callback
  , c_rocfft_execution_info_set_stream
  , c_rocfft_execution_info_set_work_buffer
  , c_rocfft_plan_create
  , c_rocfft_plan_destroy
  , c_rocfft_plan_get_print
  , c_rocfft_plan_get_work_buffer_size
  , c_rocfft_setup
  )
import ROCm.RocFFT.Types

-- Global setup --------------------------------------------------------------

rocfftSetup :: HasCallStack => IO ()
rocfftSetup = checkRocfft "rocfft_setup" =<< c_rocfft_setup

rocfftCleanup :: HasCallStack => IO ()
rocfftCleanup = checkRocfft "rocfft_cleanup" =<< c_rocfft_cleanup

withRocfft :: HasCallStack => IO a -> IO a
withRocfft = bracket_ rocfftSetup rocfftCleanup

-- Plans ---------------------------------------------------------------------

rocfftPlanDescriptionCreate :: HasCallStack => IO RocfftPlanDescription
rocfftPlanDescriptionCreate =
  alloca $ \pDesc -> do
    checkRocfft "rocfft_plan_description_create" =<< c_rocfft_plan_description_create pDesc
    RocfftPlanDescription <$> peek pDesc

rocfftPlanDescriptionDestroy :: HasCallStack => RocfftPlanDescription -> IO ()
rocfftPlanDescriptionDestroy (RocfftPlanDescription p) =
  checkRocfft "rocfft_plan_description_destroy" =<< c_rocfft_plan_description_destroy p

withRocfftPlanDescription :: HasCallStack => (RocfftPlanDescription -> IO a) -> IO a
withRocfftPlanDescription = bracket rocfftPlanDescriptionCreate rocfftPlanDescriptionDestroy

rocfftPlanDescriptionSetScaleFactor :: HasCallStack => RocfftPlanDescription -> Double -> IO ()
rocfftPlanDescriptionSetScaleFactor (RocfftPlanDescription desc) scaleFactor = do
  let cScale = CDouble scaleFactor
  checkRocfft "rocfft_plan_description_set_scale_factor" =<< c_rocfft_plan_description_set_scale_factor desc cScale

rocfftGetVersionString :: HasCallStack => IO String
rocfftGetVersionString =
  allocaBytes 256 $ \buf -> do
    checkRocfft "rocfft_get_version_string" =<< c_rocfft_get_version_string (castPtr buf) 256
    peekCString (castPtr buf :: Ptr CChar)

rocfftPlanDescriptionSetDataLayout ::
  HasCallStack =>
  RocfftPlanDescription ->
  RocfftArrayType ->
  RocfftArrayType ->
  Maybe [CSize] ->
  Maybe [CSize] ->
  [CSize] ->
  CSize ->
  [CSize] ->
  CSize ->
  IO ()
rocfftPlanDescriptionSetDataLayout (RocfftPlanDescription desc) inType outType mInOffsets mOutOffsets inStrides inDistance outStrides outDistance = do
  case (nonEmpty inStrides, nonEmpty outStrides) of
    (Nothing, _) -> throwArgumentError "rocfftPlanDescriptionSetDataLayout" "inStrides must not be empty"
    (_, Nothing) -> throwArgumentError "rocfftPlanDescriptionSetDataLayout" "outStrides must not be empty"
    _ -> pure ()

  withMaybeArrayMaybe mInOffsets $ \pInOffsets ->
    withMaybeArrayMaybe mOutOffsets $ \pOutOffsets ->
      withArray inStrides $ \pInStrides ->
        withArray outStrides $ \pOutStrides ->
          checkRocfft "rocfft_plan_description_set_data_layout" =<<
            c_rocfft_plan_description_set_data_layout
              desc
              inType
              outType
              pInOffsets
              pOutOffsets
              (fromIntegral (length inStrides))
              pInStrides
              inDistance
              (fromIntegral (length outStrides))
              pOutStrides
              outDistance

rocfftPlanCreate ::
  HasCallStack =>
  RocfftResultPlacement ->
  RocfftTransformType ->
  RocfftPrecision ->
  [CSize] ->
  CSize ->
  Maybe RocfftPlanDescription ->
  IO RocfftPlan
rocfftPlanCreate placement transformType precision lengths numberOfTransforms mDesc = do
  let dims = length lengths
  if dims < 1 || dims > 3
    then throwArgumentError "rocfftPlanCreate" "lengths must have 1..3 elements (rocFFT supports 1D/2D/3D plans)"
    else pure ()

  if numberOfTransforms < 1
    then throwArgumentError "rocfftPlanCreate" "numberOfTransforms must be >= 1"
    else pure ()

  let descPtr = maybe nullPtr (\(RocfftPlanDescription p) -> p) mDesc
  withArray lengths $ \pLengths ->
    alloca $ \pPlan -> do
      checkRocfft "rocfft_plan_create" =<<
        c_rocfft_plan_create
          pPlan
          placement
          transformType
          precision
          (fromIntegral dims)
          pLengths
          numberOfTransforms
          descPtr
      RocfftPlan <$> peek pPlan

rocfftPlanDestroy :: HasCallStack => RocfftPlan -> IO ()
rocfftPlanDestroy (RocfftPlan p) = checkRocfft "rocfft_plan_destroy" =<< c_rocfft_plan_destroy p

withRocfftPlan :: HasCallStack => IO RocfftPlan -> (RocfftPlan -> IO a) -> IO a
withRocfftPlan acquire = bracket acquire rocfftPlanDestroy

rocfftPlanGetWorkBufferSize :: HasCallStack => RocfftPlan -> IO CSize
rocfftPlanGetWorkBufferSize (RocfftPlan p) =
  alloca $ \pBytes -> do
    checkRocfft "rocfft_plan_get_work_buffer_size" =<< c_rocfft_plan_get_work_buffer_size p pBytes
    peek pBytes

rocfftPlanGetPrint :: HasCallStack => RocfftPlan -> IO ()
rocfftPlanGetPrint (RocfftPlan p) =
  checkRocfft "rocfft_plan_get_print" =<< c_rocfft_plan_get_print p

-- Execution info ------------------------------------------------------------

rocfftExecutionInfoCreate :: HasCallStack => IO RocfftExecInfo
rocfftExecutionInfoCreate =
  alloca $ \pInfo -> do
    checkRocfft "rocfft_execution_info_create" =<< c_rocfft_execution_info_create pInfo
    RocfftExecInfo <$> peek pInfo

rocfftExecutionInfoDestroy :: HasCallStack => RocfftExecInfo -> IO ()
rocfftExecutionInfoDestroy (RocfftExecInfo p) = checkRocfft "rocfft_execution_info_destroy" =<< c_rocfft_execution_info_destroy p

withRocfftExecutionInfo :: HasCallStack => (RocfftExecInfo -> IO a) -> IO a
withRocfftExecutionInfo = bracket rocfftExecutionInfoCreate rocfftExecutionInfoDestroy

rocfftExecutionInfoSetWorkBuffer :: HasCallStack => RocfftExecInfo -> DevicePtr a -> CSize -> IO ()
rocfftExecutionInfoSetWorkBuffer (RocfftExecInfo info) (DevicePtr workBuf) bytes =
  checkRocfft "rocfft_execution_info_set_work_buffer" =<< c_rocfft_execution_info_set_work_buffer info (castPtr workBuf) bytes

rocfftExecutionInfoSetStream :: HasCallStack => RocfftExecInfo -> HipStream -> IO ()
rocfftExecutionInfoSetStream (RocfftExecInfo info) (HipStream s) =
  checkRocfft "rocfft_execution_info_set_stream" =<< c_rocfft_execution_info_set_stream info (castPtr s)

rocfftExecutionInfoSetLoadCallback ::
  HasCallStack =>
  RocfftExecInfo ->
  Maybe [Ptr ()] ->
  Maybe [Ptr ()] ->
  CSize ->
  IO ()
rocfftExecutionInfoSetLoadCallback (RocfftExecInfo info) mFns mData sharedMemBytes = do
  validateCallbackLists "rocfftExecutionInfoSetLoadCallback" mFns mData
  withMaybePtrArray mFns $ \pFns ->
    withMaybePtrArray mData $ \pData ->
      checkRocfft "rocfft_execution_info_set_load_callback" =<<
        c_rocfft_execution_info_set_load_callback info pFns pData sharedMemBytes

rocfftExecutionInfoSetStoreCallback ::
  HasCallStack =>
  RocfftExecInfo ->
  Maybe [Ptr ()] ->
  Maybe [Ptr ()] ->
  CSize ->
  IO ()
rocfftExecutionInfoSetStoreCallback (RocfftExecInfo info) mFns mData sharedMemBytes = do
  validateCallbackLists "rocfftExecutionInfoSetStoreCallback" mFns mData
  withMaybePtrArray mFns $ \pFns ->
    withMaybePtrArray mData $ \pData ->
      checkRocfft "rocfft_execution_info_set_store_callback" =<<
        c_rocfft_execution_info_set_store_callback info pFns pData sharedMemBytes

-- Execute -------------------------------------------------------------------

rocfftExecute :: HasCallStack => RocfftPlan -> [Ptr ()] -> [Ptr ()] -> Maybe RocfftExecInfo -> IO ()
rocfftExecute (RocfftPlan plan) inBufs outBufs mInfo = do
  case inBufs of
    [] -> throwArgumentError "rocfftExecute" "inBufs must not be empty"
    _ -> pure ()

  let infoPtr = maybe nullPtr (\(RocfftExecInfo p) -> p) mInfo

  withArray inBufs $ \pIn -> do
    case outBufs of
      [] -> checkRocfft "rocfft_execute" =<< c_rocfft_execute plan pIn nullPtr infoPtr
      _ ->
        withArray outBufs $ \pOut ->
          checkRocfft "rocfft_execute" =<< c_rocfft_execute plan pIn pOut infoPtr

withMaybeArrayMaybe :: Maybe [CSize] -> (Ptr CSize -> IO a) -> IO a
withMaybeArrayMaybe Nothing k = k nullPtr
withMaybeArrayMaybe (Just xs) k = withArray xs k

withMaybePtrArray :: Maybe [Ptr ()] -> (Ptr (Ptr ()) -> IO a) -> IO a
withMaybePtrArray Nothing k = k nullPtr
withMaybePtrArray (Just xs) k = withArray xs k

validateCallbackLists :: HasCallStack => String -> Maybe [Ptr ()] -> Maybe [Ptr ()] -> IO ()
validateCallbackLists _ Nothing Nothing = pure ()
validateCallbackLists callName (Just fns) (Just dat)
  | length fns == length dat = pure ()
  | otherwise = throwArgumentError callName "function pointer list and callback data list must have the same length"
validateCallbackLists callName _ _ = throwArgumentError callName "function pointer list and callback data list must either both be Nothing or both be Just"

