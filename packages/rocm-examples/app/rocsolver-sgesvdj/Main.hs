{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
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
  , pattern RocblasSvectSingular
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSgesvdj)

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
      putStrLn ("rocSOLVER sgesvdj: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sgesvdj"
      putStrLn ("Current device: " <> deviceName)
    else do
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
                    when (not (infoOk && residualOk && sweepsOk && approxVecWithTol 1.0e-3 sVals expectedS && approxVecWithTol 1.0e-3 recon aOriginal && approxVecWithTol 1.0e-3 uGram identity2 && approxVecWithTol 1.0e-3 vGram identity2)) $ do
                      putStrLn "rocsolver_sgesvdj mismatch"
                      putStrLn ("residual: " <> show residualVals)
                      putStrLn ("sweeps:   " <> show nSweepsVals)
                      putStrLn ("s:        " <> show sVals)
                      putStrLn ("recon:    " <> show recon)
                      putStrLn ("uGram:    " <> show uGram)
                      putStrLn ("vGram:    " <> show vGram)
                      putStrLn ("info:     " <> show infoVals)
                      exitFailure

      putStrLn "rocSOLVER sgesvdj: OK"

approxVecWithTol :: Float -> [CFloat] -> [CFloat] -> Bool
approxVecWithTol eps xs ys =
  length xs == length ys
    && and (zipWith (approxCFloatWithTol eps) xs ys)

approxCFloatWithTol :: Float -> CFloat -> CFloat -> Bool
approxCFloatWithTol eps (CFloat a) (CFloat b) = abs (a - b) <= eps

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
