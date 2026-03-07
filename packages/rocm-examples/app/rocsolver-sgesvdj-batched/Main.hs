{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (intercalate, isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr, plusPtr)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.Process (readProcess)

import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipGetCurrentDeviceGcnArchName
  , hipGetCurrentDeviceName
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocBLAS
  ( RocblasInt
  , RocblasStride
  , pattern RocblasSvectSingular
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSgesvdjBatched)

main :: IO ()
main = do
  r <- try run :: IO (Either SomeException ())
  case r of
    Left e -> do
      putStrLn (displayException e)
      exitFailure
    Right () -> pure ()

run :: IO ()
run = do
  deviceName <- hipGetCurrentDeviceName
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"

  if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
    then do
      putStrLn ("rocSOLVER sgesvdj batched: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sgesvdj-batched"
      putStrLn ("Current device: " <> deviceName)
    else do
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
                      when (not (all fst reports)) $ do
                        putStrLn ("rocsolver_sgesvdj_batched mismatch: " <> intercalate "; " (map snd reports))
                        exitFailure

      putStrLn "rocSOLVER sgesvdj batched: OK"

approxVecWithTol :: Float -> [CFloat] -> [CFloat] -> Bool
approxVecWithTol eps xs ys =
  length xs == length ys
    && and (zipWith (approxCFloatWithTol eps) xs ys)

approxCFloatWithTol :: Float -> CFloat -> CFloat -> Bool
approxCFloatWithTol eps (CFloat a) (CFloat b) = abs (a - b) <= eps

matMulColMajorCFloat :: Int -> Int -> Int -> [CFloat] -> [CFloat] -> [CFloat]
matMulColMajorCFloat m k nCols a b =
  [ CFloat (sum [unCFloat (indexColMajor m a row t) * unCFloat (indexColMajor k b t col) | t <- [0 .. k - 1]])
  | col <- [0 .. nCols - 1]
  , row <- [0 .. m - 1]
  ]

gramMatrixColMajorCFloat :: Int -> Int -> [CFloat] -> [CFloat]
gramMatrixColMajorCFloat m nCols q =
  [ CFloat (sum [unCFloat (indexColMajor m q row i) * unCFloat (indexColMajor m q row j) | row <- [0 .. m - 1]])
  | j <- [0 .. nCols - 1]
  , i <- [0 .. nCols - 1]
  ]

diagColMajorCFloat :: [CFloat] -> [CFloat]
diagColMajorCFloat vals =
  [ if row == col then vals !! row else CFloat 0
  | col <- [0 .. nVals - 1]
  , row <- [0 .. nVals - 1]
  ]
  where
    nVals = length vals

indexColMajor :: Int -> [a] -> Int -> Int -> a
indexColMajor rows vals row col = vals !! (row + col * rows)

unCFloat :: CFloat -> Float
unCFloat (CFloat x) = x

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
    extractName line =
      case break (== ':') line of
        ("Name", ':' : rest) -> Just (dropWhile isSpace rest)
        _ -> Nothing
