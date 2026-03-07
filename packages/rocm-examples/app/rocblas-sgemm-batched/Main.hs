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
  , rocblasSgemmBatched
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
      putStrLn ("rocBLAS sgemm batched: skipped on " <> archName <> " because this rocBLAS install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-sgemm-batched"
      putStrLn ("Current device: " <> deviceName)
    else do
      let batchCount = 2 :: Int
          m = 2 :: Int
          n = 2 :: Int
          k = 2 :: Int
          a0 = fmap CFloat [1, 3, 2, 4]
          b0 = fmap CFloat [5, 7, 6, 8]
          a1 = fmap CFloat [2, 1, 0, 3]
          b1 = fmap CFloat [1, 2, 4, 5]
          expected = fmap CFloat [19, 43, 22, 50, 2, 7, 8, 19]
          bytesAFlat = fromIntegral (batchCount * m * k * sizeOf (undefined :: CFloat)) :: CSize
          bytesBFlat = fromIntegral (batchCount * k * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesCFlat = fromIntegral (batchCount * m * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesAPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          bytesBPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          bytesCPtrs = fromIntegral (batchCount * sizeOf (undefined :: Ptr CFloat)) :: CSize
          matrixABytes = m * k * sizeOf (undefined :: CFloat)
          matrixBBytes = k * n * sizeOf (undefined :: CFloat)
          matrixCBytes = m * n * sizeOf (undefined :: CFloat)

      bracket (mallocArray (batchCount * m * k) :: IO (Ptr CFloat)) free $ \hAFlat ->
        bracket (mallocArray (batchCount * k * n) :: IO (Ptr CFloat)) free $ \hBFlat ->
          bracket (mallocArray (batchCount * m * n) :: IO (Ptr CFloat)) free $ \hCFlat ->
            bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hAPtrs ->
              bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hBPtrs ->
                bracket (mallocArray batchCount :: IO (Ptr (Ptr CFloat))) free $ \hCPtrs -> do
                  pokeArray hAFlat (a0 <> a1)
                  pokeArray hBFlat (b0 <> b1)
                  pokeArray hCFlat (replicate (batchCount * m * n) (CFloat 0))
                  bracket (hipMallocBytes bytesAFlat :: IO (DevicePtr CFloat)) hipFree $ \dAFlat ->
                    bracket (hipMallocBytes bytesBFlat :: IO (DevicePtr CFloat)) hipFree $ \dBFlat ->
                      bracket (hipMallocBytes bytesCFlat :: IO (DevicePtr CFloat)) hipFree $ \dCFlat ->
                        bracket (hipMallocBytes bytesAPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dAPtrs ->
                          bracket (hipMallocBytes bytesBPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dBPtrs ->
                            bracket (hipMallocBytes bytesCPtrs :: IO (DevicePtr (Ptr CFloat))) hipFree $ \dCPtrs -> do
                              hipMemcpyH2D dAFlat (HostPtr hAFlat) bytesAFlat
                              hipMemcpyH2D dBFlat (HostPtr hBFlat) bytesBFlat
                              hipMemcpyH2D dCFlat (HostPtr hCFlat) bytesCFlat
                              let DevicePtr pAFlat = dAFlat
                                  DevicePtr pBFlat = dBFlat
                                  DevicePtr pCFlat = dCFlat
                              pokeArray hAPtrs [pAFlat, pAFlat `plusPtr` matrixABytes]
                              pokeArray hBPtrs [pBFlat, pBFlat `plusPtr` matrixBBytes]
                              pokeArray hCPtrs [pCFlat, pCFlat `plusPtr` matrixCBytes]
                              hipMemcpyH2D dAPtrs (HostPtr hAPtrs) bytesAPtrs
                              hipMemcpyH2D dBPtrs (HostPtr hBPtrs) bytesBPtrs
                              hipMemcpyH2D dCPtrs (HostPtr hCPtrs) bytesCPtrs
                              bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                withRocblasHandle $ \handle -> do
                                  rocblasSetStream handle stream
                                  rocblasSgemmBatched
                                    handle
                                    RocblasOperationNone
                                    RocblasOperationNone
                                    (fromIntegral m :: RocblasInt)
                                    (fromIntegral n :: RocblasInt)
                                    (fromIntegral k :: RocblasInt)
                                    1.0
                                    dAPtrs
                                    (fromIntegral m :: RocblasInt)
                                    dBPtrs
                                    (fromIntegral k :: RocblasInt)
                                    0.0
                                    dCPtrs
                                    (fromIntegral m :: RocblasInt)
                                    (fromIntegral batchCount :: RocblasInt)
                                  hipStreamSynchronize stream
                              hipMemcpyD2H (HostPtr hCFlat) dCFlat bytesCFlat
                  out <- peekArray (batchCount * m * n) hCFlat
                  when (out /= expected) $ do
                    putStrLn "rocBLAS SGEMM batched mismatch"
                    putStrLn ("expected: " <> show expected)
                    putStrLn ("got:      " <> show out)
                    exitFailure
      putStrLn "rocBLAS sgemm batched: OK"

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
