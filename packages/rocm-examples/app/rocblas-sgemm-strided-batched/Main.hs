{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
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
  , pattern RocblasOperationNone
  , rocblasSetStream
  , rocblasSgemmStridedBatched
  , withRocblasHandle
  )

main :: IO ()
main = do
  r <- try run :: IO (Either SomeException ())
  case r of
    Left e -> putStrLn (displayException e) >> exitFailure
    Right () -> pure ()

run :: IO ()
run = do
  deviceName <- hipGetCurrentDeviceName
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
    then do
      putStrLn ("rocBLAS sgemm strided-batched: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-sgemm-strided-batched"
      putStrLn ("Current device: " <> deviceName)
    else do
      let batchCount = 2 :: Int
          m = 2 :: Int
          n = 2 :: Int
          k = 2 :: Int
          strideA = fromIntegral (m * k) :: RocblasStride
          strideB = fromIntegral (k * n) :: RocblasStride
          strideC = fromIntegral (m * n) :: RocblasStride
          aVals = fmap CFloat [1, 3, 2, 4, 2, 1, 0, 3]
          bVals = fmap CFloat [5, 7, 6, 8, 1, 2, 4, 5]
          expected = fmap CFloat [19, 43, 22, 50, 2, 7, 8, 19]
          bytesA = fromIntegral (batchCount * m * k * sizeOf (undefined :: CFloat)) :: CSize
          bytesB = fromIntegral (batchCount * k * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesC = fromIntegral (batchCount * m * n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray (batchCount * m * k)) free $ \hA ->
        bracket (mallocArray (batchCount * k * n)) free $ \hB ->
          bracket (mallocArray (batchCount * m * n)) free $ \hC -> do
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
                        (fromIntegral batchCount :: RocblasInt)
                      hipStreamSynchronize stream
                  hipMemcpyD2H (HostPtr hC) dC bytesC
            out <- peekArray (batchCount * m * n) hC
            when (out /= expected) $ do
              putStrLn "rocBLAS SGEMM strided-batched mismatch"
              putStrLn ("expected: " <> show expected)
              putStrLn ("got:      " <> show out)
              exitFailure
      putStrLn "rocBLAS sgemm strided-batched: OK"

detectCurrentGpuArch :: IO String
detectCurrentGpuArch = do
  archName <- hipGetCurrentDeviceGcnArchName
  if "gfx" `isPrefixOf` archName then pure archName else do
    archs <- discoverGpuArchs
    pure (case archs of x : _ -> x; [] -> archName)

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
