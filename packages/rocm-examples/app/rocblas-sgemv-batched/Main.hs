{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
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
  , pattern RocblasOperationNone
  , rocblasSetStream
  , rocblasSgemvBatched
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
      putStrLn ("rocBLAS sgemv batched: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-sgemv-batched"
      putStrLn ("Current device: " <> deviceName)
    else do
      let batchCount = 2 :: Int
          m = 2 :: Int
          n = 2 :: Int
          a0 = fmap CFloat [1, 3, 2, 4]
          a1 = fmap CFloat [2, 0, 0, 3]
          x0 = fmap CFloat [5, 6]
          x1 = fmap CFloat [7, 8]
          expected = fmap CFloat [17, 39, 14, 24]
          bytesAFlat = fromIntegral (batchCount * m * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesXFlat = fromIntegral (batchCount * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesYFlat = fromIntegral (batchCount * m * sizeOf (undefined :: CFloat)) :: CSize
          bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          bytesXPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          bytesYPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          matrixBytes = m * n * sizeOf (undefined :: CFloat)
          vecXBytes = n * sizeOf (undefined :: CFloat)
          vecYBytes = m * sizeOf (undefined :: CFloat)

      bracket (mallocArray (batchCount * m * n) :: IO (Ptr CFloat)) free $ \hAFlat ->
        bracket (mallocArray (batchCount * n) :: IO (Ptr CFloat)) free $ \hXFlat ->
          bracket (mallocArray (batchCount * m) :: IO (Ptr CFloat)) free $ \hYFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hXPtrs ->
                bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hYPtrs -> do
                  pokeArray hAFlat (a0 <> a1)
                  pokeArray hXFlat (x0 <> x1)
                  pokeArray hYFlat (replicate (batchCount * m) (CFloat 0))
                  bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                    bracket (hipMallocBytes bytesXFlat :: IO (DevicePtr CFloat)) hipFree $ \dXFlat ->
                      bracket (hipMallocBytes bytesYFlat :: IO (DevicePtr CFloat)) hipFree $ \dYFlat ->
                        bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                          bracket (hipMallocBytes bytesXPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dXPtrs ->
                            bracket (hipMallocBytes bytesYPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dYPtrs -> do
                              hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                              hipMemcpyH2D dXFlat (HostPtr hXFlat) bytesXFlat
                              hipMemcpyH2D dYFlat (HostPtr hYFlat) bytesYFlat
                              let DevicePtr pAFlat = dAFlat
                                  DevicePtr pXFlat = dXFlat
                                  DevicePtr pYFlat = dYFlat
                              pokeArray hAPtrs [pAFlat, pAFlat `plusPtr` matrixBytes]
                              pokeArray hXPtrs [pXFlat, pXFlat `plusPtr` vecXBytes]
                              pokeArray hYPtrs [pYFlat, pYFlat `plusPtr` vecYBytes]
                              hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs
                              hipMemcpyH2D dXPtrs (HostPtr hXPtrs) bytesXPtrs
                              hipMemcpyH2D dYPtrs (HostPtr hYPtrs) bytesYPtrs
                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocblasHandle $ \handle -> do
                                  rocblasSetStream handle stream
                                  rocblasSgemvBatched
                                    handle
                                    RocblasOperationNone
                                    (fromIntegral m :: RocblasInt)
                                    (fromIntegral n :: RocblasInt)
                                    1.0
                                    dAPtrs
                                    (fromIntegral m :: RocblasInt)
                                    dXPtrs
                                    1
                                    0.0
                                    dYPtrs
                                    1
                                    (fromIntegral batchCount :: RocblasInt)
                                  hipStreamSynchronize stream
                              hipMemcpyD2H (HostPtr hYFlat) dYFlat bytesYFlat
                  out <- peekArray (batchCount * m) hYFlat
                  when (out /= expected) $ do
                    putStrLn "rocBLAS SGEMV batched mismatch"
                    putStrLn ("expected: " <> show expected)
                    putStrLn ("got:      " <> show out)
                    exitFailure
      putStrLn "rocBLAS sgemv batched: OK"

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
