{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Data.Bits ((.|.))
import Control.Exception (SomeException, bracket, bracket_, displayException, try)
import Control.Monad (forM)
import Data.Char (isSpace)
import Data.Complex (Complex((:+)))
import Data.List (intercalate, isPrefixOf)
import Data.Word (Word8)
import Foreign.C.Types (CDouble(..), CFloat(..), CInt, CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray, withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, castPtr, nullPtr, plusPtr)
import Foreign.Storable (sizeOf)
import System.Directory (createDirectoryIfMissing, doesFileExist, findExecutable, getTemporaryDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode(..), exitFailure, exitSuccess)
import System.FilePath ((</>))
import System.Posix.DynamicLinker (RTLDFlags(RTLD_LOCAL, RTLD_NOW), dlclose, dlopen, dlsym)
import System.Process (readProcess, readProcessWithExitCode)

import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..), PinnedHostPtr(..))
import ROCm.HIP
  ( HipDim3(..)
  , HipFunctionAddress(..)
  , HipGraphExecUpdateInfo(..)
  , HipGraphInstantiateFlags(..)
  , HipKernelNodeParams(..)
  , HipLaunchAttributeValue(..)
  , HipLaunchConfig(..)
  , HipMemsetParams(..)
  , hipDeviceSynchronize
  , hipEventCreate
  , hipEventCreateWithFlags
  , hipEventDestroy
  , hipEventElapsedTime
  , hipEventQuery
  , hipEventRecord
  , hipEventRecordWithFlags
  , hipEventSynchronize
  , hipFree
  , hipGetCurrentDeviceGcnArchName
  , hipGetDeviceCount
  , hipGraphAddChildGraphNode
  , hipGraphAddEventRecordNode
  , hipGraphAddEventWaitNode
  , hipGraphAddHostNode
  , hipGraphAddKernelNode
  , hipGraphAddMemcpyNode1D
  , hipGraphAddMemsetNode
  , hipGraphChildGraphNodeGetGraph
  , hipGraphCreate
  , hipGraphDebugDotPrint
  , hipGraphDestroy
  , hipGraphEventRecordNodeGetEvent
  , hipGraphEventRecordNodeSetEvent
  , hipGraphEventWaitNodeGetEvent
  , hipGraphEventWaitNodeSetEvent
  , hipGraphExecDestroy
  , hipGraphExecEventRecordNodeSetEvent
  , hipGraphExecEventWaitNodeSetEvent
  , hipGraphExecHostNodeSetParams
  , hipGraphExecKernelNodeSetParams
  , hipGraphExecMemsetNodeSetParams
  , hipGraphExecUpdate
  , hipGraphHostNodeGetParams
  , hipGraphHostNodeSetParams
  , hipGraphInstantiate
  , hipGraphInstantiateWithFlags
  , hipGraphKernelNodeCopyAttributes
  , hipGraphKernelNodeGetAttribute
  , hipGraphKernelNodeGetParams
  , hipGraphKernelNodeSetAttribute
  , hipGraphKernelNodeSetParams
  , hipGraphLaunch
  , hipGraphMemsetNodeGetParams
  , hipGraphMemsetNodeSetParams
  , hipGraphNodeFindInClone
  , hipHostFree
  , hipHostMallocBytes
  , hipHostMallocBytesWithFlags
  , hipHostRegister
  , hipHostUnregister
  , hipLaunchAttributeCooperative
  , hipLaunchKernel
  , hipLaunchKernelExC
  , hipMallocBytes
  , hipMemcpyAsync
  , hipMemcpyD2H
  , hipMemcpyD2HAsync
  , hipMemcpyH2D
  , hipMemcpyH2DAsync
  , hipMemcpyH2DWithStream
  , hipMemset
  , hipModuleGetFunction
  , hipModuleLaunchKernel
  , hipStreamAddCallback
  , hipStreamBeginCapture
  , hipStreamCreate
  , hipStreamCreateWithFlags
  , hipStreamDestroy
  , hipStreamEndCapture
  , hipStreamGetCaptureInfo
  , hipStreamIsCapturing
  , hipStreamQuery
  , hipStreamSynchronize
  , hipStreamWaitEvent
  , withHipGraphClone
  , withHipHostNodeCallback
  , withHipLaunchAttributes
  , withHipModuleData
  , pattern HipEventBlockingSync
  , pattern HipEventRecordExternal
  , pattern HipHostMallocPortable
  , pattern HipHostRegisterMapped
  , pattern HipGraphDebugDotFlagsHandles
  , pattern HipGraphDebugDotFlagsMemsetNodeParams
  , pattern HipGraphDebugDotFlagsVerbose
  , pattern HipGraphExecUpdateSuccess
  , pattern HipLaunchAttributeCooperative
  , pattern HipStreamCaptureModeRelaxed
  , pattern HipStreamCaptureStatusActive
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyHostToDevice
  , pattern HipStreamNonBlocking
  , pattern HipSuccess
  )
import ROCm.HIP.RTC
  ( hiprtcCompileProgram
  , hiprtcGetCode
  , withHiprtcProgram
  )
import ROCm.RocBLAS
  ( RocblasInt
  , RocblasStride
  , pattern RocblasEvectOriginal
  , pattern RocblasFillLower
  , pattern RocblasInPlace
  , pattern RocblasOperationNone
  , pattern RocblasSrangeIndex
  , pattern RocblasSrangeValue
  , pattern RocblasSvectSingular
  , rocblasDgemm
  , rocblasDgemv
  , rocblasSasum
  , rocblasSaxpy
  , rocblasScopy
  , rocblasSdot
  , rocblasSetStream
  , rocblasSgemm
  , rocblasSgemmBatched
  , rocblasSgemmStridedBatched
  , rocblasSgemv
  , rocblasSgemvBatched
  , rocblasSgemvStridedBatched
  , rocblasSnrm2
  , rocblasSscal
  , withRocblasHandle
  )
import ROCm.RocFFT
  ( rocfftExecute
  , rocfftExecutionInfoSetStream
  , rocfftExecutionInfoSetWorkBuffer
  , rocfftPlanCreate
  , rocfftPlanDescriptionSetDataLayout
  , rocfftPlanDescriptionSetScaleFactor
  , rocfftPlanGetPrint
  , rocfftPlanGetWorkBufferSize
  , withRocfft
  , withRocfftExecutionInfo
  , withRocfftPlan
  , withRocfftPlanDescription
  , pattern RocfftArrayTypeComplexInterleaved
  , pattern RocfftArrayTypeHermitianInterleaved
  , pattern RocfftArrayTypeReal
  , pattern RocfftPlacementInplace
  , pattern RocfftPlacementNotInplace
  , pattern RocfftPrecisionSingle
  , pattern RocfftTransformTypeComplexForward
  , pattern RocfftTransformTypeComplexInverse
  , pattern RocfftTransformTypeRealForward
  , pattern RocfftTransformTypeRealInverse
  )
import ROCm.RocRAND
  ( RocRandRngType
  , pattern RocRandRngPseudoDefault
  , rocrandGenerateUniform
  , rocrandSetSeed
  , withRocRandGenerator
  )
import ROCm.RocSPARSE
  ( RocsparseInt
  , pattern RocsparseDataTypeF32R
  , pattern RocsparseIndexBaseZero
  , pattern RocsparseIndexTypeI32
  , pattern RocsparseMatrixTypeGeneral
  , pattern RocsparseOperationNone
  , pattern RocsparseV2SpMVStageAnalysis
  , pattern RocsparseV2SpMVStageCompute
  , rocsparseConfigureSV2SpMV
  , rocsparseScsrmv
  , rocsparseSetMatIndexBase
  , rocsparseSetMatType
  , rocsparseSetStream
  , rocsparseSV2SpMV
  , rocsparseSV2SpMVBufferSize
  , withRocsparseCsrDescr
  , withRocsparseDnVecDescr
  , withRocsparseHandle
  , withRocsparseMatDescr
  , withRocsparseSpMVDescr
  )
import ROCm.RocSOLVER
  ( rocsolverSgeqrf
  , rocsolverSgesdd
  , rocsolverSgesddBatched
  , rocsolverSgesddStridedBatched
  , rocsolverSgesv
  , rocsolverSgesvd
  , rocsolverSgesvdj
  , rocsolverSgesvdjBatched
  , rocsolverSgesvdjStridedBatched
  , rocsolverSgesvdx
  , rocsolverSgesvdxBatched
  , rocsolverSgesvdxStridedBatched
  , rocsolverSorgqr
  , rocsolverSposv
  , rocsolverSsyev
  )

foreign import ccall "dynamic"
  mkKernelAddressGetter :: FunPtr (IO (Ptr ())) -> IO (Ptr ())

data SmokeResult
  = SmokePassed
  | SmokeSkipped String

main :: IO ()
main = do
  results <-
    forM
      [ ("hip-memcpy-roundtrip", hipMemcpySmoke)
      , ("hip-memset-roundtrip", hipMemsetSmoke)
      , ("hip-async-pinned-event", hipAsyncPinnedEventSmoke)
      , ("hip-stream-callback", hipStreamCallbackSmoke)
      , ("hip-stream-wait-event", hipStreamWaitEventSmoke)
      , ("hip-host-register-roundtrip", hipHostRegisterSmoke)
      , ("hip-event-query-timing", hipEventQueryTimingSmoke)
      , ("hip-module-launch", hipModuleLaunchSmoke)
      , ("hip-graph-memcpy", hipGraphMemcpySmoke)
      , ("hip-launch-kernel-direct", hipLaunchKernelDirectSmoke)
      , ("hip-graph-kernel-node", hipGraphKernelNodeSmoke)
      , ("hip-launch-kernel-exc", hipLaunchKernelExCSmoke)
      , ("hip-launch-kernel-exc-cooperative-attr", hipLaunchKernelExCCooperativeAttrSmoke)
      , ("hip-graph-host-node", hipGraphHostNodeSmoke)
      , ("hip-graph-memset-node", hipGraphMemsetNodeSmoke)
      , ("hip-stream-capture-graph", hipStreamCaptureGraphSmoke)
      , ("hip-graph-kernel-node-cooperative-attr", hipGraphKernelNodeCooperativeAttrSmoke)
      , ("hip-graph-update-clone-debug-dot", hipGraphUpdateCloneDebugDotSmoke)
      , ("hip-graph-child-event-nodes", hipGraphChildEventNodesSmoke)
      , ("rocfft-c2c-1d", rocfftSmoke)
      , ("rocfft-c2c-normalized", rocfftNormalizedSmoke)
      , ("rocfft-batched-notinplace", rocfftBatchedNotInplaceSmoke)
      , ("rocfft-r2c-c2r-1d", rocfftR2CC2RSmoke)
      , ("rocrand-uniform", rocrandUniformSmoke)
      , ("rocsparse-scsrmv", rocsparseScsrmvSmoke)
      , ("rocsparse-generic-spmv", rocsparseGenericSpmvSmoke)
      , ("rocsolver-sposv", rocsolverSposvSmoke)
      , ("rocsolver-sgesv", rocsolverSgesvSmoke)
      , ("rocsolver-sgeqrf-orgqr", rocsolverSgeqrfOrgqrSmoke)
      , ("rocsolver-ssyev", rocsolverSsyevSmoke)
      , ("rocsolver-sgesvd", rocsolverSgesvdSmoke)
      , ("rocsolver-sgesdd", rocsolverSgesddSmoke)
      , ("rocsolver-sgesdd-batched", rocsolverSgesddBatchedSmoke)
      , ("rocsolver-sgesdd-strided-batched", rocsolverSgesddStridedBatchedSmoke)
      , ("rocsolver-sgesvdj", rocsolverSgesvdjSmoke)
      , ("rocsolver-sgesvdj-batched", rocsolverSgesvdjBatchedSmoke)
      , ("rocsolver-sgesvdj-strided-batched", rocsolverSgesvdjStridedBatchedSmoke)
      , ("rocsolver-sgesvdx", rocsolverSgesvdxSmoke)
      , ("rocsolver-sgesvdx-value", rocsolverSgesvdxValueSmoke)
      , ("rocsolver-sgesvdx-batched", rocsolverSgesvdxBatchedSmoke)
      , ("rocsolver-sgesvdx-batched-value", rocsolverSgesvdxBatchedValueSmoke)
      , ("rocsolver-sgesvdx-strided-batched", rocsolverSgesvdxStridedBatchedSmoke)
      , ("rocsolver-sgesvdx-strided-batched-value", rocsolverSgesvdxStridedBatchedValueSmoke)
      , ("rocblas-saxpy", rocblasSmoke)
      , ("rocblas-blas1-core", rocblasBlas1CoreSmoke)
      , ("rocblas-sgemv", rocblasGemvSmoke)
      , ("rocblas-dgemv", rocblasDGemvSmoke)
      , ("rocblas-sgemv-batched", rocblasGemvBatchedSmoke)
      , ("rocblas-sgemv-strided-batched", rocblasGemvStridedBatchedSmoke)
      , ("rocblas-sgemm", rocblasGemmSmoke)
      , ("rocblas-dgemm", rocblasDGemmSmoke)
      , ("rocblas-sgemm-batched", rocblasGemmBatchedSmoke)
      , ("rocblas-sgemm-strided-batched", rocblasGemmStridedBatchedSmoke)
      ]
      $ \(name, action) -> do
        outcome <- try action :: IO (Either SomeException SmokeResult)
        case outcome of
          Left e -> do
            putStrLn ("FAIL  " <> name <> ": " <> sanitize (displayException e))
            pure False
          Right SmokePassed -> do
            putStrLn ("PASS  " <> name)
            pure True
          Right (SmokeSkipped reason) -> do
            putStrLn ("SKIP  " <> name <> ": " <> reason)
            pure True

  if and results
    then exitSuccess
    else exitFailure

hipMemcpySmoke :: IO SmokeResult
hipMemcpySmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 16 :: Int
          input = fromIntegral <$> [0 .. n - 1] :: [Int]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
          inputC = fmap (CFloat . fromIntegral) input

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn inputC

          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf -> do
            hipMemcpyH2D dBuf (HostPtr hIn) bytes
            hipMemcpyD2H (HostPtr hOut) dBuf bytes

          output <- peekArray n hOut
          if output == inputC
            then pure SmokePassed
            else fail ("hipMemcpy mismatch: expected=" <> show inputC <> ", got=" <> show output)

hipMemsetSmoke :: IO SmokeResult
hipMemsetSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 32 :: Int
          bytes = fromIntegral n :: CSize
          expected = replicate n (0x5a :: Word8)

      bracket (mallocArray n :: IO (Ptr Word8)) free $ \hOut ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf -> do
          hipMemset dBuf 0x5a bytes
          hipMemcpyD2H (HostPtr hOut) dBuf bytes
          output <- peekArray n hOut
          if output == expected
            then pure SmokePassed
            else fail ("hip memset mismatch: expected=" <> show expected <> ", got=" <> show output)

hipAsyncPinnedEventSmoke :: IO SmokeResult
hipAsyncPinnedEventSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 16 :: Int
          input = fmap (CFloat . fromIntegral) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
        bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOut ->
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              bracket hipEventCreate hipEventDestroy $ \ev -> do
                let PinnedHostPtr pIn = hIn
                    PinnedHostPtr pOut = hOut
                pokeArray pIn input
                hipMemcpyH2DAsync dBuf hIn bytes stream
                hipMemcpyD2HAsync hOut dBuf bytes stream
                hipEventRecord ev stream
                hipEventSynchronize ev
                output <- peekArray n pOut
                if output == input
                  then pure SmokePassed
                  else fail ("hip async pinned/event mismatch: expected=" <> show input <> ", got=" <> show output)

hipStreamCallbackSmoke :: IO SmokeResult
hipStreamCallbackSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 16 :: Int
          input = fmap (CFloat . fromIntegral) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input
          cbMVar <- newEmptyMVar

          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
            bracket hipStreamCreate hipStreamDestroy $ \stream -> do
              hipMemcpyH2DWithStream dBuf (HostPtr hIn) bytes stream
              hipStreamAddCallback stream (\_ status -> putMVar cbMVar status)
              hipStreamSynchronize stream
              cbStatus <- takeMVar cbMVar
              hipMemcpyD2H (HostPtr hOut) dBuf bytes
              output <- peekArray n hOut
              if cbStatus == HipSuccess && output == input
                then pure SmokePassed
                else fail ("hip stream callback mismatch: status=" <> show cbStatus <> ", output=" <> show output)

hipStreamWaitEventSmoke :: IO SmokeResult
hipStreamWaitEventSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 16 :: Int
          input = fmap (CFloat . fromIntegral) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
        bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOut ->
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
            bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream1 ->
              bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream2 ->
                bracket (hipEventCreateWithFlags HipEventBlockingSync) hipEventDestroy $ \ev -> do
                  let PinnedHostPtr pIn = hIn
                      PinnedHostPtr pOut = hOut
                  pokeArray pIn input
                  hipMemcpyH2DAsync dBuf hIn bytes stream1
                  hipEventRecordWithFlags ev stream1 HipEventRecordExternal
                  hipStreamWaitEvent stream2 ev 0
                  hipMemcpyD2HAsync hOut dBuf bytes stream2
                  hipStreamSynchronize stream2
                  ready <- hipStreamQuery stream2
                  output <- peekArray n pOut
                  if ready && output == input
                    then pure SmokePassed
                    else fail ("hip stream wait-event mismatch: ready=" <> show ready <> ", output=" <> show output)

