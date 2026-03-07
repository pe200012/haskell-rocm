{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (intercalate, isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.Process (readProcess)

import ROCm.FFI.Core.Types (DevicePtr, HostPtr(..))
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
  , pattern RocblasSrangeValue
  , pattern RocblasSvectSingular
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSgesvdxStridedBatched)

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
      putStrLn ("rocSOLVER sgesvdx strided-batched value-range: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sgesvdx-strided-batched-value"
      putStrLn ("Current device: " <> deviceName)
    else do
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
                    when (not (all fst reports)) $ do
                      putStrLn ("rocsolver_sgesvdx_strided_batched value-range mismatch: " <> intercalate "; " (map snd reports))
                      exitFailure

      putStrLn "rocSOLVER sgesvdx strided-batched value-range: OK"

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

rowGramMatrixColMajorCFloat :: Int -> Int -> [CFloat] -> [CFloat]
rowGramMatrixColMajorCFloat rows cols vals =
  [ CFloat (sum [unCFloat (indexColMajor rows vals i col) * unCFloat (indexColMajor rows vals j col) | col <- [0 .. cols - 1]])
  | j <- [0 .. rows - 1]
  , i <- [0 .. rows - 1]
  ]

diagColMajorCFloat :: [CFloat] -> [CFloat]
diagColMajorCFloat vals =
  [ if row == col then vals !! row else CFloat 0
  | col <- [0 .. nVals - 1]
  , row <- [0 .. nVals - 1]
  ]
  where
    nVals = length vals

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
