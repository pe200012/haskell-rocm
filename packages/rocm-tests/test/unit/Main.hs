{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Data.Bits ((.&.), (.|.))

import Control.Exception (SomeException, displayException, try)
import Control.Monad (forM)
import Foreign.C.String (peekCString)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (castPtrToFunPtr, intPtrToPtr, nullPtr)
import Foreign.Storable (peek, poke)
import System.Exit (exitFailure, exitSuccess)

import HeaderConstants
import RocRandHeaderConstants
import ROCm.FFI.Core.Types (HipStream(..))
import ROCm.HIP
  ( hipDriverGetVersion
  , hipGetLastError
  , hipPeekAtLastError
  , hipRuntimeGetVersion
  )
import ROCm.HIP.GraphTypes
  ( HipGraphInstantiateFlags(..)
  , HipHostNodeParams(..)
  , HipMemsetParams(..)
  , pattern HipGraphExecUpdateSuccess
  , pattern HipGraphInstantiateFlagAutoFreeOnLaunch
  , pattern HipGraphInstantiateFlagDeviceLaunch
  , pattern HipGraphInstantiateFlagUpload
  , pattern HipGraphInstantiateFlagUseNodePriority
  , pattern HipStreamCaptureModeGlobal
  , pattern HipStreamCaptureModeRelaxed
  , pattern HipStreamCaptureModeThreadLocal
  , pattern HipStreamCaptureStatusActive
  , pattern HipStreamCaptureStatusInvalidated
  , pattern HipStreamCaptureStatusNone
  )
import ROCm.HIP.KernelNodeParams (HipKernelNodeParams(..))
import ROCm.HIP.LaunchAttributes
  ( HipLaunchAttribute(..)
  , withHipLaunchAttributes
  , hipLaunchAttributeCooperative
  , hipLaunchAttributePriority
  )
import ROCm.HIP.LaunchConfig (HipLaunchConfig(..))
import ROCm.HIP.RTC (hiprtcVersion)
import ROCm.HIP.Raw (c_hipGetErrorString)
import ROCm.HIP.Types
  ( HipDim3(..)
  , HipError(..)
  , HipFunctionAddress(..)
  , HipEventFlags(..)
  , HipEventRecordFlags(..)
  , HipHostMallocFlags(..)
  , HipHostRegisterFlags(..)
  , HipMemcpyKind(..)
  , HipStreamFlags(..)
  , pattern HipErrorInvalidValue
  , pattern HipErrorNotReady
  , pattern HipEventBlockingSync
  , pattern HipEventDisableTiming
  , pattern HipEventRecordExternal
  , pattern HipHostMallocPortable
  , pattern HipHostRegisterMapped
  , pattern HipMemcpyDeviceToDeviceNoCU
  , pattern HipMemcpyHostToDevice
  , pattern HipStreamNonBlocking
  , pattern HipSuccess
  )
import ROCm.RocBLAS.Error (rocblasStatusToString)
import ROCm.RocBLAS.Types
  ( RocblasEvect(..)
  , RocblasFill(..)
  , RocblasOperation(..)
  , RocblasSrange(..)
  , RocblasStatus(..)
  , RocblasSvect(..)
  , RocblasWorkmode(..)
  , pattern RocblasEvectOriginal
  , pattern RocblasFillLower
  , pattern RocblasInPlace
  , pattern RocblasOperationNone
  , pattern RocblasSrangeIndex
  , pattern RocblasSrangeValue
  , pattern RocblasStatusSuccess
  , pattern RocblasSvectSingular
  )
import ROCm.RocFFT
  ( rocfftExecutionInfoSetLoadCallback
  , rocfftExecutionInfoSetStoreCallback
  , rocfftGetVersionString
  , withRocfft
  , withRocfftExecutionInfo
  )
import ROCm.RocFFT.Error (rocfftStatusToString)
import ROCm.RocFFT.Types
  ( RocfftArrayType(..)
  , RocfftPrecision(..)
  , RocfftResultPlacement(..)
  , RocfftStatus(..)
  , RocfftTransformType(..)
  , pattern RocfftArrayTypeComplexInterleaved
  , pattern RocfftArrayTypeHermitianInterleaved
  , pattern RocfftArrayTypeReal
  , pattern RocfftArrayTypeUnset
  , pattern RocfftPlacementInplace
  , pattern RocfftPlacementNotInplace
  , pattern RocfftPrecisionSingle
  , pattern RocfftStatusSuccess
  , pattern RocfftTransformTypeComplexForward
  , pattern RocfftTransformTypeRealForward
  , pattern RocfftTransformTypeRealInverse
  )
import ROCm.RocRAND (rocrandGetVersion)
import ROCm.RocRAND.Error (rocRandStatusToString)
import ROCm.RocRAND.Types
  ( RocRandRngType(..)
  , RocRandStatus(..)
  , pattern RocRandRngPseudoDefault
  , pattern RocRandRngPseudoPhilox4x32_10
  , pattern RocRandRngPseudoXorwow
  , pattern RocRandStatusAllocationFailed
  , pattern RocRandStatusDoublePrecisionRequired
  , pattern RocRandStatusInternalError
  , pattern RocRandStatusLaunchFailure
  , pattern RocRandStatusLengthNotMultiple
  , pattern RocRandStatusNotCreated
  , pattern RocRandStatusOutOfRange
  , pattern RocRandStatusSuccess
  , pattern RocRandStatusTypeError
  , pattern RocRandStatusVersionMismatch
  )
import ROCm.RocSPARSE.Error (rocsparseStatusToString)
import ROCm.RocSPARSE.Types
  ( RocsparseDataType(..)
  , RocsparseIndexBase(..)
  , RocsparseIndexType(..)
  , RocsparseMatrixType(..)
  , RocsparseOperation(..)
  , RocsparseSpMVAlg(..)
  , RocsparseStatus(..)
  , RocsparseV2SpMVStage(..)
  , pattern RocsparseDataTypeF32R
  , pattern RocsparseIndexBaseZero
  , pattern RocsparseIndexTypeI32
  , pattern RocsparseMatrixTypeGeneral
  , pattern RocsparseOperationNone
  , pattern RocsparseSpMVAlgCsrAdaptive
  , pattern RocsparseSpMVAlgCsrRowsplit
  , pattern RocsparseStatusSuccess
  , pattern RocsparseV2SpMVStageAnalysis
  )

main :: IO ()
main = do
  results <-
    forM
      [ ("hip-error-patterns", hipErrorPatternsUnit)
      , ("hip-host-malloc-flags-pattern", hipHostFlagsUnit)
      , ("hip-stream-flags-patterns", hipStreamFlagsUnit)
      , ("hip-event-flags-patterns", hipEventFlagsUnit)
      , ("hip-event-record-flags-patterns", hipEventRecordFlagsUnit)
      , ("hip-host-register-flags-patterns", hipHostRegisterFlagsUnit)
      , ("hip-memcpy-kind-patterns", hipMemcpyKindPatternsUnit)
      , ("rocblas-fill-patterns", rocblasFillPatternsUnit)
      , ("rocblas-operation-patterns", rocblasOperationPatternsUnit)
      , ("rocblas-evect-patterns", rocblasEvectPatternsUnit)
      , ("rocblas-svect-patterns", rocblasSvectPatternsUnit)
      , ("rocblas-workmode-patterns", rocblasWorkmodePatternsUnit)
      , ("rocblas-srange-patterns", rocblasSrangePatternsUnit)
      , ("rocblas-srange-value-patterns", rocblasSrangeValuePatternsUnit)
      , ("hip-success-string", hipSuccessStringUnit)
      , ("hip-last-error-reset", hipLastErrorResetUnit)
      , ("hip-runtime-version", hipRuntimeVersionUnit)
      , ("hip-driver-version", hipDriverVersionUnit)
      , ("hiprtc-version", hiprtcVersionUnit)
      , ("hip-launch-config-storable", hipLaunchConfigStorableUnit)
      , ("hip-launch-attribute-cooperative-roundtrip", hipLaunchAttributeCooperativeRoundTripUnit)
      , ("hip-launch-attribute-priority-roundtrip", hipLaunchAttributePriorityRoundTripUnit)
      , ("hip-launch-attributes-empty-helper", hipLaunchAttributesEmptyHelperUnit)
      , ("hip-host-node-params-storable", hipHostNodeParamsStorableUnit)
      , ("hip-memset-node-params-storable", hipMemsetNodeParamsStorableUnit)
      , ("hip-kernel-node-params-storable", hipKernelNodeParamsStorableUnit)
      , ("hip-stream-capture-mode-patterns", hipStreamCaptureModePatternsUnit)
      , ("hip-stream-capture-status-patterns", hipStreamCaptureStatusPatternsUnit)
      , ("hip-graph-instantiate-flag-patterns", hipGraphInstantiateFlagPatternsUnit)
      , ("hip-graph-update-result-pattern", hipGraphUpdateResultPatternUnit)
      , ("rocblas-status-string", rocblasStatusStringUnit)
      , ("rocfft-status-patterns", rocfftStatusPatternsUnit)
      , ("rocfft-type-patterns", rocfftTypePatternsUnit)
      , ("rocfft-status-string", rocfftStatusStringUnit)
      , ("rocfft-version-string", rocfftVersionStringUnit)
      , ("rocfft-callback-clear", rocfftCallbackClearUnit)
      , ("rocrand-status-patterns", rocrandStatusPatternsUnit)
      , ("rocrand-rng-type-patterns", rocrandRngTypePatternsUnit)
      , ("rocrand-status-string", rocrandStatusStringUnit)
      , ("rocrand-version", rocrandVersionUnit)
      , ("rocsparse-status-patterns", rocsparseStatusPatternsUnit)
      , ("rocsparse-operation-patterns", rocsparseOperationPatternsUnit)
      , ("rocsparse-index-base-patterns", rocsparseIndexBasePatternsUnit)
      , ("rocsparse-matrix-type-patterns", rocsparseMatrixTypePatternsUnit)
      , ("rocsparse-index-type-patterns", rocsparseIndexTypePatternsUnit)
      , ("rocsparse-data-type-patterns", rocsparseDataTypePatternsUnit)
      , ("rocsparse-v2-spmv-stage-patterns", rocsparseV2SpMVStagePatternsUnit)
      , ("rocsparse-spmv-alg-patterns", rocsparseSpMVAlgPatternsUnit)
      , ("rocsparse-status-string", rocsparseStatusStringUnit)
      ]
      $ \(name, action) -> do
        outcome <- try action :: IO (Either SomeException ())
        case outcome of
          Left e -> do
            putStrLn ("FAIL  " <> name <> ": " <> displayException e)
            pure False
          Right () -> do
            putStrLn ("PASS  " <> name)
            pure True
  if and results then exitSuccess else exitFailure

expectEq :: (Eq a, Show a) => String -> a -> a -> IO ()
expectEq label actual expected =
  if actual == expected
    then pure ()
    else fail (label <> ": expected " <> show expected <> ", got " <> show actual)

hipErrorPatternsUnit :: IO ()
hipErrorPatternsUnit = do
  expectEq "HipSuccess" HipSuccess (HipError hipSuccessHeader)
  expectEq "HipErrorInvalidValue" HipErrorInvalidValue (HipError hipErrorInvalidValueHeader)
  expectEq "HipErrorNotReady" HipErrorNotReady (HipError hipErrorNotReadyHeader)

hipHostFlagsUnit :: IO ()
hipHostFlagsUnit =
  expectEq "HipHostMallocPortable" HipHostMallocPortable (HipHostMallocFlags hipHostMallocPortableHeader)

hipStreamFlagsUnit :: IO ()
hipStreamFlagsUnit =
  expectEq "HipStreamNonBlocking" HipStreamNonBlocking (HipStreamFlags hipStreamNonBlockingHeader)

hipEventFlagsUnit :: IO ()
hipEventFlagsUnit = do
  expectEq "HipEventBlockingSync" HipEventBlockingSync (HipEventFlags hipEventBlockingSyncHeader)
  expectEq "HipEventDisableTiming" HipEventDisableTiming (HipEventFlags hipEventDisableTimingHeader)

hipEventRecordFlagsUnit :: IO ()
hipEventRecordFlagsUnit =
  expectEq "HipEventRecordExternal" HipEventRecordExternal (HipEventRecordFlags hipEventRecordExternalHeader)

hipHostRegisterFlagsUnit :: IO ()
hipHostRegisterFlagsUnit =
  expectEq "HipHostRegisterMapped" HipHostRegisterMapped (HipHostRegisterFlags hipHostRegisterMappedHeader)

hipMemcpyKindPatternsUnit :: IO ()
hipMemcpyKindPatternsUnit = do
  expectEq "HipMemcpyHostToDevice" HipMemcpyHostToDevice (HipMemcpyKind hipMemcpyHostToDeviceHeader)
  expectEq "HipMemcpyDeviceToDeviceNoCU" HipMemcpyDeviceToDeviceNoCU (HipMemcpyKind hipMemcpyDeviceToDeviceNoCUHeader)

rocblasFillPatternsUnit :: IO ()
rocblasFillPatternsUnit =
  expectEq "RocblasFillLower" RocblasFillLower (RocblasFill rocblasFillLowerHeader)

rocblasOperationPatternsUnit :: IO ()
rocblasOperationPatternsUnit =
  expectEq "RocblasOperationNone" RocblasOperationNone (RocblasOperation rocblasOperationNoneHeader)

rocblasEvectPatternsUnit :: IO ()
rocblasEvectPatternsUnit =
  expectEq "RocblasEvectOriginal" RocblasEvectOriginal (RocblasEvect rocblasEvectOriginalHeader)

rocblasSvectPatternsUnit :: IO ()
rocblasSvectPatternsUnit =
  expectEq "RocblasSvectSingular" RocblasSvectSingular (RocblasSvect rocblasSvectSingularHeader)

rocblasWorkmodePatternsUnit :: IO ()
rocblasWorkmodePatternsUnit =
  expectEq "RocblasInPlace" RocblasInPlace (RocblasWorkmode rocblasInPlaceHeader)

rocblasSrangePatternsUnit :: IO ()
rocblasSrangePatternsUnit =
  expectEq "RocblasSrangeIndex" RocblasSrangeIndex (RocblasSrange rocblasSrangeIndexHeader)

rocblasSrangeValuePatternsUnit :: IO ()
rocblasSrangeValuePatternsUnit =
  expectEq "RocblasSrangeValue" RocblasSrangeValue (RocblasSrange rocblasSrangeValueHeader)

hipSuccessStringUnit :: IO ()
hipSuccessStringUnit = do
  cstr <- c_hipGetErrorString (HipError 0)
  msg <- peekCString cstr
  if null msg then fail "empty hip success string" else pure ()

hipLastErrorResetUnit :: IO ()
hipLastErrorResetUnit = do
  _ <- hipPeekAtLastError
  _ <- hipGetLastError
  st2 <- hipGetLastError
  if st2 == HipError 0 then pure () else fail ("expected HipSuccess, got " <> show st2)

hipRuntimeVersionUnit :: IO ()
hipRuntimeVersionUnit = do
  version <- hipRuntimeGetVersion
  if version > 0 then pure () else fail ("invalid HIP runtime version: " <> show version)

hipDriverVersionUnit :: IO ()
hipDriverVersionUnit = do
  version <- hipDriverGetVersion
  if version > 0 then pure () else fail ("invalid HIP driver version: " <> show version)

hiprtcVersionUnit :: IO ()
hiprtcVersionUnit = do
  (majorVersion, minorVersion) <- hiprtcVersion
  if majorVersion >= 0 && minorVersion >= 0
    then pure ()
    else fail ("invalid HIPRTC version: " <> show (majorVersion, minorVersion))

hipLaunchConfigStorableUnit :: IO ()
hipLaunchConfigStorableUnit = do
  let config =
        HipLaunchConfig
          { hipLaunchConfigGridDim = HipDim3 7 3 1
          , hipLaunchConfigBlockDim = HipDim3 64 1 1
          , hipLaunchConfigDynamicSmemBytes = 128 :: CSize
          , hipLaunchConfigStream = Just (HipStream (intPtrToPtr 0x1234))
          , hipLaunchConfigAttrs = intPtrToPtr 0x5678
          , hipLaunchConfigNumAttrs = 0
          }
  alloca $ \pConfig -> do
    poke pConfig config
    roundTrip <- peek pConfig
    expectEq "HipLaunchConfig round-trip" roundTrip config

hipLaunchAttributeCooperativeRoundTripUnit :: IO ()
hipLaunchAttributeCooperativeRoundTripUnit = do
  let attr = hipLaunchAttributeCooperative True
  alloca $ \pAttr -> do
    poke pAttr attr
    roundTrip <- peek pAttr
    expectEq "HipLaunchAttribute cooperative round-trip" roundTrip attr

hipLaunchAttributePriorityRoundTripUnit :: IO ()
hipLaunchAttributePriorityRoundTripUnit = do
  let attr = hipLaunchAttributePriority 7
  alloca $ \pAttr -> do
    poke pAttr attr
    roundTrip <- peek pAttr
    expectEq "HipLaunchAttribute priority round-trip" roundTrip attr

hipLaunchAttributesEmptyHelperUnit :: IO ()
hipLaunchAttributesEmptyHelperUnit =
  withHipLaunchAttributes [] $ \pAttrs attrCount -> do
    if pAttrs == nullPtr && attrCount == 0
      then pure ()
      else fail ("expected nullPtr/0 for empty launch attributes, got ptr=" <> show pAttrs <> ", count=" <> show attrCount)

hipHostNodeParamsStorableUnit :: IO ()
hipHostNodeParamsStorableUnit = do
  let params =
        HipHostNodeParams
          { hipHostNodeFn = castPtrToFunPtr (intPtrToPtr 0x2345)
          , hipHostNodeUserData = intPtrToPtr 0x3456
          }
  alloca $ \pParams -> do
    poke pParams params
    roundTrip <- peek pParams
    expectEq "HipHostNodeParams round-trip" roundTrip params

hipMemsetNodeParamsStorableUnit :: IO ()
hipMemsetNodeParamsStorableUnit = do
  let params =
        HipMemsetParams
          { hipMemsetDst = intPtrToPtr 0x4567
          , hipMemsetElementSize = 1
          , hipMemsetHeight = 1
          , hipMemsetPitch = 16
          , hipMemsetValue = 0x7f
          , hipMemsetWidth = 16
          }
  alloca $ \pParams -> do
    poke pParams params
    roundTrip <- peek pParams
    expectEq "HipMemsetParams round-trip" roundTrip params

hipKernelNodeParamsStorableUnit :: IO ()
hipKernelNodeParamsStorableUnit = do
  let params =
        HipKernelNodeParams
          { hipKernelNodeBlockDim = HipDim3 7 8 9
          , hipKernelNodeExtra = intPtrToPtr 0x11
          , hipKernelNodeFunc = HipFunctionAddress (intPtrToPtr 0x22)
          , hipKernelNodeGridDim = HipDim3 3 4 5
          , hipKernelNodeKernelParams = intPtrToPtr 0x33
          , hipKernelNodeSharedMemBytes = 64
          }
  alloca $ \pParams -> do
    poke pParams params
    roundTrip <- peek pParams
    expectEq "HipKernelNodeParams round-trip" roundTrip params
    if hipKernelNodeExtra roundTrip == nullPtr || hipKernelNodeKernelParams roundTrip == nullPtr
      then fail "HipKernelNodeParams pointer fields unexpectedly became null"
      else pure ()

hipStreamCaptureModePatternsUnit :: IO ()
hipStreamCaptureModePatternsUnit = do
  let modes = [HipStreamCaptureModeGlobal, HipStreamCaptureModeThreadLocal, HipStreamCaptureModeRelaxed]
  if length modes == length (foldr (\x acc -> if x `elem` acc then acc else x : acc) [] modes)
    then pure ()
    else fail ("expected distinct stream capture modes, got=" <> show modes)

hipStreamCaptureStatusPatternsUnit :: IO ()
hipStreamCaptureStatusPatternsUnit = do
  let statuses = [HipStreamCaptureStatusNone, HipStreamCaptureStatusActive, HipStreamCaptureStatusInvalidated]
  if length statuses == length (foldr (\x acc -> if x `elem` acc then acc else x : acc) [] statuses)
    then pure ()
    else fail ("expected distinct stream capture statuses, got=" <> show statuses)

hipGraphInstantiateFlagPatternsUnit :: IO ()
hipGraphInstantiateFlagPatternsUnit = do
  let flags = HipGraphInstantiateFlagUpload .|. HipGraphInstantiateFlagUseNodePriority
  if flags /= HipGraphInstantiateFlags 0 && (flags .&. HipGraphInstantiateFlagUpload) == HipGraphInstantiateFlagUpload
    then pure ()
    else fail ("unexpected graph instantiate flag combination: " <> show flags)

hipGraphUpdateResultPatternUnit :: IO ()
hipGraphUpdateResultPatternUnit =
  expectEq "HipGraphExecUpdateSuccess" HipGraphExecUpdateSuccess HipGraphExecUpdateSuccess

rocblasStatusStringUnit :: IO ()
rocblasStatusStringUnit = do
  expectEq "RocblasStatusSuccess" RocblasStatusSuccess (RocblasStatus 0)
  msg <- rocblasStatusToString RocblasStatusSuccess
  if null msg then fail "empty rocblas status string" else pure ()

rocfftStatusPatternsUnit :: IO ()
rocfftStatusPatternsUnit =
  expectEq "RocfftStatusSuccess" RocfftStatusSuccess (RocfftStatus rocfftStatusSuccessHeader)

rocfftTypePatternsUnit :: IO ()
rocfftTypePatternsUnit = do
  expectEq "RocfftTransformTypeComplexForward" RocfftTransformTypeComplexForward (RocfftTransformType rocfftTransformTypeComplexForwardHeader)
  expectEq "RocfftTransformTypeRealForward" RocfftTransformTypeRealForward (RocfftTransformType rocfftTransformTypeRealForwardHeader)
  expectEq "RocfftTransformTypeRealInverse" RocfftTransformTypeRealInverse (RocfftTransformType rocfftTransformTypeRealInverseHeader)
  expectEq "RocfftPrecisionSingle" RocfftPrecisionSingle (RocfftPrecision rocfftPrecisionSingleHeader)
  expectEq "RocfftPlacementInplace" RocfftPlacementInplace (RocfftResultPlacement rocfftPlacementInplaceHeader)
  expectEq "RocfftPlacementNotInplace" RocfftPlacementNotInplace (RocfftResultPlacement rocfftPlacementNotInplaceHeader)
  expectEq "RocfftArrayTypeComplexInterleaved" RocfftArrayTypeComplexInterleaved (RocfftArrayType rocfftArrayTypeComplexInterleavedHeader)
  expectEq "RocfftArrayTypeReal" RocfftArrayTypeReal (RocfftArrayType rocfftArrayTypeRealHeader)
  expectEq "RocfftArrayTypeHermitianInterleaved" RocfftArrayTypeHermitianInterleaved (RocfftArrayType rocfftArrayTypeHermitianInterleavedHeader)
  expectEq "RocfftArrayTypeUnset" RocfftArrayTypeUnset (RocfftArrayType rocfftArrayTypeUnsetHeader)

rocfftStatusStringUnit :: IO ()
rocfftStatusStringUnit = do
  let msg = rocfftStatusToString RocfftStatusSuccess
  if null msg then fail "empty rocfft status string" else pure ()

rocfftVersionStringUnit :: IO ()
rocfftVersionStringUnit = withRocfft $ do
  msg <- rocfftGetVersionString
  if null msg then fail "empty rocfft version string" else pure ()

rocfftCallbackClearUnit :: IO ()
rocfftCallbackClearUnit =
  withRocfft $
    withRocfftExecutionInfo $ \info -> do
      rocfftExecutionInfoSetLoadCallback info Nothing Nothing 0
      rocfftExecutionInfoSetStoreCallback info Nothing Nothing 0

rocrandStatusPatternsUnit :: IO ()
rocrandStatusPatternsUnit = do
  expectEq "RocRandStatusSuccess" RocRandStatusSuccess (RocRandStatus rocrandStatusSuccessHeader)
  expectEq "RocRandStatusVersionMismatch" RocRandStatusVersionMismatch (RocRandStatus rocrandStatusVersionMismatchHeader)
  expectEq "RocRandStatusNotCreated" RocRandStatusNotCreated (RocRandStatus rocrandStatusNotCreatedHeader)
  expectEq "RocRandStatusAllocationFailed" RocRandStatusAllocationFailed (RocRandStatus rocrandStatusAllocationFailedHeader)
  expectEq "RocRandStatusTypeError" RocRandStatusTypeError (RocRandStatus rocrandStatusTypeErrorHeader)
  expectEq "RocRandStatusOutOfRange" RocRandStatusOutOfRange (RocRandStatus rocrandStatusOutOfRangeHeader)
  expectEq "RocRandStatusLengthNotMultiple" RocRandStatusLengthNotMultiple (RocRandStatus rocrandStatusLengthNotMultipleHeader)
  expectEq "RocRandStatusDoublePrecisionRequired" RocRandStatusDoublePrecisionRequired (RocRandStatus rocrandStatusDoublePrecisionRequiredHeader)
  expectEq "RocRandStatusLaunchFailure" RocRandStatusLaunchFailure (RocRandStatus rocrandStatusLaunchFailureHeader)
  expectEq "RocRandStatusInternalError" RocRandStatusInternalError (RocRandStatus rocrandStatusInternalErrorHeader)

rocrandRngTypePatternsUnit :: IO ()
rocrandRngTypePatternsUnit = do
  expectEq "RocRandRngPseudoDefault" RocRandRngPseudoDefault (RocRandRngType rocrandRngPseudoDefaultHeader)
  expectEq "RocRandRngPseudoXorwow" RocRandRngPseudoXorwow (RocRandRngType rocrandRngPseudoXorwowHeader)
  expectEq "RocRandRngPseudoPhilox4x32_10" RocRandRngPseudoPhilox4x32_10 (RocRandRngType rocrandRngPseudoPhilox4x32_10Header)

rocrandStatusStringUnit :: IO ()
rocrandStatusStringUnit = do
  let msg = rocRandStatusToString RocRandStatusSuccess
  if null msg then fail "empty rocrand status string" else pure ()

rocrandVersionUnit :: IO ()
rocrandVersionUnit = do
  version <- rocrandGetVersion
  if version > 0 then pure () else fail ("invalid rocrand version: " <> show version)

rocsparseStatusPatternsUnit :: IO ()
rocsparseStatusPatternsUnit =
  expectEq "RocsparseStatusSuccess" RocsparseStatusSuccess (RocsparseStatus rocsparseStatusSuccessHeader)

rocsparseOperationPatternsUnit :: IO ()
rocsparseOperationPatternsUnit =
  expectEq "RocsparseOperationNone" RocsparseOperationNone (RocsparseOperation rocsparseOperationNoneHeader)

rocsparseIndexBasePatternsUnit :: IO ()
rocsparseIndexBasePatternsUnit =
  expectEq "RocsparseIndexBaseZero" RocsparseIndexBaseZero (RocsparseIndexBase rocsparseIndexBaseZeroHeader)

rocsparseMatrixTypePatternsUnit :: IO ()
rocsparseMatrixTypePatternsUnit =
  expectEq "RocsparseMatrixTypeGeneral" RocsparseMatrixTypeGeneral (RocsparseMatrixType rocsparseMatrixTypeGeneralHeader)

rocsparseIndexTypePatternsUnit :: IO ()
rocsparseIndexTypePatternsUnit =
  expectEq "RocsparseIndexTypeI32" RocsparseIndexTypeI32 (RocsparseIndexType rocsparseIndexTypeI32Header)

rocsparseDataTypePatternsUnit :: IO ()
rocsparseDataTypePatternsUnit =
  expectEq "RocsparseDataTypeF32R" RocsparseDataTypeF32R (RocsparseDataType rocsparseDataTypeF32RHeader)

rocsparseV2SpMVStagePatternsUnit :: IO ()
rocsparseV2SpMVStagePatternsUnit =
  expectEq "RocsparseV2SpMVStageAnalysis" RocsparseV2SpMVStageAnalysis (RocsparseV2SpMVStage rocsparseV2SpMVStageAnalysisHeader)

rocsparseSpMVAlgPatternsUnit :: IO ()
rocsparseSpMVAlgPatternsUnit = do
  expectEq "RocsparseSpMVAlgCsrAdaptive" RocsparseSpMVAlgCsrAdaptive (RocsparseSpMVAlg rocsparseSpMVAlgCsrAdaptiveHeader)
  expectEq "RocsparseSpMVAlgCsrRowsplit" RocsparseSpMVAlgCsrRowsplit (RocsparseSpMVAlg rocsparseSpMVAlgCsrRowsplitHeader)

rocsparseStatusStringUnit :: IO ()
rocsparseStatusStringUnit = do
  msg <- rocsparseStatusToString RocsparseStatusSuccess
  if null msg then fail "empty rocsparse status string" else pure ()