hipHostRegisterSmoke :: IO SmokeResult
hipHostRegisterSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 16 :: Int
          input = fmap (CFloat . fromIntegral) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input
          bracket_ (hipHostRegister (HostPtr hIn) bytes HipHostRegisterMapped) (hipHostUnregister (HostPtr hIn)) $
            bracket_ (hipHostRegister (HostPtr hOut) bytes HipHostRegisterMapped) (hipHostUnregister (HostPtr hOut)) $
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
                bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream -> do
                  let HostPtr pIn = HostPtr hIn
                      HostPtr pOut = HostPtr hOut
                  hipMemcpyAsync (castPtr (let DevicePtr p = dBuf in p)) (castPtr pIn) bytes HipMemcpyHostToDevice stream
                  hipMemcpyAsync (castPtr pOut) (castPtr (let DevicePtr p = dBuf in p)) bytes HipMemcpyDeviceToHost stream
                  hipStreamSynchronize stream
                  output <- peekArray n hOut
                  if output == input
                    then pure SmokePassed
                    else fail ("hip host register mismatch: expected=" <> show input <> ", got=" <> show output)

hipEventQueryTimingSmoke :: IO SmokeResult
hipEventQueryTimingSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 1024 * 256 :: Int
          input = fmap (CFloat . fromIntegral . (`mod` 97)) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (hipHostMallocBytesWithFlags bytes HipHostMallocPortable :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            bracket hipEventCreate hipEventDestroy $ \startEv ->
              bracket hipEventCreate hipEventDestroy $ \stopEv -> do
                let PinnedHostPtr pIn = hIn
                pokeArray pIn input
                hipEventRecord startEv stream
                hipMemcpyH2DAsync dBuf hIn bytes stream
                hipEventRecord stopEv stream
                hipEventSynchronize stopEv
                ready <- hipEventQuery stopEv
                ms <- hipEventElapsedTime startEv stopEv
                if ready && ms >= 0
                  then pure SmokePassed
                  else fail ("hip event query/timing mismatch: ready=" <> show ready <> ", ms=" <> show ms)

hipModuleLaunchSmoke :: IO SmokeResult
hipModuleLaunchSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 256 :: Int
          threads = 64 :: Int
          blocks = (n + threads - 1) `div` threads
          input = fmap (CFloat . fromIntegral) [0 .. n - 1]
          expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      arch <- normalizeHiprtcArch <$> hipGetCurrentDeviceGcnArchName
      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
            bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
              bracket hipStreamCreate hipStreamDestroy $ \stream -> do
                hipMemcpyH2D dIn (HostPtr hIn) bytes
                withHiprtcProgram hipModuleLaunchSource "hip_module_launch.hip" $ \prog -> do
                  hiprtcCompileProgram prog ["--offload-arch=" ++ arch, "-O2"]
                  codeObject <- hiprtcGetCode prog
                  withHipModuleData codeObject $ \modu -> do
                    fun <- hipModuleGetFunction modu "add_one"
                    let DevicePtr pIn = dIn
                        DevicePtr pOut = dOut
                        grid = HipDim3 (fromIntegral blocks) 1 1
                        block = HipDim3 (fromIntegral threads) 1 1
                        nArg = fromIntegral n :: CInt
                    with pOut $ \pArgOut ->
                      with pIn $ \pArgIn ->
                        with nArg $ \pArgN ->
                          withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                            hipModuleLaunchKernel fun grid block 0 (Just stream) kernelParams nullPtr
                            hipStreamSynchronize stream
                            hipMemcpyD2H (HostPtr hOut) dOut bytes
                            output <- peekArray n hOut
                            if output == expected
                              then pure SmokePassed
                              else fail ("hip module launch mismatch: expected=" <> show expected <> ", got=" <> show output)

hipGraphMemcpySmoke :: IO SmokeResult
hipGraphMemcpySmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let n = 64 :: Int
          input = fmap (CFloat . fromIntegral . (`mod` 11)) [0 .. n - 1]
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                let DevicePtr pBuf = dBuf
                h2dNode <- hipGraphAddMemcpyNode1D graph [] (castPtr pBuf) (castPtr hIn) bytes HipMemcpyHostToDevice
                _ <- hipGraphAddMemcpyNode1D graph [h2dNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                execGraph <- hipGraphInstantiate graph
                bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                  hipGraphLaunch execGraph stream
                  hipStreamSynchronize stream
                  output <- peekArray n hOut
                  if output == input
                    then pure SmokePassed
                    else fail ("hip graph memcpy mismatch: expected=" <> show input <> ", got=" <> show output)

hipLaunchKernelDirectSmoke :: IO SmokeResult
hipLaunchKernelDirectSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 256 :: Int
              threads = 64 :: Int
              blocks = (n + threads - 1) `div` threads
              input = fmap (CFloat . fromIntegral) [0 .. n - 1]
              expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 (fromIntegral blocks) 1 1
              block = HipDim3 (fromIntegral threads) 1 1
          bracket (mallocArray n) free $ \hIn ->
            bracket (mallocArray n) free $ \hOut -> do
              pokeArray hIn input
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                    withDirectAddOneKernelAddress "hip_launch_kernel_direct" $ \kernelAddress -> do
                      hipMemcpyH2D dIn (HostPtr hIn) bytes
                      let DevicePtr pIn = dIn
                          DevicePtr pOut = dOut
                          nArg = fromIntegral n :: CInt
                      with pOut $ \pArgOut ->
                        with pIn $ \pArgIn ->
                          with nArg $ \pArgN ->
                            withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                              hipLaunchKernel kernelAddress grid block kernelParams 0 (Just stream)
                              hipStreamSynchronize stream
                              hipMemcpyD2H (HostPtr hOut) dOut bytes
                              output <- peekArray n hOut
                              if output == expected
                                then pure SmokePassed
                                else fail ("hipLaunchKernel mismatch: expected=" <> show expected <> ", got=" <> show output)

hipGraphKernelNodeSmoke :: IO SmokeResult
hipGraphKernelNodeSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 128 :: Int
              threads = 64 :: Int
              blocks = (n + threads - 1) `div` threads
              input = fmap (CFloat . fromIntegral . (`mod` 13)) [0 .. n - 1]
              expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 (fromIntegral blocks) 1 1
              block = HipDim3 (fromIntegral threads) 1 1
          bracket (mallocArray n) free $ \hIn ->
            bracket (mallocArray n) free $ \hOut -> do
              pokeArray hIn input
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                    withDirectAddOneKernelAddress "hip_graph_kernel_node" $ \kernelAddress -> do
                      let DevicePtr pIn = dIn
                          DevicePtr pOut = dOut
                          nArg = fromIntegral n :: CInt
                      with pOut $ \pArgOut ->
                        with pIn $ \pArgIn ->
                          with nArg $ \pArgN ->
                            withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams ->
                              bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                                h2dNode <- hipGraphAddMemcpyNode1D graph [] (castPtr pIn) (castPtr hIn) bytes HipMemcpyHostToDevice
                                let params =
                                      HipKernelNodeParams
                                        { hipKernelNodeBlockDim = block
                                        , hipKernelNodeExtra = nullPtr
                                        , hipKernelNodeFunc = kernelAddress
                                        , hipKernelNodeGridDim = grid
                                        , hipKernelNodeKernelParams = kernelParams
                                        , hipKernelNodeSharedMemBytes = 0
                                        }
                                kernelNode <- hipGraphAddKernelNode graph [h2dNode] params
                                gotParams <- hipGraphKernelNodeGetParams kernelNode
                                if hipKernelNodeBlockDim gotParams /= block
                                  || hipKernelNodeGridDim gotParams /= grid
                                  || hipKernelNodeFunc gotParams /= kernelAddress
                                  || hipKernelNodeSharedMemBytes gotParams /= 0
                                  then fail ("hipGraphKernelNodeGetParams mismatch: got=" <> show gotParams)
                                  else pure ()
                                hipGraphKernelNodeSetParams kernelNode params
                                _ <- hipGraphAddMemcpyNode1D graph [kernelNode] (castPtr hOut) (castPtr pOut) bytes HipMemcpyDeviceToHost
                                execGraph <- hipGraphInstantiate graph
                                bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                                  hipGraphExecKernelNodeSetParams execGraph kernelNode params
                                  hipGraphLaunch execGraph stream
                                  hipStreamSynchronize stream
                                  output <- peekArray n hOut
                                  if output == expected
                                    then pure SmokePassed
                                    else fail ("hip graph kernel node mismatch: expected=" <> show expected <> ", got=" <> show output)

hipLaunchKernelExCSmoke :: IO SmokeResult
hipLaunchKernelExCSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 256 :: Int
              threads = 64 :: Int
              blocks = (n + threads - 1) `div` threads
              input = fmap (CFloat . fromIntegral) [0 .. n - 1]
              expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 (fromIntegral blocks) 1 1
              block = HipDim3 (fromIntegral threads) 1 1
          bracket (mallocArray n) free $ \hIn ->
            bracket (mallocArray n) free $ \hOut -> do
              pokeArray hIn input
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                    withDirectAddOneKernelAddress "hip_launch_kernel_exc" $ \kernelAddress -> do
                      hipMemcpyH2D dIn (HostPtr hIn) bytes
                      let DevicePtr pIn = dIn
                          DevicePtr pOut = dOut
                          nArg = fromIntegral n :: CInt
                          config =
                            HipLaunchConfig
                              { hipLaunchConfigGridDim = grid
                              , hipLaunchConfigBlockDim = block
                              , hipLaunchConfigDynamicSmemBytes = 0
                              , hipLaunchConfigStream = Just stream
                              , hipLaunchConfigAttrs = nullPtr
                              , hipLaunchConfigNumAttrs = 0
                              }
                      with pOut $ \pArgOut ->
                        with pIn $ \pArgIn ->
                          with nArg $ \pArgN ->
                            withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                              hipLaunchKernelExC config kernelAddress kernelParams
                              hipStreamSynchronize stream
                              hipMemcpyD2H (HostPtr hOut) dOut bytes
                              output <- peekArray n hOut
                              if output == expected
                                then pure SmokePassed
                                else fail ("hipLaunchKernelExC mismatch: expected=" <> show expected <> ", got=" <> show output)

hipLaunchKernelExCCooperativeAttrSmoke :: IO SmokeResult
hipLaunchKernelExCCooperativeAttrSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 64 :: Int
              input = fmap (CFloat . fromIntegral) [0 .. n - 1]
              expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 1 1 1
              block = HipDim3 64 1 1
          bracket (mallocArray n) free $ \hIn ->
            bracket (mallocArray n) free $ \hOut -> do
              pokeArray hIn input
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                    withDirectAddOneKernelAddress "hip_launch_kernel_exc_cooperative_attr" $ \kernelAddress ->
                      withHipLaunchAttributes [hipLaunchAttributeCooperative True] $ \pAttrs attrCount -> do
                        hipMemcpyH2D dIn (HostPtr hIn) bytes
                        let DevicePtr pIn = dIn
                            DevicePtr pOut = dOut
                            nArg = fromIntegral n :: CInt
                            config =
                              HipLaunchConfig
                                { hipLaunchConfigGridDim = grid
                                , hipLaunchConfigBlockDim = block
                                , hipLaunchConfigDynamicSmemBytes = 0
                                , hipLaunchConfigStream = Just stream
                                , hipLaunchConfigAttrs = castPtr pAttrs
                                , hipLaunchConfigNumAttrs = attrCount
                                }
                        with pOut $ \pArgOut ->
                          with pIn $ \pArgIn ->
                            with nArg $ \pArgN ->
                              withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                                hipLaunchKernelExC config kernelAddress kernelParams
                                hipStreamSynchronize stream
                                hipMemcpyD2H (HostPtr hOut) dOut bytes
                                output <- peekArray n hOut
                                if output == expected
                                  then pure SmokePassed
                                  else fail ("hipLaunchKernelExC cooperative attr mismatch: expected=" <> show expected <> ", got=" <> show output)

hipStreamCaptureGraphSmoke :: IO SmokeResult
hipStreamCaptureGraphSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 64 :: Int
              input = fmap (CFloat . fromIntegral) [0 .. n - 1]
              expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 1 1 1
              block = HipDim3 64 1 1
          bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hInPinned ->
            bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOutPinned -> do
              let PinnedHostPtr pInPinned = hInPinned
                  PinnedHostPtr pOutPinned = hOutPinned
              pokeArray pInPinned input
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                    withDirectAddOneKernelAddress "hip_stream_capture_graph" $ \kernelAddress -> do
                      hipStreamBeginCapture stream HipStreamCaptureModeRelaxed
                      status1 <- hipStreamIsCapturing stream
                      if status1 /= HipStreamCaptureStatusActive
                        then fail ("hipStreamIsCapturing expected active, got=" <> show status1)
                        else pure ()
                      (status2, captureId) <- hipStreamGetCaptureInfo stream
                      if status2 /= HipStreamCaptureStatusActive || captureId == 0
                        then fail ("hipStreamGetCaptureInfo mismatch: status=" <> show status2 <> ", id=" <> show captureId)
                        else pure ()
                      hipMemcpyH2DAsync dIn hInPinned bytes stream
                      let DevicePtr pIn = dIn
                          DevicePtr pOut = dOut
                          nArg = fromIntegral n :: CInt
                      with pOut $ \pArgOut ->
                        with pIn $ \pArgIn ->
                          with nArg $ \pArgN ->
                            withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                              hipLaunchKernel kernelAddress grid block kernelParams 0 (Just stream)
                              hipMemcpyD2HAsync hOutPinned dOut bytes stream
                              capturedGraph <- hipStreamEndCapture stream
                              bracket (pure capturedGraph) hipGraphDestroy $ \graph -> do
                                execGraph <- hipGraphInstantiateWithFlags graph (HipGraphInstantiateFlags 0)
                                bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                                  hipGraphLaunch execGraph stream
                                  hipStreamSynchronize stream
                                  output <- peekArray n pOutPinned
                                  if output == expected
                                    then pure SmokePassed
                                    else fail ("hip stream capture graph mismatch: expected=" <> show expected <> ", got=" <> show output)

hipGraphKernelNodeCooperativeAttrSmoke :: IO SmokeResult
hipGraphKernelNodeCooperativeAttrSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      hipccReady <- requireHipcc
      case hipccReady of
        Just skipMsg -> pure (SmokeSkipped skipMsg)
        Nothing -> do
          let n = 64 :: Int
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              grid = HipDim3 1 1 1
              block = HipDim3 64 1 1
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
            bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
              withDirectAddOneKernelAddress "hip_graph_kernel_node_cooperative_attr" $ \kernelAddress -> do
                let DevicePtr pIn = dIn
                    DevicePtr pOut = dOut
                    nArg = fromIntegral n :: CInt
                with pOut $ \pArgOut ->
                  with pIn $ \pArgIn ->
                    with nArg $ \pArgN ->
                      withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams ->
                        bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                          let params =
                                HipKernelNodeParams
                                  { hipKernelNodeBlockDim = block
                                  , hipKernelNodeExtra = nullPtr
                                  , hipKernelNodeFunc = kernelAddress
                                  , hipKernelNodeGridDim = grid
                                  , hipKernelNodeKernelParams = kernelParams
                                  , hipKernelNodeSharedMemBytes = 0
                                  }
                          node1 <- hipGraphAddKernelNode graph [] params
                          node2 <- hipGraphAddKernelNode graph [] params
                          hipGraphKernelNodeSetAttribute node1 HipLaunchAttributeCooperative (HipLaunchAttributeValueCooperative True)
                          value1 <- hipGraphKernelNodeGetAttribute node1 HipLaunchAttributeCooperative
                          if value1 /= HipLaunchAttributeValueCooperative True
                            then fail ("hipGraphKernelNodeGetAttribute mismatch: got=" <> show value1)
                            else pure ()
                          hipGraphKernelNodeCopyAttributes node1 node2
                          value2 <- hipGraphKernelNodeGetAttribute node2 HipLaunchAttributeCooperative
                          if value2 /= HipLaunchAttributeValueCooperative True
                            then fail ("hipGraphKernelNodeCopyAttributes mismatch: got=" <> show value2)
                            else pure SmokePassed

hipGraphHostNodeSmoke :: IO SmokeResult
hipGraphHostNodeSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      callbackMv <- newEmptyMVar
      let bytesCount = 32 :: Int
          bytes = fromIntegral bytesCount :: CSize
          paramsFor dst value =
            HipMemsetParams
              { hipMemsetDst = dst
              , hipMemsetElementSize = 1
              , hipMemsetHeight = 1
              , hipMemsetPitch = bytes
              , hipMemsetValue = fromIntegral value
              , hipMemsetWidth = bytes
              }
      bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            withHipHostNodeCallback (putMVar callbackMv (1 :: Int)) $ \params1 ->
              withHipHostNodeCallback (putMVar callbackMv (2 :: Int)) $ \params2 ->
                withHipHostNodeCallback (putMVar callbackMv (3 :: Int)) $ \params3 ->
                  bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                    let DevicePtr pBuf = dBuf
                        memsetParams = paramsFor (castPtr pBuf) (0x33 :: Word8)
                    memsetNode <- hipGraphAddMemsetNode graph [] memsetParams
                    hostNode <- hipGraphAddHostNode graph [memsetNode] params1
                    gotParams <- hipGraphHostNodeGetParams hostNode
                    if gotParams /= params1
                      then fail ("hipGraphHostNodeGetParams mismatch: got=" <> show gotParams)
                      else pure ()
                    hipGraphHostNodeSetParams hostNode params2
                    _ <- hipGraphAddMemcpyNode1D graph [hostNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                    execGraph <- hipGraphInstantiate graph
                    bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                      hipGraphExecHostNodeSetParams execGraph hostNode params3
                      hipGraphLaunch execGraph stream
                      hipStreamSynchronize stream
                      callbackResult <- takeMVar callbackMv
                      output <- peekArray bytesCount hOut
                      if callbackResult /= 3
                        then fail ("hip graph host node callback mismatch: expected 3, got=" <> show callbackResult)
                        else
                          if output == replicate bytesCount 0x33
                            then pure SmokePassed
                            else fail ("hip graph host node data mismatch: expected all 0x33, got=" <> show output)

hipGraphMemsetNodeSmoke :: IO SmokeResult
hipGraphMemsetNodeSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let bytesCount = 32 :: Int
          bytes = fromIntegral bytesCount :: CSize
          paramsFor dst value =
            HipMemsetParams
              { hipMemsetDst = dst
              , hipMemsetElementSize = 1
              , hipMemsetHeight = 1
              , hipMemsetPitch = bytes
              , hipMemsetValue = fromIntegral value
              , hipMemsetWidth = bytes
              }
      bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
              let DevicePtr pBuf = dBuf
                  params1 = paramsFor (castPtr pBuf) (0x11 :: Word8)
                  params2 = paramsFor (castPtr pBuf) (0x22 :: Word8)
                  params3 = paramsFor (castPtr pBuf) (0x33 :: Word8)
              memsetNode <- hipGraphAddMemsetNode graph [] params1
              gotParams <- hipGraphMemsetNodeGetParams memsetNode
              if gotParams /= params1
                then fail ("hipGraphMemsetNodeGetParams mismatch: got=" <> show gotParams)
                else pure ()
              hipGraphMemsetNodeSetParams memsetNode params2
              _ <- hipGraphAddMemcpyNode1D graph [memsetNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
              execGraph <- hipGraphInstantiate graph
              bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                hipGraphExecMemsetNodeSetParams execGraph memsetNode params3
                hipGraphLaunch execGraph stream
                hipStreamSynchronize stream
                output <- peekArray bytesCount hOut
                if output == replicate bytesCount 0x33
                  then pure SmokePassed
                  else fail ("hip graph memset node mismatch: expected all 0x33, got=" <> show output)

hipGraphUpdateCloneDebugDotSmoke :: IO SmokeResult
hipGraphUpdateCloneDebugDotSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let bytesCount = 32 :: Int
          bytes = fromIntegral bytesCount :: CSize
          paramsFor dst value =
            HipMemsetParams
              { hipMemsetDst = dst
              , hipMemsetElementSize = 1
              , hipMemsetHeight = 1
              , hipMemsetPitch = bytes
              , hipMemsetValue = fromIntegral value
              , hipMemsetWidth = bytes
              }
      tempDir <- getTemporaryDirectory
      let dotDir = tempDir </> "haskell-rocm-graph-dot"
          dotPath = dotDir </> "hip_graph_update_clone_debug.dot"
      createDirectoryIfMissing True dotDir
      bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
          bracket hipStreamCreate hipStreamDestroy $ \stream -> do
            let DevicePtr pBuf = dBuf
            bracket (hipGraphCreate 0) hipGraphDestroy $ \graph1 ->
              bracket (hipGraphCreate 0) hipGraphDestroy $ \graph2 -> do
                memsetNode1 <- hipGraphAddMemsetNode graph1 [] (paramsFor (castPtr pBuf) (0x11 :: Word8))
                _ <- hipGraphAddMemcpyNode1D graph1 [memsetNode1] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                memsetNode2 <- hipGraphAddMemsetNode graph2 [] (paramsFor (castPtr pBuf) (0x44 :: Word8))
                _ <- hipGraphAddMemcpyNode1D graph2 [memsetNode2] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                withHipGraphClone graph1 $ \graphClone -> do
                  cloneNode <- hipGraphNodeFindInClone memsetNode1 graphClone
                  _ <- hipGraphMemsetNodeGetParams cloneNode
                  hipGraphDebugDotPrint graphClone dotPath (HipGraphDebugDotFlagsVerbose .|. HipGraphDebugDotFlagsMemsetNodeParams .|. HipGraphDebugDotFlagsHandles)
                  dotExists <- doesFileExist dotPath
                  if not dotExists
                    then fail "hipGraphDebugDotPrint did not produce the DOT file"
                    else pure ()
                  dotContents <- readFile dotPath
                  if "digraph" `isPrefixOf` dropWhile isSpace dotContents || "digraph" `elem` words dotContents
                    then pure ()
                    else fail ("hipGraphDebugDotPrint output does not look like DOT: " <> take 120 dotContents)
                execGraph <- hipGraphInstantiate graph1
                bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                  updateInfo <- hipGraphExecUpdate execGraph graph2
                  if hipGraphExecUpdateResult updateInfo /= HipGraphExecUpdateSuccess
                    then fail ("hipGraphExecUpdate expected success, got=" <> show updateInfo)
                    else pure ()
                  hipGraphLaunch execGraph stream
                  hipStreamSynchronize stream
                  output <- peekArray bytesCount hOut
                  if output == replicate bytesCount 0x44
                    then pure SmokePassed
                    else fail ("hip graph update/clone/debug-dot mismatch: expected all 0x44, got=" <> show output)

hipGraphChildEventNodesSmoke :: IO SmokeResult
hipGraphChildEventNodesSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      let bytesCount = 32 :: Int
          bytes = fromIntegral bytesCount :: CSize
          paramsFor dst value =
            HipMemsetParams
              { hipMemsetDst = dst
              , hipMemsetElementSize = 1
              , hipMemsetHeight = 1
              , hipMemsetPitch = bytes
              , hipMemsetValue = fromIntegral value
              , hipMemsetWidth = bytes
              }
      tempDir <- getTemporaryDirectory
      let dotDir = tempDir </> "haskell-rocm-graph-dot"
          childDotPath = dotDir </> "hip_graph_child_graph.dot"
      createDirectoryIfMissing True dotDir
      bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            bracket hipStreamCreate hipStreamDestroy $ \readyStream ->
              bracket hipEventCreate hipEventDestroy $ \readyEv1 ->
                bracket hipEventCreate hipEventDestroy $ \readyEv2 ->
                  bracket hipEventCreate hipEventDestroy $ \doneEv1 ->
                    bracket hipEventCreate hipEventDestroy $ \doneEv2 -> do
                      let DevicePtr pBuf = dBuf
                      bracket (hipGraphCreate 0) hipGraphDestroy $ \childGraph ->
                        bracket (hipGraphCreate 0) hipGraphDestroy $ \parentGraph -> do
                          _ <- hipGraphAddMemsetNode childGraph [] (paramsFor (castPtr pBuf) (0x5a :: Word8))
                          waitNode <- hipGraphAddEventWaitNode parentGraph [] readyEv1
                          waitEv0 <- hipGraphEventWaitNodeGetEvent waitNode
                          if waitEv0 /= readyEv1
                            then fail "hipGraphEventWaitNodeGetEvent mismatch before set"
                            else pure ()
                          hipGraphEventWaitNodeSetEvent waitNode readyEv2
                          childNode <- hipGraphAddChildGraphNode parentGraph [waitNode] childGraph
                          embeddedGraph <- hipGraphChildGraphNodeGetGraph childNode
                          hipGraphDebugDotPrint embeddedGraph childDotPath HipGraphDebugDotFlagsVerbose
                          childDotExists <- doesFileExist childDotPath
                          if not childDotExists
                            then fail "hipGraphChildGraphNodeGetGraph returned an unusable graph handle"
                            else pure ()
                          recordNode <- hipGraphAddEventRecordNode parentGraph [childNode] doneEv1
                          recordEv0 <- hipGraphEventRecordNodeGetEvent recordNode
                          if recordEv0 /= doneEv1
                            then fail "hipGraphEventRecordNodeGetEvent mismatch before set"
                            else pure ()
                          hipGraphEventRecordNodeSetEvent recordNode doneEv2
                          _ <- hipGraphAddMemcpyNode1D parentGraph [recordNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                          execGraph <- hipGraphInstantiate parentGraph
                          bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                            hipGraphExecEventWaitNodeSetEvent execGraph waitNode readyEv2
                            hipGraphExecEventRecordNodeSetEvent execGraph recordNode doneEv2
                            hipEventRecord readyEv2 readyStream
                            hipGraphLaunch execGraph stream
                            hipEventSynchronize doneEv2
                            hipStreamSynchronize stream
                            output <- peekArray bytesCount hOut
                            if output == replicate bytesCount 0x5a
                              then pure SmokePassed
                              else fail ("hip graph child/event nodes mismatch: expected all 0x5a, got=" <> show output)

normalizeHiprtcArch :: String -> String
normalizeHiprtcArch = takeWhile (/= ':')

hipModuleLaunchSource :: String
hipModuleLaunchSource = unlines
  [ "extern \"C\" __global__ void add_one(float* out, const float* in, int n) {"
  , "  int i = blockIdx.x * blockDim.x + threadIdx.x;"
  , "  if (i < n) out[i] = in[i] + 1.0f;"
  , "}"
  ]

hipDirectAddOneSource :: String
hipDirectAddOneSource = unlines
  [ "#include <hip/hip_runtime.h>"
  , "extern \"C\" __global__ void add_one(float* out, const float* in, int n) {"
  , "  int i = blockIdx.x * blockDim.x + threadIdx.x;"
  , "  if (i < n) out[i] = in[i] + 1.0f;"
  , "}"
  , "extern \"C\" void* add_one_kernel_address() {"
  , "  return (void*)add_one;"
  , "}"
  ]

requireHipcc :: IO (Maybe String)
requireHipcc = do
  mHipcc <- findExecutable "hipcc"
  pure $ case mHipcc of
    Nothing -> Just "hipcc not found in PATH; required for direct hipLaunchKernel / graph kernel-node coverage"
    Just _ -> Nothing

withDirectAddOneKernelAddress :: String -> (HipFunctionAddress -> IO a) -> IO a
withDirectAddOneKernelAddress buildName action = do
  tempDir <- getTemporaryDirectory
  let buildDir = tempDir </> "haskell-rocm-hip-direct-kernels"
      srcPath = buildDir </> (buildName <> ".hip")
      soPath = buildDir </> ("lib" <> buildName <> ".so")
  createDirectoryIfMissing True buildDir
  writeFile srcPath hipDirectAddOneSource
  mHipcc <- findExecutable "hipcc"
  hipcc <- case mHipcc of
    Just path -> pure path
    Nothing -> fail "hipcc not found in PATH"
  (exitCode, stdOut, stdErr) <- readProcessWithExitCode hipcc ["-shared", "-fPIC", "-O2", srcPath, "-o", soPath] ""
  case exitCode of
    ExitSuccess ->
      bracket (dlopen soPath [RTLD_NOW, RTLD_LOCAL]) dlclose $ \dl -> do
        getter <- dlsym dl "add_one_kernel_address" :: IO (FunPtr (IO (Ptr ())))
        address <- HipFunctionAddress <$> mkKernelAddressGetter getter
        action address
    ExitFailure code ->
      fail
        ( "hipcc failed with exit code "
            <> show code
            <> " while building direct HIP kernel helper\nstdout:\n"
            <> stdOut
            <> "\nstderr:\n"
            <> stdErr
        )

rocfftR2CC2RSmoke :: IO SmokeResult
rocfftR2CC2RSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> withRocfft $ do
      let n = 8 :: Int
          k = n `div` 2 + 1
          invScale = 1.0 / fromIntegral n :: Double
          input = fmap (\x -> CFloat (fromIntegral x)) [0 .. n - 1]
          bytesReal = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
          bytesHerm = fromIntegral (k * sizeOf (undefined :: Complex Float)) :: CSize

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input

          bracket (hipMallocBytes bytesReal :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
            bracket (hipMallocBytes bytesHerm :: IO (DevicePtr (Complex Float))) hipFree $ \dFreq ->
              bracket (hipMallocBytes bytesReal :: IO (DevicePtr CFloat)) hipFree $ \dOut -> do
                hipMemcpyH2D dIn (HostPtr hIn) bytesReal

                bracket hipStreamCreate hipStreamDestroy $ \stream ->
                  withRocfftExecutionInfo $ \info -> do
                    rocfftExecutionInfoSetStream info stream
                    withRocfftPlanDescription $ \descF -> do
                      rocfftPlanDescriptionSetDataLayout
                        descF
                        RocfftArrayTypeReal
                        RocfftArrayTypeHermitianInterleaved
                        Nothing
                        Nothing
                        [1]
                        (fromIntegral n)
                        [1]
                        (fromIntegral k)
                      withRocfftPlan
                        ( rocfftPlanCreate
                            RocfftPlacementNotInplace
                            RocfftTransformTypeRealForward
                            RocfftPrecisionSingle
                            [fromIntegral n]
                            1
                            (Just descF)
                        )
                        $ \planF -> do
                          withRocfftPlanDescription $ \descI -> do
                            rocfftPlanDescriptionSetScaleFactor descI invScale
                            rocfftPlanDescriptionSetDataLayout
                              descI
                              RocfftArrayTypeHermitianInterleaved
                              RocfftArrayTypeReal
                              Nothing
                              Nothing
                              [1]
                              (fromIntegral k)
                              [1]
                              (fromIntegral n)
                            withRocfftPlan
                              ( rocfftPlanCreate
                                  RocfftPlacementNotInplace
                                  RocfftTransformTypeRealInverse
                                  RocfftPrecisionSingle
                                  [fromIntegral n]
                                  1
                                  (Just descI)
                              )
                              $ \planI -> do
                                rocfftPlanGetPrint planF
                                workF <- rocfftPlanGetWorkBufferSize planF
                                workI <- rocfftPlanGetWorkBufferSize planI
                                let workBytes = max workF workI
                                bracket
                                  (if workBytes > 0 then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ())) else pure Nothing)
                                  (\mWork -> maybe (pure ()) hipFree mWork)
                                  $ \mWork -> do
                                    case mWork of
                                      Nothing -> pure ()
                                      Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes
                                    let DevicePtr pIn = dIn
                                        DevicePtr pFreq = dFreq
                                        DevicePtr pOut = dOut
                                    rocfftExecute planF [castPtr pIn] [castPtr pFreq] (Just info)
                                    rocfftExecute planI [castPtr pFreq] [castPtr pOut] (Just info)
                                    hipStreamSynchronize stream

                hipMemcpyD2H (HostPtr hOut) dOut bytesReal
                out <- peekArray n hOut
                if approxVecWithTol 1.0e-3 out input
                  then pure SmokePassed
                  else fail ("rocFFT R2C/C2R mismatch: expected=" <> show input <> ", got=" <> show out)

rocfftSmoke :: IO SmokeResult
rocfftSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> withRocfft $ do
      let n = 16 :: Int
          scale = fromIntegral n :: Float
          input :: [Complex Float]
          input = [fromIntegral k :+ fromIntegral ((k * 7) `mod` 5) | k <- [0 .. n - 1]]
          expected = fmap (\z -> z * (scale :+ 0)) input
          bytes = fromIntegral (n * sizeOf (undefined :: Complex Float)) :: CSize

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input

          bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dBuf -> do
            hipMemcpyH2D dBuf (HostPtr hIn) bytes

            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              withRocfftExecutionInfo $ \info -> do
                rocfftExecutionInfoSetStream info stream

                withRocfftPlan
                  ( rocfftPlanCreate
                      RocfftPlacementInplace
                      RocfftTransformTypeComplexForward
                      RocfftPrecisionSingle
                      [fromIntegral n]
                      1
                      Nothing
                  )
                  $ \planF ->
                    withRocfftPlan
                      ( rocfftPlanCreate
                          RocfftPlacementInplace
                          RocfftTransformTypeComplexInverse
                          RocfftPrecisionSingle
                          [fromIntegral n]
                          1
                          Nothing
                      )
                      $ \planI -> do
                        workF <- rocfftPlanGetWorkBufferSize planF
                        workI <- rocfftPlanGetWorkBufferSize planI
                        let workBytes = max workF workI

                        bracket
                          ( if workBytes > 0
                              then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ()))
                              else pure Nothing
                          )
                          (\m -> maybe (pure ()) hipFree m)
                          $ \mWorkBuf -> do
                            case mWorkBuf of
                              Nothing -> pure ()
                              Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes

                            let DevicePtr p = dBuf
                                inPtrs = [castPtr p]

                            rocfftExecute planF inPtrs [] (Just info)
                            rocfftExecute planI inPtrs [] (Just info)
                            hipStreamSynchronize stream

            hipMemcpyD2H (HostPtr hOut) dBuf bytes

          out <- peekArray n hOut
          if approxComplexVec out expected
            then pure SmokePassed
            else fail ("rocFFT mismatch: expected=" <> show expected <> ", got=" <> show out)

rocfftBatchedNotInplaceSmoke :: IO SmokeResult
rocfftBatchedNotInplaceSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> withRocfft $ do
      let len1 = 4 :: Int
          batchCount = 2 :: Int
          total = len1 * batchCount
          scale = fromIntegral len1 :: Float
          input :: [Complex Float]
          input = [fromIntegral i :+ fromIntegral ((i * 3) `mod` 5) | i <- [0 .. total - 1]]
          expected = fmap (\z -> z * (scale :+ 0)) input
          bytes = fromIntegral (total * sizeOf (undefined :: Complex Float)) :: CSize
          strides = [1]
          distance = fromIntegral len1 :: CSize

      bracket (mallocArray total :: IO (Ptr (Complex Float))) free $ \hIn ->
        bracket (mallocArray total :: IO (Ptr (Complex Float))) free $ \hOut -> do
          pokeArray hIn input

          bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dIn ->
            bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dMid ->
              bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dOut -> do
                hipMemcpyH2D dIn (HostPtr hIn) bytes

                bracket hipStreamCreate hipStreamDestroy $ \stream ->
                  withRocfftExecutionInfo $ \info -> do
                    rocfftExecutionInfoSetStream info stream

                    withRocfftPlanDescription $ \desc -> do
                      rocfftPlanDescriptionSetDataLayout
                        desc
                        RocfftArrayTypeComplexInterleaved
                        RocfftArrayTypeComplexInterleaved
                        Nothing
                        Nothing
                        strides
                        distance
                        strides
                        distance

                      withRocfftPlan
                        ( rocfftPlanCreate
                            RocfftPlacementNotInplace
                            RocfftTransformTypeComplexForward
                            RocfftPrecisionSingle
                            [fromIntegral len1]
                            (fromIntegral batchCount)
                            (Just desc)
                        )
                        $ \planF ->
                          withRocfftPlan
                            ( rocfftPlanCreate
                                RocfftPlacementNotInplace
                                RocfftTransformTypeComplexInverse
                                RocfftPrecisionSingle
                                [fromIntegral len1]
                                (fromIntegral batchCount)
                                (Just desc)
                            )
                            $ \planI -> do
                              workF <- rocfftPlanGetWorkBufferSize planF
                              workI <- rocfftPlanGetWorkBufferSize planI
                              let workBytes = max workF workI

                              bracket
                                (if workBytes > 0 then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ())) else pure Nothing)
                                (\m -> maybe (pure ()) hipFree m)
                                $ \mWorkBuf -> do
                                  case mWorkBuf of
                                    Nothing -> pure ()
                                    Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes

                                  let DevicePtr pIn = dIn
                                      DevicePtr pMid = dMid
                                      DevicePtr pOut = dOut
                                  rocfftExecute planF [castPtr pIn] [castPtr pMid] (Just info)
                                  rocfftExecute planI [castPtr pMid] [castPtr pOut] (Just info)
                                  hipStreamSynchronize stream

                hipMemcpyD2H (HostPtr hOut) dOut bytes

          out <- peekArray total hOut
          if approxComplexVec out expected
            then pure SmokePassed
            else fail ("rocFFT batched not-inplace mismatch: expected=" <> show expected <> ", got=" <> show out)

