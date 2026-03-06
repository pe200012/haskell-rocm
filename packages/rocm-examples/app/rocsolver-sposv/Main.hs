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
  , pattern RocblasFillLower
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSposv)

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
      putStrLn ("rocSOLVER sposv: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sposv"
      putStrLn ("Current device: " <> deviceName)
    else do
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
            when (not (infoOk && approxVec out expected)) $ do
              putStrLn "rocsolver_sposv mismatch"
              putStrLn ("expected: " <> show expected)
              putStrLn ("got:      " <> show out)
              putStrLn ("info:     " <> show infoVals)
              exitFailure

      putStrLn "rocSOLVER sposv: OK"

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys = length xs == length ys && and (zipWith approxCFloat xs ys)

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
