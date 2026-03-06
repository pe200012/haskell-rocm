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
  , pattern RocblasOperationNone
  , rocblasSetStream
  , rocblasSgemm
  , withRocblasHandle
  )

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
      putStrLn ("rocBLAS sgemm: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-sgemm"
      putStrLn ("Current device: " <> deviceName)
    else do
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
            when (not (approxVec out expected)) $ do
              putStrLn "rocBLAS SGEMM mismatch"
              putStrLn ("expected: " <> show expected)
              putStrLn ("got:      " <> show out)
              exitFailure

      putStrLn "rocBLAS sgemm: OK"

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys =
  length xs == length ys
    && and (zipWith approxCFloat xs ys)

approxCFloat :: CFloat -> CFloat -> Bool
approxCFloat (CFloat a) (CFloat b) = abs (a - b) <= 1.0e-4

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
