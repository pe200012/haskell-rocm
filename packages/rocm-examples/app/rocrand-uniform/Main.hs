{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (unless)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray)
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
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocRAND
  ( RocRandRngType
  , pattern RocRandRngPseudoDefault
  , rocrandGenerateUniform
  , rocrandSetSeed
  , rocrandSetStream
  , withRocRandGenerator
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
      putStrLn ("rocRAND uniform: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocrand-uniform"
      putStrLn ("Current device: " <> deviceName)
    else do
      let n = 32 :: Int
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
          rngType = RocRandRngPseudoDefault :: RocRandRngType

      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
        bracket (mallocArray n) free $ \hOut ->
          bracket hipStreamCreate hipStreamDestroy $ \stream -> do
            withRocRandGenerator rngType $ \gen -> do
              rocrandSetStream gen stream
              rocrandSetSeed gen 20260306
              rocrandGenerateUniform gen dBuf (fromIntegral n)
              hipStreamSynchronize stream

            hipMemcpyD2H (HostPtr hOut) dBuf bytes
            xs <- peekArray n hOut
            unless (all inUnitInterval xs) $ do
              putStrLn ("rocRAND uniform out of range: " <> show xs)
              exitFailure

      putStrLn "rocRAND uniform: OK"
  where
    inUnitInterval (CFloat x) = x > 0 && x <= 1

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
