{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, pokeArray)
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
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocBLAS (RocblasInt, rocblasSdot, rocblasSetStream, withRocblasHandle)

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
      putStrLn ("rocBLAS sdot: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-sdot"
      putStrLn ("Current device: " <> deviceName)
    else do
      let n = 3 :: Int
          xVals = fmap CFloat [2, 4, 6]
          yVals = fmap CFloat [4, 5, 6]
          expected = 64.0 :: Float
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray n) free $ \hX ->
        bracket (mallocArray n) free $ \hY -> do
          pokeArray hX xVals
          pokeArray hY yVals
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dX ->
            bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
              hipMemcpyH2D dX (HostPtr hX) bytes
              hipMemcpyH2D dY (HostPtr hY) bytes
              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                withRocblasHandle $ \handle -> do
                  rocblasSetStream handle stream
                  result <- rocblasSdot handle (fromIntegral n :: RocblasInt) dX 1 dY 1
                  hipStreamSynchronize stream
                  when (abs (result - expected) > 1.0e-4) $ do
                    putStrLn "rocBLAS SDOT mismatch"
                    putStrLn ("expected: " <> show expected)
                    putStrLn ("got:      " <> show result)
                    exitFailure
      putStrLn "rocBLAS sdot: OK"

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