rocrandUniformSmoke :: IO SmokeResult
rocrandUniformSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocrandSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 64 :: Int
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              rngType = RocRandRngPseudoDefault :: RocRandRngType

          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dA ->
            bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dB ->
              bracket (mallocArray n) free $ \hA ->
                bracket (mallocArray n) free $ \hB -> do
                  withRocRandGenerator rngType $ \g1 ->
                    withRocRandGenerator rngType $ \g2 -> do
                      rocrandSetSeed g1 12345
                      rocrandSetSeed g2 12345
                      rocrandGenerateUniform g1 dA (fromIntegral n)
                      rocrandGenerateUniform g2 dB (fromIntegral n)
                      hipDeviceSynchronize
                  hipMemcpyD2H (HostPtr hA) dA bytes
                  hipMemcpyD2H (HostPtr hB) dB bytes
                  xs <- peekArray n hA
                  ys <- peekArray n hB
                  if xs == ys && all inUnitInterval xs
                    then pure SmokePassed
                    else fail ("rocRAND uniform mismatch or out of range")
  where
    inUnitInterval (CFloat x) = x > 0 && x <= 1

rocfftNormalizedSmoke :: IO SmokeResult
rocfftNormalizedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> withRocfft $ do
      let n = 16 :: Int
          input :: [Complex Float]
          input = [fromIntegral k :+ fromIntegral ((k * 7) `mod` 5) | k <- [0 .. n - 1]]
          expected = input
          bytes = fromIntegral (n * sizeOf (undefined :: Complex Float)) :: CSize
          invScale = 1.0 / fromIntegral n :: Double

      bracket (mallocArray n) free $ \hIn ->
        bracket (mallocArray n) free $ \hOut -> do
          pokeArray hIn input

          bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dBuf -> do
            hipMemcpyH2D dBuf (HostPtr hIn) bytes

            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              withRocfftExecutionInfo $ \info -> do
                rocfftExecutionInfoSetStream info stream

                withRocfftPlan
                  ( rocfftPlanCreate
                      RocfftPlacementInplace
                      RocfftTransformTypeComplexForward
                      RocfftPrecisionSingle
                      [fromIntegral n]
                      1
                      Nothing
                  )
                  $ \planF ->
                    withRocfftPlanDescription $ \descInv -> do
                      rocfftPlanDescriptionSetScaleFactor descInv invScale
                      withRocfftPlan
                        ( rocfftPlanCreate
                            RocfftPlacementInplace
                            RocfftTransformTypeComplexInverse
                            RocfftPrecisionSingle
                            [fromIntegral n]
                            1
                            (Just descInv)
                        )
                        $ \planI -> do
                          workF <- rocfftPlanGetWorkBufferSize planF
                          workI <- rocfftPlanGetWorkBufferSize planI
                          let workBytes = max workF workI

                          bracket
                            (if workBytes > 0 then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ())) else pure Nothing)
                            (\m -> maybe (pure ()) hipFree m)
                            $ \mWorkBuf -> do
                              case mWorkBuf of
                                Nothing -> pure ()
                                Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes

                              let DevicePtr p = dBuf
                                  inPtrs = [castPtr p]
                              rocfftExecute planF inPtrs [] (Just info)
                              rocfftExecute planI inPtrs [] (Just info)
                              hipStreamSynchronize stream

            hipMemcpyD2H (HostPtr hOut) dBuf bytes

          out <- peekArray n hOut
          if approxComplexVec out expected
            then pure SmokePassed
            else fail ("rocFFT normalized mismatch: expected=" <> show expected <> ", got=" <> show out)

