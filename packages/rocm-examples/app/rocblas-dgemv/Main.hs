{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CDouble(..), CSize)
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
  , rocblasDgemv
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
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"

  if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
    then do
      putStrLn ("rocBLAS dgemv: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-dgemv"
      putStrLn ("Current device: " <> deviceName)
    else do
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
            when (not (approxDVec out expected)) $ do
              putStrLn "rocblas_dgemv mismatch"
              putStrLn ("expected: " <> show expected)
              putStrLn ("got:      " <> show out)
              exitFailure

      putStrLn "rocBLAS dgemv: OK"

approxDVec :: [CDouble] -> [CDouble] -> Bool
approxDVec xs ys = length xs == length ys && and (zipWith approxCDouble xs ys)

approxCDouble :: CDouble -> CDouble -> Bool
approxCDouble (CDouble a) (CDouble b) = abs (a - b) <= 1.0e-10

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
