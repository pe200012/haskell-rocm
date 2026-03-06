{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Foreign.C.Types (CDouble(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure, exitSuccess)

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
  , rocblasDgemm
  , rocblasSetStream
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
  archName <- hipGetCurrentDeviceGcnArchName
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"

  when (archName == "gfx1103" && hsaOverride /= Just "11.0.0") $ do
    putStrLn ("rocBLAS dgemm: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
    putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-dgemm"
    putStrLn ("Current device: " <> deviceName)
    exitSuccess

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
        when (not (approxDVec out expected)) $ do
          putStrLn "rocblas_dgemm mismatch"
          putStrLn ("expected: " <> show expected)
          putStrLn ("got:      " <> show out)
          exitFailure

  putStrLn "rocBLAS dgemm: OK"

approxDVec :: [CDouble] -> [CDouble] -> Bool
approxDVec xs ys = length xs == length ys && and (zipWith approxCDouble xs ys)

approxCDouble :: CDouble -> CDouble -> Bool
approxCDouble (CDouble a) (CDouble b) = abs (a - b) <= 1.0e-10