rocblasGemvSmoke :: IO SmokeResult
rocblasGemvSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 2 :: Int
              n = 2 :: Int
              aVals = fmap CFloat [1, 3, 2, 4]
              xVals = fmap CFloat [10, 20]
              expected = fmap CFloat [50, 110]
              bytesA = fromIntegral (m * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesX = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesY = fromIntegral (m * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray (m * n)) free $ \hA ->
            bracket (mallocArray n) free $ \hX ->
              bracket (mallocArray m) free $ \hY -> do
                pokeArray hA aVals
                pokeArray hX xVals
                pokeArray hY (replicate m (CFloat 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesX :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                    bracket (hipMallocBytes bytesY :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dX (HostPtr hX) bytesX
                      hipMemcpyH2D dY (HostPtr hY) bytesY

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasSgemv
                            handle
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            dX
                            1
                            0.0
                            dY
                            1
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hY) dY bytesY

                out <- peekArray m hY
                if approxVec out expected
                  then pure SmokePassed
                  else fail ("rocBLAS SGEMV mismatch: expected=" <> show expected <> ", got=" <> show out)

rocblasDGemvSmoke :: IO SmokeResult
rocblasDGemvSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 2 :: Int
              n = 2 :: Int
              aVals = fmap CDouble [1, 3, 2, 4]
              xVals = fmap CDouble [10, 20]
              expected = fmap CDouble [50, 110]
              bytesA = fromIntegral (m * n * sizeOf (undefined :: CDouble)) :: CSize
              bytesX = fromIntegral (n * sizeOf (undefined :: CDouble)) :: CSize
              bytesY = fromIntegral (m * sizeOf (undefined :: CDouble)) :: CSize

          bracket (mallocArray (m * n)) free $ \hA ->
            bracket (mallocArray n) free $ \hX ->
              bracket (mallocArray m) free $ \hY -> do
                pokeArray hA aVals
                pokeArray hX xVals
                pokeArray hY (replicate m (CDouble 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CDouble)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesX :: IO (DevicePtr CDouble)) hipFree $ \dX ->
                    bracket (hipMallocBytes bytesY :: IO (DevicePtr CDouble)) hipFree $ \dY -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dX (HostPtr hX) bytesX
                      hipMemcpyH2D dY (HostPtr hY) bytesY

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasDgemv
                            handle
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            dX
                            1
                            0.0
                            dY
                            1
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hY) dY bytesY

                out <- peekArray m hY
                if approxDVec out expected
                  then pure SmokePassed
                  else fail ("rocBLAS DGEMV mismatch: expected=" <> show expected <> ", got=" <> show out)

rocsparseScsrmvSmoke :: IO SmokeResult
rocsparseScsrmvSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsparseSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 3 :: Int
              n = 3 :: Int
              nnz = 5 :: Int
              rowPtrVals = [0, 2, 3, 5] :: [Int]
              colIndVals = [0, 2, 1, 0, 2] :: [Int]
              valVals = fmap CFloat [1, 2, 3, 4, 5]
              xVals = fmap CFloat [10, 20, 30]
              yVals = replicate m (CFloat 0)
              expected = fmap CFloat [70, 60, 190]
              bytesRowPtr = fromIntegral (length rowPtrVals * sizeOf (undefined :: RocsparseInt)) :: CSize
              bytesColInd = fromIntegral (nnz * sizeOf (undefined :: RocsparseInt)) :: CSize
              bytesVal = fromIntegral (nnz * sizeOf (undefined :: CFloat)) :: CSize
              bytesX = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesY = fromIntegral (m * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray (length rowPtrVals) :: IO (Ptr RocsparseInt)) free $ \hRowPtr ->
            bracket (mallocArray nnz :: IO (Ptr RocsparseInt)) free $ \hColInd ->
              bracket (mallocArray nnz :: IO (Ptr CFloat)) free $ \hVal ->
                bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hX ->
                  bracket (mallocArray m :: IO (Ptr CFloat)) free $ \hY -> do
                    pokeArray hRowPtr (fromIntegral <$> rowPtrVals)
                    pokeArray hColInd (fromIntegral <$> colIndVals)
                    pokeArray hVal valVals
                    pokeArray hX xVals
                    pokeArray hY yVals

                    bracket (hipMallocBytes bytesRowPtr :: IO (DevicePtr RocsparseInt)) hipFree $ \dRowPtr ->
                      bracket (hipMallocBytes bytesColInd :: IO (DevicePtr RocsparseInt)) hipFree $ \dColInd ->
                        bracket (hipMallocBytes bytesVal :: IO (DevicePtr CFloat)) hipFree $ \dVal ->
                          bracket (hipMallocBytes bytesX :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                            bracket (hipMallocBytes bytesY :: IO (DevicePtr CFloat)) hipFree $ \dY ->
                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocsparseHandle $ \handle ->
                                  withRocsparseMatDescr $ \descr -> do
                                    hipMemcpyH2D dRowPtr (HostPtr hRowPtr) bytesRowPtr
                                    hipMemcpyH2D dColInd (HostPtr hColInd) bytesColInd
                                    hipMemcpyH2D dVal (HostPtr hVal) bytesVal
                                    hipMemcpyH2D dX (HostPtr hX) bytesX
                                    hipMemcpyH2D dY (HostPtr hY) bytesY

                                    rocsparseSetStream handle stream
                                    rocsparseSetMatIndexBase descr RocsparseIndexBaseZero
                                    rocsparseSetMatType descr RocsparseMatrixTypeGeneral
                                    rocsparseScsrmv
                                      handle
                                      RocsparseOperationNone
                                      (fromIntegral m :: RocsparseInt)
                                      (fromIntegral n :: RocsparseInt)
                                      (fromIntegral nnz :: RocsparseInt)
                                      1.0
                                      descr
                                      dVal
                                      dRowPtr
                                      dColInd
                                      dX
                                      0.0
                                      dY
                                    hipStreamSynchronize stream
                                    hipMemcpyD2H (HostPtr hY) dY bytesY

                    out <- peekArray m hY
                    if approxVec out expected
                      then pure SmokePassed
                      else fail ("rocSPARSE SCSRMV mismatch: expected=" <> show expected <> ", got=" <> show out)

rocsparseGenericSpmvSmoke :: IO SmokeResult
rocsparseGenericSpmvSmoke = do
  _ <- pure RocsparseIndexTypeI32
  _ <- pure RocsparseDataTypeF32R
  _ <- pure RocsparseV2SpMVStageAnalysis
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsparseSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 3 :: Int
              n = 3 :: Int
              nnz = 5 :: Int
              rowPtrVals = [0, 2, 3, 5] :: [Int]
              colIndVals = [0, 2, 1, 0, 2] :: [Int]
              valVals = fmap CFloat [1, 2, 3, 4, 5]
              xVals = fmap CFloat [10, 20, 30]
              yVals = replicate m (CFloat 0)
              expected = fmap CFloat [70, 60, 190]
              bytesRowPtr = fromIntegral (length rowPtrVals * sizeOf (undefined :: RocsparseInt)) :: CSize
              bytesColInd = fromIntegral (nnz * sizeOf (undefined :: RocsparseInt)) :: CSize
              bytesVal = fromIntegral (nnz * sizeOf (undefined :: CFloat)) :: CSize
              bytesX = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesY = fromIntegral (m * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray (length rowPtrVals) :: IO (Ptr RocsparseInt)) free $ \hRowPtr ->
            bracket (mallocArray nnz :: IO (Ptr RocsparseInt)) free $ \hColInd ->
              bracket (mallocArray nnz :: IO (Ptr CFloat)) free $ \hVal ->
                bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hX ->
                  bracket (mallocArray m :: IO (Ptr CFloat)) free $ \hY -> do
                    pokeArray hRowPtr (fromIntegral <$> rowPtrVals)
                    pokeArray hColInd (fromIntegral <$> colIndVals)
                    pokeArray hVal valVals
                    pokeArray hX xVals
                    pokeArray hY yVals

                    bracket (hipMallocBytes bytesRowPtr :: IO (DevicePtr RocsparseInt)) hipFree $ \dRowPtr ->
                      bracket (hipMallocBytes bytesColInd :: IO (DevicePtr RocsparseInt)) hipFree $ \dColInd ->
                        bracket (hipMallocBytes bytesVal :: IO (DevicePtr CFloat)) hipFree $ \dVal ->
                          bracket (hipMallocBytes bytesX :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                            bracket (hipMallocBytes bytesY :: IO (DevicePtr CFloat)) hipFree $ \dY ->
                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocsparseHandle $ \handle -> do
                                  hipMemcpyH2D dRowPtr (HostPtr hRowPtr) bytesRowPtr
                                  hipMemcpyH2D dColInd (HostPtr hColInd) bytesColInd
                                  hipMemcpyH2D dVal (HostPtr hVal) bytesVal
                                  hipMemcpyH2D dX (HostPtr hX) bytesX
                                  hipMemcpyH2D dY (HostPtr hY) bytesY

                                  rocsparseSetStream handle stream
                                  withRocsparseCsrDescr
                                    (fromIntegral m)
                                    (fromIntegral n)
                                    (fromIntegral nnz)
                                    dRowPtr
                                    dColInd
                                    dVal
                                    RocsparseIndexTypeI32
                                    RocsparseIndexTypeI32
                                    RocsparseIndexBaseZero
                                    RocsparseDataTypeF32R
                                    $ \aDescr ->
                                      withRocsparseDnVecDescr (fromIntegral n) dX RocsparseDataTypeF32R $ \xDescr ->
                                        withRocsparseDnVecDescr (fromIntegral m) dY RocsparseDataTypeF32R $ \yDescr ->
                                          withRocsparseSpMVDescr $ \spmvDescr -> do
                                            rocsparseConfigureSV2SpMV handle spmvDescr RocsparseOperationNone
                                            analysisBytes <- rocsparseSV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr RocsparseV2SpMVStageAnalysis
                                            computeBytes <- rocsparseSV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr RocsparseV2SpMVStageCompute
                                            let bufferBytes = max analysisBytes computeBytes
                                            bracket
                                              ( if bufferBytes > 0
                                                  then Just <$> (hipMallocBytes bufferBytes :: IO (DevicePtr ()))
                                                  else pure Nothing
                                              )
                                              (\mTemp -> maybe (pure ()) hipFree mTemp)
                                              $ \mTemp -> do
                                                rocsparseSV2SpMV handle spmvDescr aDescr xDescr yDescr 1.0 0.0 RocsparseV2SpMVStageAnalysis bufferBytes mTemp
                                                rocsparseSV2SpMV handle spmvDescr aDescr xDescr yDescr 1.0 0.0 RocsparseV2SpMVStageCompute bufferBytes mTemp
                                                hipStreamSynchronize stream

                                  hipMemcpyD2H (HostPtr hY) dY bytesY

                    out <- peekArray m hY
                    if approxVec out expected
                      then pure SmokePassed
                      else fail ("rocSPARSE generic SpMV mismatch: expected=" <> show expected <> ", got=" <> show out)

rocsolverSposvSmoke :: IO SmokeResult
rocsolverSposvSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              nrhs = 1 :: Int
              aVals = fmap CFloat [4, 1, 1, 3]
              bVals = fmap CFloat [1, 2]
              expected = fmap CFloat [1 / 11, 7 / 11]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesB = fromIntegral (n * nrhs * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray (n * nrhs) :: IO (Ptr CFloat)) free $ \hB ->
              bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                pokeArray hA aVals
                pokeArray hB bVals

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesB :: IO (DevicePtr CFloat)) hipFree $ \dB ->
                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dB (HostPtr hB) bytesB

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocsolverSposv
                            handle
                            RocblasFillLower
                            (fromIntegral n :: RocblasInt)
                            (fromIntegral nrhs :: RocblasInt)
                            dA
                            (fromIntegral n :: RocblasInt)
                            dB
                            (fromIntegral n :: RocblasInt)
                            dInfo
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hB) dB bytesB
                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                out <- peekArray (n * nrhs) hB
                infoVals <- peekArray 1 hInfo
                let infoOk = case infoVals of
                      [infoVal] -> infoVal == 0
                      _ -> False
                if infoOk && approxVec out expected
                  then pure SmokePassed
                  else fail ("rocSOLVER SPOSV mismatch: expected=" <> show expected <> ", got=" <> show out <> ", info=" <> show infoVals)

rocsolverSgesvSmoke :: IO SmokeResult
rocsolverSgesvSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              nrhs = 1 :: Int
              aVals = fmap CFloat [0, 1, 2, 3]
              bVals = fmap CFloat [4, 5]
              expected = fmap CFloat [-1, 2]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesB = fromIntegral (n * nrhs * sizeOf (undefined :: CFloat)) :: CSize
              bytesIpiv = fromIntegral (n * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray (n * nrhs) :: IO (Ptr CFloat)) free $ \hB ->
              bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                pokeArray hA aVals
                pokeArray hB bVals

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesB :: IO (DevicePtr CFloat)) hipFree $ \dB ->
                    bracket (hipMallocBytes bytesIpiv :: IO (DevicePtr RocblasInt)) hipFree $ \dIpiv ->
                      bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                        hipMemcpyH2D dA (HostPtr hA) bytesA
                        hipMemcpyH2D dB (HostPtr hB) bytesB

                        bracket hipStreamCreate hipStreamDestroy $ \stream ->
                          withRocblasHandle $ \handle -> do
                            rocblasSetStream handle stream
                            rocsolverSgesv
                              handle
                              (fromIntegral n :: RocblasInt)
                              (fromIntegral nrhs :: RocblasInt)
                              dA
                              (fromIntegral n :: RocblasInt)
                              dIpiv
                              dB
                              (fromIntegral n :: RocblasInt)
                              dInfo
                            hipStreamSynchronize stream

                        hipMemcpyD2H (HostPtr hB) dB bytesB
                        hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                out <- peekArray (n * nrhs) hB
                infoVals <- peekArray 1 hInfo
                let infoOk = case infoVals of
                      [infoVal] -> infoVal == 0
                      _ -> False
                if infoOk && approxVec out expected
                  then pure SmokePassed
                  else fail ("rocSOLVER SGESV mismatch: expected=" <> show expected <> ", got=" <> show out <> ", info=" <> show infoVals)

rocsolverSgeqrfOrgqrSmoke :: IO SmokeResult
rocsolverSgeqrfOrgqrSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 3 :: Int
              n = 2 :: Int
              k = min m n
              aOriginal = fmap CFloat [1, 2, 3, 4, 5, 6]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (m * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesTau = fromIntegral (k * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hAIn ->
            bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hAFact ->
              bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hQ -> do
                pokeArray hAIn aOriginal

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesTau :: IO (DevicePtr CFloat)) hipFree $ \dTau -> do
                    hipMemcpyH2D dA (HostPtr hAIn) bytesA

                    bracket hipStreamCreate hipStreamDestroy $ \stream ->
                      withRocblasHandle $ \handle -> do
                        rocblasSetStream handle stream
                        rocsolverSgeqrf
                          handle
                          (fromIntegral m :: RocblasInt)
                          (fromIntegral n :: RocblasInt)
                          dA
                          (fromIntegral m :: RocblasInt)
                          dTau
                        hipStreamSynchronize stream
                        hipMemcpyD2H (HostPtr hAFact) dA bytesA

                        rocsolverSorgqr
                          handle
                          (fromIntegral m :: RocblasInt)
                          (fromIntegral n :: RocblasInt)
                          (fromIntegral k :: RocblasInt)
                          dA
                          (fromIntegral m :: RocblasInt)
                          dTau
                        hipStreamSynchronize stream
                        hipMemcpyD2H (HostPtr hQ) dA bytesA

                factorized <- peekArray (m * n) hAFact
                qVals <- peekArray (m * n) hQ
                let rVals = extractThinRColMajor m n factorized
                    recon = matMulColMajorCFloat m n n qVals rVals
                    qtq = gramMatrixColMajorCFloat m n qVals
                if approxVecWithTol 1.0e-3 recon aOriginal && approxVecWithTol 1.0e-3 qtq identity2
                  then pure SmokePassed
                  else fail ("rocSOLVER SGEQRF/ORGQR mismatch: recon=" <> show recon <> ", qtq=" <> show qtq <> ", r=" <> show rVals)

rocsolverSsyevSmoke :: IO SmokeResult
rocsolverSsyevSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              aOriginal = fmap CFloat [2, 1, 1, 2]
              expectedVals = fmap CFloat [1, 3]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesD = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesE = fromIntegral ((n - 1) * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hD ->
              bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                pokeArray hA aOriginal

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesD :: IO (DevicePtr CFloat)) hipFree $ \dD ->
                    bracket (hipMallocBytes bytesE :: IO (DevicePtr CFloat)) hipFree $ \dE ->
                      bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                        hipMemcpyH2D dA (HostPtr hA) bytesA

                        bracket hipStreamCreate hipStreamDestroy $ \stream ->
                          withRocblasHandle $ \handle -> do
                            rocblasSetStream handle stream
                            rocsolverSsyev
                              handle
                              RocblasEvectOriginal
                              RocblasFillLower
                              (fromIntegral n :: RocblasInt)
                              dA
                              (fromIntegral n :: RocblasInt)
                              dD
                              dE
                              dInfo
                            hipStreamSynchronize stream

                        hipMemcpyD2H (HostPtr hA) dA bytesA
                        hipMemcpyD2H (HostPtr hD) dD bytesD
                        hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                vectors <- peekArray (n * n) hA
                eigenVals <- peekArray n hD
                infoVals <- peekArray 1 hInfo
                let infoOk = case infoVals of
                      [infoVal] -> infoVal == 0
                      _ -> False
                    lhs = matMulColMajorCFloat n n n aOriginal vectors
                    rhs = matMulColMajorCFloat n n n vectors (diagColMajorCFloat eigenVals)
                    gram = gramMatrixColMajorCFloat n n vectors
                if infoOk
                    && approxVecWithTol 1.0e-3 eigenVals expectedVals
                    && approxVecWithTol 1.0e-3 lhs rhs
                    && approxVecWithTol 1.0e-3 gram identity2
                  then pure SmokePassed
                  else fail ("rocSOLVER SSYEV mismatch: eigenVals=" <> show eigenVals <> ", lhs=" <> show lhs <> ", rhs=" <> show rhs <> ", gram=" <> show gram <> ", info=" <> show infoVals)

rocsolverSgesvdSmoke :: IO SmokeResult
rocsolverSgesvdSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              aOriginal = fmap CFloat [3, 0, 0, 1]
              expectedS = fmap CFloat [3, 1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesS = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesE = fromIntegral ((n - 1) * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                    pokeArray hA aOriginal

                    bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                      bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                        bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                          bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                            bracket (hipMallocBytes bytesE :: IO (DevicePtr CFloat)) hipFree $ \dE ->
                              bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                hipMemcpyH2D dA (HostPtr hA) bytesA

                                bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                  withRocblasHandle $ \handle -> do
                                    rocblasSetStream handle stream
                                    rocsolverSgesvd
                                      handle
                                      RocblasSvectSingular
                                      RocblasSvectSingular
                                      (fromIntegral n :: RocblasInt)
                                      (fromIntegral n :: RocblasInt)
                                      dA
                                      (fromIntegral n :: RocblasInt)
                                      dS
                                      dU
                                      (fromIntegral n :: RocblasInt)
                                      dV
                                      (fromIntegral n :: RocblasInt)
                                      dE
                                      RocblasInPlace
                                      dInfo
                                    hipStreamSynchronize stream

                                hipMemcpyD2H (HostPtr hS) dS bytesS
                                hipMemcpyD2H (HostPtr hU) dU bytesU
                                hipMemcpyD2H (HostPtr hV) dV bytesV
                                hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                    sVals <- peekArray n hS
                    uVals <- peekArray (n * n) hU
                    vVals <- peekArray (n * n) hV
                    infoVals <- peekArray 1 hInfo
                    let infoOk = case infoVals of
                          [infoVal] -> infoVal == 0
                          _ -> False
                        us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                        recon = matMulColMajorCFloat n n n us vVals
                        uGram = gramMatrixColMajorCFloat n n uVals
                        vGram = gramMatrixColMajorCFloat n n vVals
                    if infoOk
                        && approxVecWithTol 1.0e-3 sVals expectedS
                        && approxVecWithTol 1.0e-3 recon aOriginal
                        && approxVecWithTol 1.0e-3 uGram identity2
                        && approxVecWithTol 1.0e-3 vGram identity2
                      then pure SmokePassed
                      else fail ("rocSOLVER SGESVD mismatch: s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVals)

rocsolverSgesddSmoke :: IO SmokeResult
rocsolverSgesddSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              aOriginal = fmap CFloat [3, 0, 0, 1]
              expectedS = fmap CFloat [3, 1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesS = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                    pokeArray hA aOriginal

                    bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                      bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                        bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                          bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                            bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                              hipMemcpyH2D dA (HostPtr hA) bytesA

                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocblasHandle $ \handle -> do
                                  rocblasSetStream handle stream
                                  rocsolverSgesdd
                                    handle
                                    RocblasSvectSingular
                                    RocblasSvectSingular
                                    (fromIntegral n :: RocblasInt)
                                    (fromIntegral n :: RocblasInt)
                                    dA
                                    (fromIntegral n :: RocblasInt)
                                    dS
                                    dU
                                    (fromIntegral n :: RocblasInt)
                                    dV
                                    (fromIntegral n :: RocblasInt)
                                    dInfo
                                  hipStreamSynchronize stream

                              hipMemcpyD2H (HostPtr hS) dS bytesS
                              hipMemcpyD2H (HostPtr hU) dU bytesU
                              hipMemcpyD2H (HostPtr hV) dV bytesV
                              hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                    sVals <- peekArray n hS
                    uVals <- peekArray (n * n) hU
                    vVals <- peekArray (n * n) hV
                    infoVals <- peekArray 1 hInfo
                    let infoOk = case infoVals of
                          [infoVal] -> infoVal == 0
                          _ -> False
                        us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                        recon = matMulColMajorCFloat n n n us vVals
                        uGram = gramMatrixColMajorCFloat n n uVals
                        vGram = gramMatrixColMajorCFloat n n vVals
                    if infoOk
                        && approxVecWithTol 1.0e-3 sVals expectedS
                        && approxVecWithTol 1.0e-3 recon aOriginal
                        && approxVecWithTol 1.0e-3 uGram identity2
                        && approxVecWithTol 1.0e-3 vGram identity2
                      then pure SmokePassed
                      else fail ("rocSOLVER SGESDD mismatch: s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVals)

rocsolverSgesddBatchedSmoke :: IO SmokeResult
rocsolverSgesddBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              strideSCount = n
              strideUCount = n * n
              strideVCount = n * n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [fmap CFloat [3, 1], fmap CFloat [4, 2]]
              expectedMatrices = [aBatch0, aBatch1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              matrixElems = n * n
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                  bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                    bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                      pokeArray hAFlat (aBatch0 <> aBatch1)

                      bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                        bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                          bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                            bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                              bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                  hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                  let DevicePtr pAFlat = dAFlat
                                      aPtrs = [pAFlat `plusPtr` (idx * matrixBytesInt) | idx <- [0 .. batchCount - 1]]
                                  pokeArray hAPtrs aPtrs
                                  hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs

                                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                    withRocblasHandle $ \handle -> do
                                      rocblasSetStream handle stream
                                      rocsolverSgesddBatched
                                        handle
                                        RocblasSvectSingular
                                        RocblasSvectSingular
                                        (fromIntegral n :: RocblasInt)
                                        (fromIntegral n :: RocblasInt)
                                        dAPtrs
                                        (fromIntegral n :: RocblasInt)
                                        dS
                                        strideS
                                        dU
                                        (fromIntegral n :: RocblasInt)
                                        strideU
                                        dV
                                        (fromIntegral n :: RocblasInt)
                                        strideV
                                        dInfo
                                        batchCount'
                                      hipStreamSynchronize stream

                                  hipMemcpyD2H (HostPtr hS) dS bytesS
                                  hipMemcpyD2H (HostPtr hU) dU bytesU
                                  hipMemcpyD2H (HostPtr hV) dV bytesV
                                  hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                      sAll <- peekArray (batchCount * strideSCount) hS
                      uAll <- peekArray (batchCount * strideUCount) hU
                      vAll <- peekArray (batchCount * strideVCount) hV
                      infoVals <- peekArray batchCount hInfo
                      let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                          batchReport idx =
                            let sVals = batchSlice strideSCount idx sAll
                                uVals = batchSlice strideUCount idx uAll
                                vVals = batchSlice strideVCount idx vAll
                                infoVal = infoVals !! idx
                                us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                                recon = matMulColMajorCFloat n n n us vVals
                                uGram = gramMatrixColMajorCFloat n n uVals
                                vGram = gramMatrixColMajorCFloat n n vVals
                                ok = infoVal == 0
                                  && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                  && approxVecWithTol 1.0e-3 recon (expectedMatrices !! idx)
                                  && approxVecWithTol 1.0e-3 uGram identity2
                                  && approxVecWithTol 1.0e-3 vGram identity2
                             in (ok, "batch=" <> show idx <> ", s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVal)
                          reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                      if all fst reports
                        then pure SmokePassed
                        else fail ("rocSOLVER SGESDD batched mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesddStridedBatchedSmoke :: IO SmokeResult
rocsolverSgesddStridedBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              strideACount = n * n
              strideSCount = n
              strideUCount = n * n
              strideVCount = n * n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [fmap CFloat [3, 1], fmap CFloat [4, 2]]
              expectedMatrices = [aBatch0, aBatch1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (batchCount * strideACount * sizeOf (undefined :: CFloat)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideA = fromIntegral strideACount :: RocblasStride
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * strideACount) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                    pokeArray hA (aBatch0 <> aBatch1)

                    bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                      bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                        bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                          bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                            bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                              hipMemcpyH2D dA (HostPtr hA) bytesA

                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocblasHandle $ \handle -> do
                                  rocblasSetStream handle stream
                                  rocsolverSgesddStridedBatched
                                    handle
                                    RocblasSvectSingular
                                    RocblasSvectSingular
                                    (fromIntegral n :: RocblasInt)
                                    (fromIntegral n :: RocblasInt)
                                    dA
                                    (fromIntegral n :: RocblasInt)
                                    strideA
                                    dS
                                    strideS
                                    dU
                                    (fromIntegral n :: RocblasInt)
                                    strideU
                                    dV
                                    (fromIntegral n :: RocblasInt)
                                    strideV
                                    dInfo
                                    batchCount'
                                  hipStreamSynchronize stream

                              hipMemcpyD2H (HostPtr hS) dS bytesS
                              hipMemcpyD2H (HostPtr hU) dU bytesU
                              hipMemcpyD2H (HostPtr hV) dV bytesV
                              hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                    sAll <- peekArray (batchCount * strideSCount) hS
                    uAll <- peekArray (batchCount * strideUCount) hU
                    vAll <- peekArray (batchCount * strideVCount) hV
                    infoVals <- peekArray batchCount hInfo
                    let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                        batchReport idx =
                          let sVals = batchSlice strideSCount idx sAll
                              uVals = batchSlice strideUCount idx uAll
                              vVals = batchSlice strideVCount idx vAll
                              infoVal = infoVals !! idx
                              us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                              recon = matMulColMajorCFloat n n n us vVals
                              uGram = gramMatrixColMajorCFloat n n uVals
                              vGram = gramMatrixColMajorCFloat n n vVals
                              ok = infoVal == 0
                                && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                && approxVecWithTol 1.0e-3 recon (expectedMatrices !! idx)
                                && approxVecWithTol 1.0e-3 uGram identity2
                                && approxVecWithTol 1.0e-3 vGram identity2
                           in (ok, "batch=" <> show idx <> ", s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVal)
                        reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                    if all fst reports
                      then pure SmokePassed
                      else fail ("rocSOLVER SGESDD strided-batched mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdjBatchedSmoke :: IO SmokeResult
rocsolverSgesvdjBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              maxSweeps = 100 :: RocblasInt
              strideSCount = n
              strideUCount = n * n
              strideVCount = n * n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [fmap CFloat [3, 1], fmap CFloat [4, 2]]
              expectedMatrices = [aBatch0, aBatch1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              matrixElems = n * n
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesResidual = fromIntegral (batchCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesNSweeps = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray batchCount :: IO (Ptr CFloat)) free $ \hResidual ->
                bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNSweeps ->
                  bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                    bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                      bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                        bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                          pokeArray hAFlat (aBatch0 <> aBatch1)

                          bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                            bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                              bracket (hipMallocBytes bytesResidual :: IO (DevicePtr CFloat)) hipFree $ \dResidual ->
                                bracket (hipMallocBytes bytesNSweeps :: IO (DevicePtr RocblasInt)) hipFree $ \dNSweeps ->
                                  bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                                    bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                      bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                        bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                          hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                          let DevicePtr pAFlat = dAFlat
                                              aPtrs = [pAFlat `plusPtr` (idx * matrixBytesInt) | idx <- [0 .. batchCount - 1]]
                                          pokeArray hAPtrs aPtrs
                                          hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs

                                          bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                            withRocblasHandle $ \handle -> do
                                              rocblasSetStream handle stream
                                              rocsolverSgesvdjBatched
                                                handle
                                                RocblasSvectSingular
                                                RocblasSvectSingular
                                                (fromIntegral n :: RocblasInt)
                                                (fromIntegral n :: RocblasInt)
                                                dAPtrs
                                                (fromIntegral n :: RocblasInt)
                                                0.0
                                                dResidual
                                                maxSweeps
                                                dNSweeps
                                                dS
                                                strideS
                                                dU
                                                (fromIntegral n :: RocblasInt)
                                                strideU
                                                dV
                                                (fromIntegral n :: RocblasInt)
                                                strideV
                                                dInfo
                                                batchCount'
                                              hipStreamSynchronize stream

                                          hipMemcpyD2H (HostPtr hResidual) dResidual bytesResidual
                                          hipMemcpyD2H (HostPtr hNSweeps) dNSweeps bytesNSweeps
                                          hipMemcpyD2H (HostPtr hS) dS bytesS
                                          hipMemcpyD2H (HostPtr hU) dU bytesU
                                          hipMemcpyD2H (HostPtr hV) dV bytesV
                                          hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                          residualVals <- peekArray batchCount hResidual
                          nSweepsVals <- peekArray batchCount hNSweeps
                          sAll <- peekArray (batchCount * strideSCount) hS
                          uAll <- peekArray (batchCount * strideUCount) hU
                          vAll <- peekArray (batchCount * strideVCount) hV
                          infoVals <- peekArray batchCount hInfo
                          let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                              batchReport idx =
                                let residualVal = residualVals !! idx
                                    nSweeps = nSweepsVals !! idx
                                    sVals = batchSlice strideSCount idx sAll
                                    uVals = batchSlice strideUCount idx uAll
                                    vVals = batchSlice strideVCount idx vAll
                                    infoVal = infoVals !! idx
                                    us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                                    recon = matMulColMajorCFloat n n n us vVals
                                    uGram = gramMatrixColMajorCFloat n n uVals
                                    vGram = gramMatrixColMajorCFloat n n vVals
                                    ok = infoVal == 0
                                      && approxCFloatWithTol 1.0e-3 residualVal (CFloat 0)
                                      && nSweeps >= 0 && nSweeps <= maxSweeps
                                      && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                      && approxVecWithTol 1.0e-3 recon (expectedMatrices !! idx)
                                      && approxVecWithTol 1.0e-3 uGram identity2
                                      && approxVecWithTol 1.0e-3 vGram identity2
                                 in (ok, "batch=" <> show idx <> ", residual=" <> show residualVal <> ", sweeps=" <> show nSweeps <> ", s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVal)
                              reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                          if all fst reports
                            then pure SmokePassed
                            else fail ("rocSOLVER SGESVDJ batched mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdjStridedBatchedSmoke :: IO SmokeResult
rocsolverSgesvdjStridedBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              maxSweeps = 100 :: RocblasInt
              strideACount = n * n
              strideSCount = n
              strideUCount = n * n
              strideVCount = n * n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [fmap CFloat [3, 1], fmap CFloat [4, 2]]
              expectedMatrices = [aBatch0, aBatch1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (batchCount * strideACount * sizeOf (undefined :: CFloat)) :: CSize
              bytesResidual = fromIntegral (batchCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesNSweeps = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideA = fromIntegral strideACount :: RocblasStride
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * strideACount) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray batchCount :: IO (Ptr CFloat)) free $ \hResidual ->
              bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNSweeps ->
                bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                  bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                    bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                      bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA (aBatch0 <> aBatch1)

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesResidual :: IO (DevicePtr CFloat)) hipFree $ \dResidual ->
                            bracket (hipMallocBytes bytesNSweeps :: IO (DevicePtr RocblasInt)) hipFree $ \dNSweeps ->
                              bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                                bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                  bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdjStridedBatched
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            strideA
                                            0.0
                                            dResidual
                                            maxSweeps
                                            dNSweeps
                                            dS
                                            strideS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            strideU
                                            dV
                                            (fromIntegral n :: RocblasInt)
                                            strideV
                                            dInfo
                                            batchCount'
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hResidual) dResidual bytesResidual
                                      hipMemcpyD2H (HostPtr hNSweeps) dNSweeps bytesNSweeps
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        residualVals <- peekArray batchCount hResidual
                        nSweepsVals <- peekArray batchCount hNSweeps
                        sAll <- peekArray (batchCount * strideSCount) hS
                        uAll <- peekArray (batchCount * strideUCount) hU
                        vAll <- peekArray (batchCount * strideVCount) hV
                        infoVals <- peekArray batchCount hInfo
                        let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                            batchReport idx =
                              let residualVal = residualVals !! idx
                                  nSweeps = nSweepsVals !! idx
                                  sVals = batchSlice strideSCount idx sAll
                                  uVals = batchSlice strideUCount idx uAll
                                  vVals = batchSlice strideVCount idx vAll
                                  infoVal = infoVals !! idx
                                  us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                                  recon = matMulColMajorCFloat n n n us vVals
                                  uGram = gramMatrixColMajorCFloat n n uVals
                                  vGram = gramMatrixColMajorCFloat n n vVals
                                  ok = infoVal == 0
                                    && approxCFloatWithTol 1.0e-3 residualVal (CFloat 0)
                                    && nSweeps >= 0 && nSweeps <= maxSweeps
                                    && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                    && approxVecWithTol 1.0e-3 recon (expectedMatrices !! idx)
                                    && approxVecWithTol 1.0e-3 uGram identity2
                                    && approxVecWithTol 1.0e-3 vGram identity2
                               in (ok, "batch=" <> show idx <> ", residual=" <> show residualVal <> ", sweeps=" <> show nSweeps <> ", s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVal)
                            reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                        if all fst reports
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDJ strided-batched mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdjSmoke :: IO SmokeResult
rocsolverSgesvdjSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              maxSweeps = 100 :: RocblasInt
              aOriginal = fmap CFloat [3, 0, 0, 1]
              expectedS = fmap CFloat [3, 1]
              identity2 = fmap CFloat [1, 0, 0, 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesResidual = fromIntegral (sizeOf (undefined :: CFloat)) :: CSize
              bytesNSweeps = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray 1 :: IO (Ptr CFloat)) free $ \hResidual ->
                    bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hNSweeps ->
                      bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA aOriginal

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesResidual :: IO (DevicePtr CFloat)) hipFree $ \dResidual ->
                            bracket (hipMallocBytes bytesNSweeps :: IO (DevicePtr RocblasInt)) hipFree $ \dNSweeps ->
                              bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                                bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                  bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdj
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            0.0
                                            dResidual
                                            maxSweeps
                                            dNSweeps
                                            dS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            dV
                                            (fromIntegral n :: RocblasInt)
                                            dInfo
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hResidual) dResidual bytesResidual
                                      hipMemcpyD2H (HostPtr hNSweeps) dNSweeps bytesNSweeps
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        residualVals <- peekArray 1 hResidual
                        nSweepsVals <- peekArray 1 hNSweeps
                        sVals <- peekArray n hS
                        uVals <- peekArray (n * n) hU
                        vVals <- peekArray (n * n) hV
                        infoVals <- peekArray 1 hInfo
                        let infoOk = case infoVals of
                              [infoVal] -> infoVal == 0
                              _ -> False
                            residualOk = case residualVals of
                              [residualVal] -> approxCFloatWithTol 1.0e-3 residualVal (CFloat 0)
                              _ -> False
                            sweepsOk = case nSweepsVals of
                              [nSweeps] -> nSweeps >= 0 && nSweeps <= maxSweeps
                              _ -> False
                            us = matMulColMajorCFloat n n n uVals (diagColMajorCFloat sVals)
                            recon = matMulColMajorCFloat n n n us vVals
                            uGram = gramMatrixColMajorCFloat n n uVals
                            vGram = gramMatrixColMajorCFloat n n vVals
                        if infoOk
                            && residualOk
                            && sweepsOk
                            && approxVecWithTol 1.0e-3 sVals expectedS
                            && approxVecWithTol 1.0e-3 recon aOriginal
                            && approxVecWithTol 1.0e-3 uGram identity2
                            && approxVecWithTol 1.0e-3 vGram identity2
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDJ mismatch: residual=" <> show residualVals <> ", sweeps=" <> show nSweepsVals <> ", s=" <> show sVals <> ", recon=" <> show recon <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", info=" <> show infoVals)

rocsolverSgesvdxSmoke :: IO SmokeResult
rocsolverSgesvdxSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              k = 1 :: Int
              aOriginal = fmap CFloat [3, 0, 0, 1]
              expectedS = [CFloat 3]
              expectedPartial = fmap CFloat [3, 0, 0, 0]
              identity1 = [CFloat 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesNsv = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (k * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (n * k * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (k * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (n * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray k :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (n * k) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (k * n) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hNsv ->
                    bracket (mallocArray n :: IO (Ptr RocblasInt)) free $ \hIfail ->
                      bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA aOriginal

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                            bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                              bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                  bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdx
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            RocblasSrangeIndex
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            0.0
                                            0.0
                                            1
                                            1
                                            dNsv
                                            dS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            dV
                                            1
                                            dIfail
                                            dInfo
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        nsvVals <- peekArray 1 hNsv
                        sVals <- peekArray k hS
                        uVals <- peekArray (n * k) hU
                        vVals <- peekArray (k * n) hV
                        ifailVals <- peekArray n hIfail
                        infoVals <- peekArray 1 hInfo
                        let infoOk = case infoVals of
                              [infoVal] -> infoVal == 0
                              _ -> False
                            nsvOk = case nsvVals of
                              [nsv] -> nsv == 1
                              _ -> False
                            ifailOk = case ifailVals of
                              x : _ -> x == 0
                              _ -> False
                            partial = matMulRightRowVector (matMulColMajorCFloat n k k uVals (diagColMajorCFloat sVals)) vVals
                            uGram = gramMatrixColMajorCFloat n k uVals
                            vNorm = [CFloat (sum [unCFloat x * unCFloat x | x <- vVals])]
                        if infoOk
                            && nsvOk
                            && ifailOk
                            && approxVecWithTol 1.0e-3 sVals expectedS
                            && approxVecWithTol 1.0e-3 partial expectedPartial
                            && approxVecWithTol 1.0e-3 uGram identity1
                            && approxVecWithTol 1.0e-3 vNorm identity1
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDX mismatch: nsv=" <> show nsvVals <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vNorm=" <> show vNorm <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVals)

rocsolverSgesvdxValueSmoke :: IO SmokeResult
rocsolverSgesvdxValueSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 2 :: Int
              kUpper = n
              aOriginal = fmap CFloat [3, 0, 0, 1]
              expectedS = [CFloat 3]
              expectedPartial = fmap CFloat [3, 0, 0, 0]
              identity1 = [CFloat 1]
              bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesNsv = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (kUpper * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (n * kUpper * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (kUpper * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (kUpper * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

          bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray kUpper :: IO (Ptr CFloat)) free $ \hS ->
              bracket (mallocArray (n * kUpper) :: IO (Ptr CFloat)) free $ \hU ->
                bracket (mallocArray (kUpper * n) :: IO (Ptr CFloat)) free $ \hV ->
                  bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hNsv ->
                    bracket (mallocArray kUpper :: IO (Ptr RocblasInt)) free $ \hIfail ->
                      bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA aOriginal

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                            bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                              bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                  bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdx
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            RocblasSrangeValue
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            2.0
                                            4.0
                                            1
                                            1
                                            dNsv
                                            dS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            dV
                                            (fromIntegral kUpper :: RocblasInt)
                                            dIfail
                                            dInfo
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        nsvVals <- peekArray 1 hNsv
                        sAll <- peekArray kUpper hS
                        uAll <- peekArray (n * kUpper) hU
                        vAll <- peekArray (kUpper * n) hV
                        ifailAll <- peekArray kUpper hIfail
                        infoVals <- peekArray 1 hInfo
                        let selected = case nsvVals of
                              [nsv] -> fromIntegral nsv
                              _ -> -1
                            sVals = take selected sAll
                            uVals = take (n * selected) uAll
                            vVals = extractLeadingRowsColMajor kUpper n selected vAll
                            ifailVals = take selected ifailAll
                            infoOk = case infoVals of
                              [infoVal] -> infoVal == 0
                              _ -> False
                            nsvOk = case nsvVals of
                              [nsv] -> nsv == 1
                              _ -> False
                            ifailOk = not (null ifailVals) && all (== 0) ifailVals
                            partial = matMulRightRowVector (matMulColMajorCFloat n selected selected uVals (diagColMajorCFloat sVals)) vVals
                            uGram = gramMatrixColMajorCFloat n selected uVals
                            vNorm = [CFloat (sum [unCFloat x * unCFloat x | x <- vVals])]
                        if infoOk
                            && nsvOk
                            && ifailOk
                            && approxVecWithTol 1.0e-3 sVals expectedS
                            && approxVecWithTol 1.0e-3 partial expectedPartial
                            && approxVecWithTol 1.0e-3 uGram identity1
                            && approxVecWithTol 1.0e-3 vNorm identity1
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDX value-range mismatch: nsv=" <> show nsvVals <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vNorm=" <> show vNorm <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVals)

rocsolverSgesvdxBatchedValueSmoke :: IO SmokeResult
rocsolverSgesvdxBatchedValueSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              kUpper = n
              ldv = kUpper
              strideSCount = kUpper
              strideUCount = n * kUpper
              strideVCount = ldv * n
              strideFCount = kUpper
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedNsv = [1, 2] :: [RocblasInt]
              expectedSingulars = [[CFloat 3], fmap CFloat [4, 2]]
              expectedPartials = [fmap CFloat [3, 0, 0, 0], fmap CFloat [4, 0, 0, 2]]
              expectedGrams = [[CFloat 1], fmap CFloat [1, 0, 0, 1]]
              matrixElems = n * n
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesNsv = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (batchCount * strideFCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              strideF = fromIntegral strideFCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNsv ->
                bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                  bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                    bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                      bracket (mallocArray (batchCount * strideFCount) :: IO (Ptr RocblasInt)) free $ \hIfail ->
                        bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                          pokeArray hAFlat (aBatch0 <> aBatch1)

                          bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                            bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                              bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                                bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                                  bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                    bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                      bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                        bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                          hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                          let DevicePtr pAFlat = dAFlat
                                              aPtrs = [pAFlat `plusPtr` (idx * matrixBytesInt) | idx <- [0 .. batchCount - 1]]
                                          pokeArray hAPtrs aPtrs
                                          hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs

                                          bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                            withRocblasHandle $ \handle -> do
                                              rocblasSetStream handle stream
                                              rocsolverSgesvdxBatched
                                                handle
                                                RocblasSvectSingular
                                                RocblasSvectSingular
                                                RocblasSrangeValue
                                                (fromIntegral n :: RocblasInt)
                                                (fromIntegral n :: RocblasInt)
                                                dAPtrs
                                                (fromIntegral n :: RocblasInt)
                                                1.5
                                                5.0
                                                1
                                                1
                                                dNsv
                                                dS
                                                strideS
                                                dU
                                                (fromIntegral n :: RocblasInt)
                                                strideU
                                                dV
                                                (fromIntegral ldv :: RocblasInt)
                                                strideV
                                                dIfail
                                                strideF
                                                dInfo
                                                batchCount'
                                              hipStreamSynchronize stream

                                          hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                          hipMemcpyD2H (HostPtr hS) dS bytesS
                                          hipMemcpyD2H (HostPtr hU) dU bytesU
                                          hipMemcpyD2H (HostPtr hV) dV bytesV
                                          hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                          hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                          nsvVals <- peekArray batchCount hNsv
                          sAll <- peekArray (batchCount * strideSCount) hS
                          uAll <- peekArray (batchCount * strideUCount) hU
                          vAll <- peekArray (batchCount * strideVCount) hV
                          ifailAll <- peekArray (batchCount * strideFCount) hIfail
                          infoVals <- peekArray batchCount hInfo
                          let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                              batchReport idx =
                                let nsvVal = nsvVals !! idx
                                    selected = fromIntegral nsvVal :: Int
                                    sVals = take selected (batchSlice strideSCount idx sAll)
                                    uVals = take (n * selected) (batchSlice strideUCount idx uAll)
                                    vVals = extractLeadingRowsColMajor ldv n selected (batchSlice strideVCount idx vAll)
                                    ifailVals = take selected (batchSlice strideFCount idx ifailAll)
                                    infoVal = infoVals !! idx
                                    us = matMulColMajorCFloat n selected selected uVals (diagColMajorCFloat sVals)
                                    partial = matMulColMajorCFloat n selected n us vVals
                                    uGram = gramMatrixColMajorCFloat n selected uVals
                                    vGram = rowGramMatrixColMajorCFloat selected n vVals
                                    ok = infoVal == 0
                                      && nsvVal == expectedNsv !! idx
                                      && all (== 0) ifailVals
                                      && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                      && approxVecWithTol 1.0e-3 partial (expectedPartials !! idx)
                                      && approxVecWithTol 1.0e-3 uGram (expectedGrams !! idx)
                                      && approxVecWithTol 1.0e-3 vGram (expectedGrams !! idx)
                                 in (ok, "batch=" <> show idx <> ", nsv=" <> show nsvVal <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVal)
                              reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                          if all fst reports
                            then pure SmokePassed
                            else fail ("rocSOLVER SGESVDX batched value-range mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdxBatchedSmoke :: IO SmokeResult
rocsolverSgesvdxBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              k = 1 :: Int
              ldv = k
              strideSCount = k
              strideUCount = n * k
              strideVCount = ldv * n
              strideFCount = n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [[CFloat 3], [CFloat 4]]
              expectedPartials = [fmap CFloat [3, 0, 0, 0], fmap CFloat [4, 0, 0, 0]]
              identity1 = [CFloat 1]
              matrixElems = n * n
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesNsv = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (batchCount * strideFCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              strideF = fromIntegral strideFCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNsv ->
                bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                  bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                    bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                      bracket (mallocArray (batchCount * strideFCount) :: IO (Ptr RocblasInt)) free $ \hIfail ->
                        bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                          pokeArray hAFlat (aBatch0 <> aBatch1)

                          bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                            bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                              bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                                bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                                  bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                    bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                      bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                        bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                          hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                          let DevicePtr pAFlat = dAFlat
                                              aPtrs = [pAFlat `plusPtr` (idx * matrixBytesInt) | idx <- [0 .. batchCount - 1]]
                                          pokeArray hAPtrs aPtrs
                                          hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs

                                          bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                            withRocblasHandle $ \handle -> do
                                              rocblasSetStream handle stream
                                              rocsolverSgesvdxBatched
                                                handle
                                                RocblasSvectSingular
                                                RocblasSvectSingular
                                                RocblasSrangeIndex
                                                (fromIntegral n :: RocblasInt)
                                                (fromIntegral n :: RocblasInt)
                                                dAPtrs
                                                (fromIntegral n :: RocblasInt)
                                                0.0
                                                0.0
                                                1
                                                1
                                                dNsv
                                                dS
                                                strideS
                                                dU
                                                (fromIntegral n :: RocblasInt)
                                                strideU
                                                dV
                                                (fromIntegral ldv :: RocblasInt)
                                                strideV
                                                dIfail
                                                strideF
                                                dInfo
                                                batchCount'
                                              hipStreamSynchronize stream

                                          hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                          hipMemcpyD2H (HostPtr hS) dS bytesS
                                          hipMemcpyD2H (HostPtr hU) dU bytesU
                                          hipMemcpyD2H (HostPtr hV) dV bytesV
                                          hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                          hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                          nsvVals <- peekArray batchCount hNsv
                          sAll <- peekArray (batchCount * strideSCount) hS
                          uAll <- peekArray (batchCount * strideUCount) hU
                          vAll <- peekArray (batchCount * strideVCount) hV
                          ifailAll <- peekArray (batchCount * strideFCount) hIfail
                          infoVals <- peekArray batchCount hInfo
                          let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                              batchReport idx =
                                let nsvVal = nsvVals !! idx
                                    selected = fromIntegral nsvVal :: Int
                                    sVals = take selected (batchSlice strideSCount idx sAll)
                                    uVals = take (n * selected) (batchSlice strideUCount idx uAll)
                                    vVals = extractLeadingRowsColMajor ldv n selected (batchSlice strideVCount idx vAll)
                                    ifailVals = take selected (batchSlice strideFCount idx ifailAll)
                                    infoVal = infoVals !! idx
                                    partial = matMulRightRowVector (matMulColMajorCFloat n selected selected uVals (diagColMajorCFloat sVals)) vVals
                                    uGram = gramMatrixColMajorCFloat n selected uVals
                                    vNorm = [CFloat (sum [unCFloat x * unCFloat x | x <- vVals])]
                                    ok = infoVal == 0
                                      && nsvVal == 1
                                      && all (== 0) ifailVals
                                      && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                      && approxVecWithTol 1.0e-3 partial (expectedPartials !! idx)
                                      && approxVecWithTol 1.0e-3 uGram identity1
                                      && approxVecWithTol 1.0e-3 vNorm identity1
                                 in (ok, "batch=" <> show idx <> ", nsv=" <> show nsvVal <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vNorm=" <> show vNorm <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVal)
                              reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                          if all fst reports
                            then pure SmokePassed
                            else fail ("rocSOLVER SGESVDX batched mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdxStridedBatchedValueSmoke :: IO SmokeResult
rocsolverSgesvdxStridedBatchedValueSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              kUpper = n
              ldv = kUpper
              strideACount = n * n
              strideSCount = kUpper
              strideUCount = n * kUpper
              strideVCount = ldv * n
              strideFCount = kUpper
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedNsv = [1, 2] :: [RocblasInt]
              expectedSingulars = [[CFloat 3], fmap CFloat [4, 2]]
              expectedPartials = [fmap CFloat [3, 0, 0, 0], fmap CFloat [4, 0, 0, 2]]
              expectedGrams = [[CFloat 1], fmap CFloat [1, 0, 0, 1]]
              bytesA = fromIntegral (batchCount * strideACount * sizeOf (undefined :: CFloat)) :: CSize
              bytesNsv = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (batchCount * strideFCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideA = fromIntegral strideACount :: RocblasStride
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              strideF = fromIntegral strideFCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * strideACount) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNsv ->
              bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                  bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                    bracket (mallocArray (batchCount * strideFCount) :: IO (Ptr RocblasInt)) free $ \hIfail ->
                      bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA (aBatch0 <> aBatch1)

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                            bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                              bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                  bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdxStridedBatched
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            RocblasSrangeValue
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            strideA
                                            1.5
                                            5.0
                                            1
                                            1
                                            dNsv
                                            dS
                                            strideS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            strideU
                                            dV
                                            (fromIntegral ldv :: RocblasInt)
                                            strideV
                                            dIfail
                                            strideF
                                            dInfo
                                            batchCount'
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        nsvVals <- peekArray batchCount hNsv
                        sAll <- peekArray (batchCount * strideSCount) hS
                        uAll <- peekArray (batchCount * strideUCount) hU
                        vAll <- peekArray (batchCount * strideVCount) hV
                        ifailAll <- peekArray (batchCount * strideFCount) hIfail
                        infoVals <- peekArray batchCount hInfo
                        let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                            batchReport idx =
                              let nsvVal = nsvVals !! idx
                                  selected = fromIntegral nsvVal :: Int
                                  sVals = take selected (batchSlice strideSCount idx sAll)
                                  uVals = take (n * selected) (batchSlice strideUCount idx uAll)
                                  vVals = extractLeadingRowsColMajor ldv n selected (batchSlice strideVCount idx vAll)
                                  ifailVals = take selected (batchSlice strideFCount idx ifailAll)
                                  infoVal = infoVals !! idx
                                  us = matMulColMajorCFloat n selected selected uVals (diagColMajorCFloat sVals)
                                  partial = matMulColMajorCFloat n selected n us vVals
                                  uGram = gramMatrixColMajorCFloat n selected uVals
                                  vGram = rowGramMatrixColMajorCFloat selected n vVals
                                  ok = infoVal == 0
                                    && nsvVal == expectedNsv !! idx
                                    && all (== 0) ifailVals
                                    && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                    && approxVecWithTol 1.0e-3 partial (expectedPartials !! idx)
                                    && approxVecWithTol 1.0e-3 uGram (expectedGrams !! idx)
                                    && approxVecWithTol 1.0e-3 vGram (expectedGrams !! idx)
                               in (ok, "batch=" <> show idx <> ", nsv=" <> show nsvVal <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vGram=" <> show vGram <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVal)
                            reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                        if all fst reports
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDX strided-batched value-range mismatch: " <> intercalate "; " (map snd reports))

rocsolverSgesvdxStridedBatchedSmoke :: IO SmokeResult
rocsolverSgesvdxStridedBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocsolverSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              n = 2 :: Int
              k = 1 :: Int
              ldv = k
              strideACount = n * n
              strideSCount = k
              strideUCount = n * k
              strideVCount = ldv * n
              strideFCount = n
              aBatch0 = fmap CFloat [3, 0, 0, 1]
              aBatch1 = fmap CFloat [4, 0, 0, 2]
              expectedSingulars = [[CFloat 3], [CFloat 4]]
              expectedPartials = [fmap CFloat [3, 0, 0, 0], fmap CFloat [4, 0, 0, 0]]
              identity1 = [CFloat 1]
              bytesA = fromIntegral (batchCount * strideACount * sizeOf (undefined :: CFloat)) :: CSize
              bytesNsv = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesS = fromIntegral (batchCount * strideSCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesU = fromIntegral (batchCount * strideUCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesV = fromIntegral (batchCount * strideVCount * sizeOf (undefined :: CFloat)) :: CSize
              bytesIfail = fromIntegral (batchCount * strideFCount * sizeOf (undefined :: RocblasInt)) :: CSize
              bytesInfo = fromIntegral (batchCount * sizeOf (undefined :: RocblasInt)) :: CSize
              strideA = fromIntegral strideACount :: RocblasStride
              strideS = fromIntegral strideSCount :: RocblasStride
              strideU = fromIntegral strideUCount :: RocblasStride
              strideV = fromIntegral strideVCount :: RocblasStride
              strideF = fromIntegral strideFCount :: RocblasStride
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * strideACount) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hNsv ->
              bracket (mallocArray (batchCount * strideSCount) :: IO (Ptr CFloat)) free $ \hS ->
                bracket (mallocArray (batchCount * strideUCount) :: IO (Ptr CFloat)) free $ \hU ->
                  bracket (mallocArray (batchCount * strideVCount) :: IO (Ptr CFloat)) free $ \hV ->
                    bracket (mallocArray (batchCount * strideFCount) :: IO (Ptr RocblasInt)) free $ \hIfail ->
                      bracket (mallocArray batchCount :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                        pokeArray hA (aBatch0 <> aBatch1)

                        bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                          bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                            bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                              bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                                bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                                  bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                    bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                      hipMemcpyH2D dA (HostPtr hA) bytesA

                                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                        withRocblasHandle $ \handle -> do
                                          rocblasSetStream handle stream
                                          rocsolverSgesvdxStridedBatched
                                            handle
                                            RocblasSvectSingular
                                            RocblasSvectSingular
                                            RocblasSrangeIndex
                                            (fromIntegral n :: RocblasInt)
                                            (fromIntegral n :: RocblasInt)
                                            dA
                                            (fromIntegral n :: RocblasInt)
                                            strideA
                                            0.0
                                            0.0
                                            1
                                            1
                                            dNsv
                                            dS
                                            strideS
                                            dU
                                            (fromIntegral n :: RocblasInt)
                                            strideU
                                            dV
                                            (fromIntegral ldv :: RocblasInt)
                                            strideV
                                            dIfail
                                            strideF
                                            dInfo
                                            batchCount'
                                          hipStreamSynchronize stream

                                      hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                      hipMemcpyD2H (HostPtr hS) dS bytesS
                                      hipMemcpyD2H (HostPtr hU) dU bytesU
                                      hipMemcpyD2H (HostPtr hV) dV bytesV
                                      hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                      hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                        nsvVals <- peekArray batchCount hNsv
                        sAll <- peekArray (batchCount * strideSCount) hS
                        uAll <- peekArray (batchCount * strideUCount) hU
                        vAll <- peekArray (batchCount * strideVCount) hV
                        ifailAll <- peekArray (batchCount * strideFCount) hIfail
                        infoVals <- peekArray batchCount hInfo
                        let batchSlice stride idx vals = take stride (drop (idx * stride) vals)
                            batchReport idx =
                              let nsvVal = nsvVals !! idx
                                  selected = fromIntegral nsvVal :: Int
                                  sVals = take selected (batchSlice strideSCount idx sAll)
                                  uVals = take (n * selected) (batchSlice strideUCount idx uAll)
                                  vVals = extractLeadingRowsColMajor ldv n selected (batchSlice strideVCount idx vAll)
                                  ifailVals = take selected (batchSlice strideFCount idx ifailAll)
                                  infoVal = infoVals !! idx
                                  partial = matMulRightRowVector (matMulColMajorCFloat n selected selected uVals (diagColMajorCFloat sVals)) vVals
                                  uGram = gramMatrixColMajorCFloat n selected uVals
                                  vNorm = [CFloat (sum [unCFloat x * unCFloat x | x <- vVals])]
                                  ok = infoVal == 0
                                    && nsvVal == 1
                                    && all (== 0) ifailVals
                                    && approxVecWithTol 1.0e-3 sVals (expectedSingulars !! idx)
                                    && approxVecWithTol 1.0e-3 partial (expectedPartials !! idx)
                                    && approxVecWithTol 1.0e-3 uGram identity1
                                    && approxVecWithTol 1.0e-3 vNorm identity1
                               in (ok, "batch=" <> show idx <> ", nsv=" <> show nsvVal <> ", s=" <> show sVals <> ", partial=" <> show partial <> ", uGram=" <> show uGram <> ", vNorm=" <> show vNorm <> ", ifail=" <> show ifailVals <> ", info=" <> show infoVal)
                            reports = [batchReport idx | idx <- [0 .. batchCount - 1]]
                        if all fst reports
                          then pure SmokePassed
                          else fail ("rocSOLVER SGESVDX strided-batched mismatch: " <> intercalate "; " (map snd reports))

rocblasSmoke :: IO SmokeResult
rocblasSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 16 :: Int
              alpha = 2.0 :: Float
              xVals = [1 .. fromIntegral n] :: [Float]
              yVals = [100, 101 ..] :: [Float]
              xC = fmap CFloat xVals
              yC = take n (fmap CFloat yVals)
              expected = zipWith (\(CFloat x) (CFloat y) -> CFloat (alpha * x + y)) xC yC
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray n) free $ \hX ->
            bracket (mallocArray n) free $ \hY ->
              bracket (mallocArray n) free $ \hOut -> do
                pokeArray hX xC
                pokeArray hY yC

                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                  bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
                    hipMemcpyH2D dX (HostPtr hX) bytes
                    hipMemcpyH2D dY (HostPtr hY) bytes

                    bracket hipStreamCreate hipStreamDestroy $ \stream ->
                      withRocblasHandle $ \handle -> do
                        rocblasSetStream handle stream
                        rocblasSaxpy handle (fromIntegral n :: RocblasInt) alpha dX 1 dY 1
                        hipStreamSynchronize stream

                    hipMemcpyD2H (HostPtr hOut) dY bytes

                out <- peekArray n hOut
                if approxVec out expected
                  then pure SmokePassed
                  else fail ("rocBLAS mismatch: expected=" <> show expected <> ", got=" <> show out)

rocblasBlas1CoreSmoke :: IO SmokeResult
rocblasBlas1CoreSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let n = 3 :: Int
              xVals = fmap CFloat [1, 2, 3]
              yVals = fmap CFloat [4, 5, 6]
              zExpected = fmap CFloat [2, 4, 6]
              bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
              expectedDot = 64.0 :: Float
              expectedAsum = 12.0 :: Float
              expectedNrm2 = sqrt 56.0 :: Float

          bracket (mallocArray n) free $ \hX ->
            bracket (mallocArray n) free $ \hY ->
              bracket (mallocArray n) free $ \hZ -> do
                pokeArray hX xVals
                pokeArray hY yVals
                pokeArray hZ (replicate n (CFloat 0))

                bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                  bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dY ->
                    bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dZ -> do
                      hipMemcpyH2D dX (HostPtr hX) bytes
                      hipMemcpyH2D dY (HostPtr hY) bytes
                      hipMemcpyH2D dZ (HostPtr hZ) bytes

                      (dotVal, asumVal, nrm2Val) <-
                        bracket hipStreamCreate hipStreamDestroy $ \stream ->
                          withRocblasHandle $ \handle -> do
                            rocblasSetStream handle stream
                            rocblasScopy handle (fromIntegral n :: RocblasInt) dX 1 dZ 1
                            rocblasSscal handle (fromIntegral n :: RocblasInt) 2.0 dZ 1
                            dotVal <- rocblasSdot handle (fromIntegral n :: RocblasInt) dZ 1 dY 1
                            asumVal <- rocblasSasum handle (fromIntegral n :: RocblasInt) dZ 1
                            nrm2Val <- rocblasSnrm2 handle (fromIntegral n :: RocblasInt) dZ 1
                            hipStreamSynchronize stream
                            pure (dotVal, asumVal, nrm2Val)

                      hipMemcpyD2H (HostPtr hZ) dZ bytes
                      zOut <- peekArray n hZ
                      if approxVecWithTol 1.0e-3 zOut zExpected
                        && abs (dotVal - expectedDot) <= 1.0e-3
                        && abs (asumVal - expectedAsum) <= 1.0e-3
                        && abs (nrm2Val - expectedNrm2) <= 1.0e-3
                        then pure SmokePassed
                        else fail ("rocBLAS BLAS1 core mismatch: z=" <> show zOut <> ", dot=" <> show dotVal <> ", asum=" <> show asumVal <> ", nrm2=" <> show nrm2Val)

rocblasGemvBatchedSmoke :: IO SmokeResult
rocblasGemvBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              m = 2 :: Int
              n = 2 :: Int
              matrixElems = m * n
              vecElems = n
              outElems = m
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              vecBytesInt = vecElems * sizeOf (undefined :: CFloat)
              outBytesInt = outElems * sizeOf (undefined :: CFloat)
              a0 = fmap CFloat [1, 3, 2, 4]
              a1 = fmap CFloat [2, 0, 0, 3]
              x0 = fmap CFloat [5, 6]
              x1 = fmap CFloat [7, 8]
              yExpected = fmap CFloat [17, 39, 14, 24]
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesXFlat = fromIntegral (batchCount * vecBytesInt) :: CSize
              bytesYFlat = fromIntegral (batchCount * outBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesXPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesYPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray (batchCount * vecElems) :: IO (Ptr CFloat)) free $ \hXFlat ->
              bracket (mallocArray (batchCount * outElems) :: IO (Ptr CFloat)) free $ \hYFlat ->
                bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
                  bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hXPtrs ->
                    bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hYPtrs -> do
                      pokeArray hAFlat (a0 <> a1)
                      pokeArray hXFlat (x0 <> x1)
                      pokeArray hYFlat (replicate (batchCount * outElems) (CFloat 0))

                      bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                        bracket (hipMallocBytes bytesXFlat :: IO (DevicePtr CFloat)) hipFree $ \dXFlat ->
                          bracket (hipMallocBytes bytesYFlat :: IO (DevicePtr CFloat)) hipFree $ \dYFlat ->
                            bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                              bracket (hipMallocBytes bytesXPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dXPtrs ->
                                bracket (hipMallocBytes bytesYPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dYPtrs -> do
                                  hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                  hipMemcpyH2D dXFlat (HostPtr hXFlat) bytesXFlat
                                  hipMemcpyH2D dYFlat (HostPtr hYFlat) bytesYFlat
                                  let DevicePtr pAFlat = dAFlat
                                      DevicePtr pXFlat = dXFlat
                                      DevicePtr pYFlat = dYFlat
                                  pokeArray hAPtrs [pAFlat, pAFlat `plusPtr` matrixBytesInt]
                                  pokeArray hXPtrs [pXFlat, pXFlat `plusPtr` vecBytesInt]
                                  pokeArray hYPtrs [pYFlat, pYFlat `plusPtr` outBytesInt]
                                  hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs
                                  hipMemcpyH2D dXPtrs (HostPtr hXPtrs) bytesXPtrs
                                  hipMemcpyH2D dYPtrs (HostPtr hYPtrs) bytesYPtrs

                                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                    withRocblasHandle $ \handle -> do
                                      rocblasSetStream handle stream
                                      rocblasSgemvBatched
                                        handle
                                        RocblasOperationNone
                                        (fromIntegral m :: RocblasInt)
                                        (fromIntegral n :: RocblasInt)
                                        1.0
                                        dAPtrs
                                        (fromIntegral m :: RocblasInt)
                                        dXPtrs
                                        1
                                        0.0
                                        dYPtrs
                                        1
                                        batchCount'
                                      hipStreamSynchronize stream

                                  hipMemcpyD2H (HostPtr hYFlat) dYFlat bytesYFlat
                                  yOut <- peekArray (batchCount * outElems) hYFlat
                                  if approxVecWithTol 1.0e-3 yOut yExpected
                                    then pure SmokePassed
                                    else fail ("rocBLAS SGEMV batched mismatch: expected=" <> show yExpected <> ", got=" <> show yOut)

rocblasGemvStridedBatchedSmoke :: IO SmokeResult
rocblasGemvStridedBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              m = 2 :: Int
              n = 2 :: Int
              strideA = fromIntegral (m * n) :: RocblasStride
              strideX = fromIntegral n :: RocblasStride
              strideY = fromIntegral m :: RocblasStride
              aVals = fmap CFloat [1, 3, 2, 4, 2, 0, 0, 3]
              xVals = fmap CFloat [5, 6, 7, 8]
              yExpected = fmap CFloat [17, 39, 14, 24]
              bytesA = fromIntegral (batchCount * m * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesX = fromIntegral (batchCount * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesY = fromIntegral (batchCount * m * sizeOf (undefined :: CFloat)) :: CSize
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * m * n) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray (batchCount * n) :: IO (Ptr CFloat)) free $ \hX ->
              bracket (mallocArray (batchCount * m) :: IO (Ptr CFloat)) free $ \hY -> do
                pokeArray hA aVals
                pokeArray hX xVals
                pokeArray hY (replicate (batchCount * m) (CFloat 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesX :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                    bracket (hipMallocBytes bytesY :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dX (HostPtr hX) bytesX
                      hipMemcpyH2D dY (HostPtr hY) bytesY

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasSgemvStridedBatched
                            handle
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            strideA
                            dX
                            1
                            strideX
                            0.0
                            dY
                            1
                            strideY
                            batchCount'
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hY) dY bytesY
                      yOut <- peekArray (batchCount * m) hY
                      if approxVecWithTol 1.0e-3 yOut yExpected
                        then pure SmokePassed
                        else fail ("rocBLAS SGEMV strided batched mismatch: expected=" <> show yExpected <> ", got=" <> show yOut)

rocblasGemmBatchedSmoke :: IO SmokeResult
rocblasGemmBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              m = 2 :: Int
              n = 2 :: Int
              k = 2 :: Int
              matrixElems = m * n
              matrixBytesInt = matrixElems * sizeOf (undefined :: CFloat)
              a0 = fmap CFloat [1, 3, 2, 4]
              b0 = fmap CFloat [5, 7, 6, 8]
              c0 = fmap CFloat [19, 43, 22, 50]
              a1 = fmap CFloat [2, 1, 0, 3]
              b1 = fmap CFloat [1, 2, 4, 5]
              c1 = fmap CFloat [2, 7, 8, 19]
              cExpected = c0 <> c1
              bytesAFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesBFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesCFlat = fromIntegral (batchCount * matrixBytesInt) :: CSize
              bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesBPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              bytesCPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hAFlat ->
            bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hBFlat ->
              bracket (mallocArray (batchCount * matrixElems) :: IO (Ptr CFloat)) free $ \hCFlat ->
                bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
                  bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hBPtrs ->
                    bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hCPtrs -> do
                      pokeArray hAFlat (a0 <> a1)
                      pokeArray hBFlat (b0 <> b1)
                      pokeArray hCFlat (replicate (batchCount * matrixElems) (CFloat 0))

                      bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                        bracket (hipMallocBytes bytesBFlat :: IO (DevicePtr CFloat)) hipFree $ \dBFlat ->
                          bracket (hipMallocBytes bytesCFlat :: IO (DevicePtr CFloat)) hipFree $ \dCFlat ->
                            bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                              bracket (hipMallocBytes bytesBPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dBPtrs ->
                                bracket (hipMallocBytes bytesCPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dCPtrs -> do
                                  hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                                  hipMemcpyH2D dBFlat (HostPtr hBFlat) bytesBFlat
                                  hipMemcpyH2D dCFlat (HostPtr hCFlat) bytesCFlat
                                  let DevicePtr pAFlat = dAFlat
                                      DevicePtr pBFlat = dBFlat
                                      DevicePtr pCFlat = dCFlat
                                  pokeArray hAPtrs [pAFlat, pAFlat `plusPtr` matrixBytesInt]
                                  pokeArray hBPtrs [pBFlat, pBFlat `plusPtr` matrixBytesInt]
                                  pokeArray hCPtrs [pCFlat, pCFlat `plusPtr` matrixBytesInt]
                                  hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs
                                  hipMemcpyH2D dBPtrs (HostPtr hBPtrs) bytesBPtrs
                                  hipMemcpyH2D dCPtrs (HostPtr hCPtrs) bytesCPtrs

                                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                    withRocblasHandle $ \handle -> do
                                      rocblasSetStream handle stream
                                      rocblasSgemmBatched
                                        handle
                                        RocblasOperationNone
                                        RocblasOperationNone
                                        (fromIntegral m :: RocblasInt)
                                        (fromIntegral n :: RocblasInt)
                                        (fromIntegral k :: RocblasInt)
                                        1.0
                                        dAPtrs
                                        (fromIntegral m :: RocblasInt)
                                        dBPtrs
                                        (fromIntegral k :: RocblasInt)
                                        0.0
                                        dCPtrs
                                        (fromIntegral m :: RocblasInt)
                                        batchCount'
                                      hipStreamSynchronize stream

                                  hipMemcpyD2H (HostPtr hCFlat) dCFlat bytesCFlat
                                  cOut <- peekArray (batchCount * matrixElems) hCFlat
                                  if approxVecWithTol 1.0e-3 cOut cExpected
                                    then pure SmokePassed
                                    else fail ("rocBLAS SGEMM batched mismatch: expected=" <> show cExpected <> ", got=" <> show cOut)

rocblasGemmStridedBatchedSmoke :: IO SmokeResult
rocblasGemmStridedBatchedSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let batchCount = 2 :: Int
              m = 2 :: Int
              n = 2 :: Int
              k = 2 :: Int
              strideA = fromIntegral (m * k) :: RocblasStride
              strideB = fromIntegral (k * n) :: RocblasStride
              strideC = fromIntegral (m * n) :: RocblasStride
              aVals = fmap CFloat [1, 3, 2, 4, 2, 1, 0, 3]
              bVals = fmap CFloat [5, 7, 6, 8, 1, 2, 4, 5]
              cExpected = fmap CFloat [19, 43, 22, 50, 2, 7, 8, 19]
              bytesA = fromIntegral (batchCount * m * k * sizeOf (undefined :: CFloat)) :: CSize
              bytesB = fromIntegral (batchCount * k * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesC = fromIntegral (batchCount * m * n * sizeOf (undefined :: CFloat)) :: CSize
              batchCount' = fromIntegral batchCount :: RocblasInt

          bracket (mallocArray (batchCount * m * k) :: IO (Ptr CFloat)) free $ \hA ->
            bracket (mallocArray (batchCount * k * n) :: IO (Ptr CFloat)) free $ \hB ->
              bracket (mallocArray (batchCount * m * n) :: IO (Ptr CFloat)) free $ \hC -> do
                pokeArray hA aVals
                pokeArray hB bVals
                pokeArray hC (replicate (batchCount * m * n) (CFloat 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesB :: IO (DevicePtr CFloat)) hipFree $ \dB ->
                    bracket (hipMallocBytes bytesC :: IO (DevicePtr CFloat)) hipFree $ \dC -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dB (HostPtr hB) bytesB
                      hipMemcpyH2D dC (HostPtr hC) bytesC

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasSgemmStridedBatched
                            handle
                            RocblasOperationNone
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            (fromIntegral k :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            strideA
                            dB
                            (fromIntegral k :: RocblasInt)
                            strideB
                            0.0
                            dC
                            (fromIntegral m :: RocblasInt)
                            strideC
                            batchCount'
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hC) dC bytesC
                      cOut <- peekArray (batchCount * m * n) hC
                      if approxVecWithTol 1.0e-3 cOut cExpected
                        then pure SmokePassed
                        else fail ("rocBLAS SGEMM strided batched mismatch: expected=" <> show cExpected <> ", got=" <> show cOut)

rocblasGemmSmoke :: IO SmokeResult
rocblasGemmSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 2 :: Int
              n = 2 :: Int
              k = 2 :: Int
              aVals = fmap CFloat [1, 3, 2, 4]
              bVals = fmap CFloat [5, 7, 6, 8]
              expected = fmap CFloat [19, 43, 22, 50]
              bytesA = fromIntegral (m * k * sizeOf (undefined :: CFloat)) :: CSize
              bytesB = fromIntegral (k * n * sizeOf (undefined :: CFloat)) :: CSize
              bytesC = fromIntegral (m * n * sizeOf (undefined :: CFloat)) :: CSize

          bracket (mallocArray (m * k)) free $ \hA ->
            bracket (mallocArray (k * n)) free $ \hB ->
              bracket (mallocArray (m * n)) free $ \hC -> do
                pokeArray hA aVals
                pokeArray hB bVals
                pokeArray hC (replicate (m * n) (CFloat 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesB :: IO (DevicePtr CFloat)) hipFree $ \dB ->
                    bracket (hipMallocBytes bytesC :: IO (DevicePtr CFloat)) hipFree $ \dC -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dB (HostPtr hB) bytesB
                      hipMemcpyH2D dC (HostPtr hC) bytesC

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasSgemm
                            handle
                            RocblasOperationNone
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            (fromIntegral k :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            dB
                            (fromIntegral k :: RocblasInt)
                            0.0
                            dC
                            (fromIntegral m :: RocblasInt)
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hC) dC bytesC

                out <- peekArray (m * n) hC
                if approxVec out expected
                  then pure SmokePassed
                  else fail ("rocBLAS SGEMM mismatch: expected=" <> show expected <> ", got=" <> show out)

rocblasDGemmSmoke :: IO SmokeResult
rocblasDGemmSmoke = do
  gpuReady <- requireGpu
  case gpuReady of
    Just skipMsg -> pure (SmokeSkipped skipMsg)
    Nothing -> do
      skipReason <- rocblasSkipReason
      case skipReason of
        Just reason -> pure (SmokeSkipped reason)
        Nothing -> do
          let m = 2 :: Int
              n = 2 :: Int
              k = 2 :: Int
              aVals = fmap CDouble [1, 3, 2, 4]
              bVals = fmap CDouble [5, 7, 6, 8]
              expected = fmap CDouble [19, 43, 22, 50]
              bytesA = fromIntegral (m * k * sizeOf (undefined :: CDouble)) :: CSize
              bytesB = fromIntegral (k * n * sizeOf (undefined :: CDouble)) :: CSize
              bytesC = fromIntegral (m * n * sizeOf (undefined :: CDouble)) :: CSize

          bracket (mallocArray (m * k)) free $ \hA ->
            bracket (mallocArray (k * n)) free $ \hB ->
              bracket (mallocArray (m * n)) free $ \hC -> do
                pokeArray hA aVals
                pokeArray hB bVals
                pokeArray hC (replicate (m * n) (CDouble 0))

                bracket (hipMallocBytes bytesA :: IO (DevicePtr CDouble)) hipFree $ \dA ->
                  bracket (hipMallocBytes bytesB :: IO (DevicePtr CDouble)) hipFree $ \dB ->
                    bracket (hipMallocBytes bytesC :: IO (DevicePtr CDouble)) hipFree $ \dC -> do
                      hipMemcpyH2D dA (HostPtr hA) bytesA
                      hipMemcpyH2D dB (HostPtr hB) bytesB
                      hipMemcpyH2D dC (HostPtr hC) bytesC

                      bracket hipStreamCreate hipStreamDestroy $ \stream ->
                        withRocblasHandle $ \handle -> do
                          rocblasSetStream handle stream
                          rocblasDgemm
                            handle
                            RocblasOperationNone
                            RocblasOperationNone
                            (fromIntegral m :: RocblasInt)
                            (fromIntegral n :: RocblasInt)
                            (fromIntegral k :: RocblasInt)
                            1.0
                            dA
                            (fromIntegral m :: RocblasInt)
                            dB
                            (fromIntegral k :: RocblasInt)
                            0.0
                            dC
                            (fromIntegral m :: RocblasInt)
                          hipStreamSynchronize stream

                      hipMemcpyD2H (HostPtr hC) dC bytesC

                out <- peekArray (m * n) hC
                if approxDVec out expected
                  then pure SmokePassed
                  else fail ("rocBLAS DGEMM mismatch: expected=" <> show expected <> ", got=" <> show out)

requireGpu :: IO (Maybe String)
requireGpu = do
  count <- hipGetDeviceCount
  pure $ if count <= 0 then Just "no HIP devices reported by runtime" else Nothing

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys =
  length xs == length ys
    && and (zipWith approxCFloat xs ys)

approxVecWithTol :: Float -> [CFloat] -> [CFloat] -> Bool
approxVecWithTol eps xs ys =
  length xs == length ys
    && and (zipWith (approxCFloatWithTol eps) xs ys)

approxCFloat :: CFloat -> CFloat -> Bool
approxCFloat = approxCFloatWithTol 1.0e-4

approxCFloatWithTol :: Float -> CFloat -> CFloat -> Bool
approxCFloatWithTol eps (CFloat a) (CFloat b) = abs (a - b) <= eps

approxDVec :: [CDouble] -> [CDouble] -> Bool
approxDVec xs ys =
  length xs == length ys
    && and (zipWith approxCDouble xs ys)

approxCDouble :: CDouble -> CDouble -> Bool
approxCDouble (CDouble a) (CDouble b) = abs (a - b) <= 1.0e-10

approxComplexVec :: [Complex Float] -> [Complex Float] -> Bool
approxComplexVec xs ys =
  length xs == length ys
    && and (zipWith approxComplex xs ys)

approxComplex :: Complex Float -> Complex Float -> Bool
approxComplex (ar :+ ai) (br :+ bi) = abs (ar - br) <= eps && abs (ai - bi) <= eps
  where
    eps = 1.0e-2

extractThinRColMajor :: Int -> Int -> [CFloat] -> [CFloat]
extractThinRColMajor m n vals =
  [ if row <= col then indexColMajor m vals row col else CFloat 0
  | col <- [0 .. k - 1]
  , row <- [0 .. k - 1]
  ]
  where
    k = min m n

matMulColMajorCFloat :: Int -> Int -> Int -> [CFloat] -> [CFloat] -> [CFloat]
matMulColMajorCFloat m k n a b =
  [ CFloat (sum [unCFloat (indexColMajor m a row t) * unCFloat (indexColMajor k b t col) | t <- [0 .. k - 1]])
  | col <- [0 .. n - 1]
  , row <- [0 .. m - 1]
  ]

gramMatrixColMajorCFloat :: Int -> Int -> [CFloat] -> [CFloat]
gramMatrixColMajorCFloat m n q =
  [ CFloat (sum [unCFloat (indexColMajor m q row i) * unCFloat (indexColMajor m q row j) | row <- [0 .. m - 1]])
  | j <- [0 .. n - 1]
  , i <- [0 .. n - 1]
  ]

diagColMajorCFloat :: [CFloat] -> [CFloat]
diagColMajorCFloat vals =
  [ if row == col then vals !! row else CFloat 0
  | col <- [0 .. n - 1]
  , row <- [0 .. n - 1]
  ]
  where
    n = length vals

matMulRightRowVector :: [CFloat] -> [CFloat] -> [CFloat]
matMulRightRowVector left right =
  [ CFloat (unCFloat x * unCFloat y)
  | y <- right
  , x <- left
  ]

rowGramMatrixColMajorCFloat :: Int -> Int -> [CFloat] -> [CFloat]
rowGramMatrixColMajorCFloat rows cols vals =
  [ CFloat (sum [unCFloat (indexColMajor rows vals i col) * unCFloat (indexColMajor rows vals j col) | col <- [0 .. cols - 1]])
  | j <- [0 .. rows - 1]
  , i <- [0 .. rows - 1]
  ]

extractLeadingRowsColMajor :: Int -> Int -> Int -> [a] -> [a]
extractLeadingRowsColMajor ldRows cols usedRows vals =
  [ indexColMajor ldRows vals row col
  | col <- [0 .. cols - 1]
  , row <- [0 .. usedRows - 1]
  ]

indexColMajor :: Int -> [a] -> Int -> Int -> a
indexColMajor rows vals row col = vals !! (row + col * rows)

unCFloat :: CFloat -> Float
unCFloat (CFloat x) = x

rocblasSkipReason :: IO (Maybe String)
rocblasSkipReason = do
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  pure $
    if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
      then Just "gfx1103 detected; set HSA_OVERRIDE_GFX_VERSION=11.0.0 to run rocBLAS on this install"
      else Nothing

rocrandSkipReason :: IO (Maybe String)
rocrandSkipReason = do
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  pure $
    if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
      then Just "gfx1103 detected; set HSA_OVERRIDE_GFX_VERSION=11.0.0 to run rocRAND on this install"
      else Nothing

rocsparseSkipReason :: IO (Maybe String)
rocsparseSkipReason = do
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  pure $
    if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
      then Just "gfx1103 detected; set HSA_OVERRIDE_GFX_VERSION=11.0.0 to run rocSPARSE on this install"
      else Nothing

rocsolverSkipReason :: IO (Maybe String)
rocsolverSkipReason = do
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  pure $
    if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
      then Just "gfx1103 detected; set HSA_OVERRIDE_GFX_VERSION=11.0.0 to run rocSOLVER on this install"
      else Nothing

detectCurrentGpuArch :: IO String
detectCurrentGpuArch = do
  archName <- hipGetCurrentDeviceGcnArchName
  if "gfx" `isPrefixOf` archName
    then pure archName
    else do
      archs <- discoverGpuArchs
      pure (case archs of
        x : _ -> x
        [] -> archName)

discoverGpuArchs :: IO [String]
discoverGpuArchs = do
  result <- try (readProcess "rocminfo" [] "") :: IO (Either SomeException String)
  pure $ case result of
    Left _ -> []
    Right out ->
      [ name
      | line <- lines out
      , let trimmed = dropWhile isSpace line
      , Just name <- [extractName trimmed]
      , "gfx" `isPrefixOf` name
      ]
  where
    extractName :: String -> Maybe String
    extractName line =
      case break (== ':') line of
        ("Name", ':' : rest) -> Just (dropWhile isSpace rest)
        _ -> Nothing

sanitize :: String -> String
sanitize = map (\c -> if c == '\n' then ' ' else c)
