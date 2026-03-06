{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (forM)
import Data.Char (isSpace)
import Data.Complex (Complex((:+)))
import Data.List (isPrefixOf)
import Foreign.C.Types (CDouble(..), CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure, exitSuccess)
import System.Process (readProcess)

import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..), PinnedHostPtr(..))
import ROCm.HIP
  ( hipEventCreate
  , hipEventDestroy
  , hipEventElapsedTime
  , hipEventQuery
  , hipEventRecord
  , hipEventSynchronize
  , hipFree
  , hipDeviceSynchronize
  , hipGetCurrentDeviceGcnArchName
  , hipGetDeviceCount
  , hipHostFree
  , hipHostMallocBytes
  , hipHostMallocBytesWithFlags
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyD2HAsync
  , hipMemcpyH2D
  , hipMemcpyH2DAsync
  , hipMemcpyH2DWithStream
  , hipStreamAddCallback
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipHostMallocPortable
  , pattern HipSuccess
  )
import ROCm.RocBLAS
  ( RocblasInt
  , pattern RocblasEvectOriginal
  , pattern RocblasFillLower
  , pattern RocblasInPlace
  , pattern RocblasOperationNone
  , pattern RocblasSvectSingular
  , rocblasDgemm
  , rocblasDgemv
  , rocblasSaxpy
  , rocblasSetStream
  , rocblasSgemm
  , rocblasSgemv
  , withRocblasHandle
  )
import ROCm.RocFFT
  ( rocfftExecute
  , rocfftExecutionInfoSetStream
  , rocfftExecutionInfoSetWorkBuffer
  , rocfftPlanCreate
  , rocfftPlanDescriptionSetDataLayout
  , rocfftPlanDescriptionSetScaleFactor
  , rocfftPlanGetWorkBufferSize
  , withRocfft
  , withRocfftExecutionInfo
  , withRocfftPlan
  , withRocfftPlanDescription
  , pattern RocfftArrayTypeComplexInterleaved
  , pattern RocfftPlacementInplace
  , pattern RocfftPlacementNotInplace
  , pattern RocfftPrecisionSingle
  , pattern RocfftTransformTypeComplexForward
  , pattern RocfftTransformTypeComplexInverse
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
  , rocsolverSgesv
  , rocsolverSgesvd
  , rocsolverSorgqr
  , rocsolverSposv
  , rocsolverSsyev
  )

data SmokeResult
  = SmokePassed
  | SmokeSkipped String

main :: IO ()
main = do
  results <-
    forM
      [ ("hip-memcpy-roundtrip", hipMemcpySmoke)
      , ("hip-async-pinned-event", hipAsyncPinnedEventSmoke)
      , ("hip-stream-callback", hipStreamCallbackSmoke)
      , ("hip-event-query-timing", hipEventQueryTimingSmoke)
      , ("rocfft-c2c-1d", rocfftSmoke)
      , ("rocfft-c2c-normalized", rocfftNormalizedSmoke)
      , ("rocfft-batched-notinplace", rocfftBatchedNotInplaceSmoke)
      , ("rocrand-uniform", rocrandUniformSmoke)
      , ("rocsparse-scsrmv", rocsparseScsrmvSmoke)
      , ("rocsparse-generic-spmv", rocsparseGenericSpmvSmoke)
      , ("rocsolver-sposv", rocsolverSposvSmoke)
      , ("rocsolver-sgesv", rocsolverSgesvSmoke)
      , ("rocsolver-sgeqrf-orgqr", rocsolverSgeqrfOrgqrSmoke)
      , ("rocsolver-ssyev", rocsolverSsyevSmoke)
      , ("rocsolver-sgesvd", rocsolverSgesvdSmoke)
      , ("rocblas-saxpy", rocblasSmoke)
      , ("rocblas-sgemv", rocblasGemvSmoke)
      , ("rocblas-dgemv", rocblasDGemvSmoke)
      , ("rocblas-sgemm", rocblasGemmSmoke)
      , ("rocblas-dgemm", rocblasDGemmSmoke)
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
