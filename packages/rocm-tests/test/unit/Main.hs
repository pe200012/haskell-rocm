{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, displayException, try)
import Control.Monad (forM)
import Foreign.C.String (peekCString)
import System.Exit (exitFailure, exitSuccess)

import ROCm.HIP
  ( hipGetLastError
  , hipPeekAtLastError
  , pattern HipHostMallocPortable
  )
import ROCm.HIP.Raw (c_hipGetErrorString)
import ROCm.HIP.Types (HipError(..))
import ROCm.RocBLAS.Types (pattern RocblasEvectOriginal, pattern RocblasFillLower, pattern RocblasInPlace, pattern RocblasStatusSuccess, pattern RocblasSvectSingular)
import ROCm.RocBLAS.Error (rocblasStatusToString)
import ROCm.RocFFT
  ( rocfftGetVersionString
  , withRocfft
  , withRocfftExecutionInfo
  , rocfftExecutionInfoSetLoadCallback
  , rocfftExecutionInfoSetStoreCallback
  )
import ROCm.RocFFT.Types (pattern RocfftStatusSuccess)
import ROCm.RocFFT.Error (rocfftStatusToString)
import ROCm.RocRAND (rocrandGetVersion, pattern RocRandStatusSuccess)
import ROCm.RocRAND.Error (rocRandStatusToString)
import ROCm.RocSPARSE
  ( pattern RocsparseStatusSuccess
  , pattern RocsparseIndexTypeI32
  , pattern RocsparseDataTypeF32R
  , pattern RocsparseV2SpMVStageAnalysis
  )
import ROCm.RocSPARSE.Error (rocsparseStatusToString)

main :: IO ()
main = do
  results <-
    forM
      [ ("hip-host-malloc-flags-pattern", hipHostFlagsUnit)
      , ("rocblas-fill-patterns", rocblasFillPatternsUnit)
      , ("rocblas-evect-patterns", rocblasEvectPatternsUnit)
      , ("rocblas-svect-patterns", rocblasSvectPatternsUnit)
      , ("rocblas-workmode-patterns", rocblasWorkmodePatternsUnit)
      , ("hip-success-string", hipSuccessStringUnit)
      , ("hip-last-error-reset", hipLastErrorResetUnit)
      , ("rocblas-status-string", rocblasStatusStringUnit)
      , ("rocfft-status-string", rocfftStatusStringUnit)
      , ("rocfft-version-string", rocfftVersionStringUnit)
      , ("rocfft-callback-clear", rocfftCallbackClearUnit)
      , ("rocrand-status-string", rocrandStatusStringUnit)
      , ("rocrand-version", rocrandVersionUnit)
      , ("rocsparse-status-string", rocsparseStatusStringUnit)
      , ("rocsparse-index-type-patterns", rocsparseIndexTypePatternsUnit)
      , ("rocsparse-data-type-patterns", rocsparseDataTypePatternsUnit)
      , ("rocsparse-v2-spmv-stage-patterns", rocsparseV2SpMVStagePatternsUnit)
      ]
      $ \(name, action) -> do
        outcome <- try action :: IO (Either SomeException ())
        case outcome of
          Left e -> do
            putStrLn ("FAIL  " <> name <> ": " <> displayException e)
            pure False
          Right () -> do
            putStrLn ("PASS  " <> name)
            pure True
  if and results then exitSuccess else exitFailure

hipHostFlagsUnit :: IO ()
hipHostFlagsUnit =
  case HipHostMallocPortable of
    _ -> pure ()

rocblasFillPatternsUnit :: IO ()
rocblasFillPatternsUnit =
  case RocblasFillLower of
    _ -> pure ()

rocblasEvectPatternsUnit :: IO ()
rocblasEvectPatternsUnit =
  case RocblasEvectOriginal of
    _ -> pure ()

rocblasSvectPatternsUnit :: IO ()
rocblasSvectPatternsUnit =
  case RocblasSvectSingular of
    _ -> pure ()

rocblasWorkmodePatternsUnit :: IO ()
rocblasWorkmodePatternsUnit =
  case RocblasInPlace of
    _ -> pure ()

hipSuccessStringUnit :: IO ()
hipSuccessStringUnit = do
  cstr <- c_hipGetErrorString (HipError 0)
  msg <- peekCString cstr
  if null msg then fail "empty hip success string" else pure ()

hipLastErrorResetUnit :: IO ()
hipLastErrorResetUnit = do
  _ <- hipPeekAtLastError
  _ <- hipGetLastError
  st2 <- hipGetLastError
  if st2 == HipError 0 then pure () else fail ("expected HipSuccess, got " <> show st2)

rocblasStatusStringUnit :: IO ()
rocblasStatusStringUnit = do
  msg <- rocblasStatusToString RocblasStatusSuccess
  if null msg then fail "empty rocblas status string" else pure ()

rocfftStatusStringUnit :: IO ()
rocfftStatusStringUnit = do
  let msg = rocfftStatusToString RocfftStatusSuccess
  if null msg then fail "empty rocfft status string" else pure ()

rocfftVersionStringUnit :: IO ()
rocfftVersionStringUnit = withRocfft $ do
  msg <- rocfftGetVersionString
  if null msg then fail "empty rocfft version string" else pure ()

rocfftCallbackClearUnit :: IO ()
rocfftCallbackClearUnit =
  withRocfft $
    withRocfftExecutionInfo $ \info -> do
      rocfftExecutionInfoSetLoadCallback info Nothing Nothing 0
      rocfftExecutionInfoSetStoreCallback info Nothing Nothing 0

rocrandStatusStringUnit :: IO ()
rocrandStatusStringUnit = do
  let msg = rocRandStatusToString RocRandStatusSuccess
  if null msg then fail "empty rocrand status string" else pure ()

rocrandVersionUnit :: IO ()
rocrandVersionUnit = do
  version <- rocrandGetVersion
  if version > 0 then pure () else fail ("invalid rocrand version: " <> show version)

rocsparseStatusStringUnit :: IO ()
rocsparseStatusStringUnit = do
  msg <- rocsparseStatusToString RocsparseStatusSuccess
  if null msg then fail "empty rocsparse status string" else pure ()

rocsparseIndexTypePatternsUnit :: IO ()
rocsparseIndexTypePatternsUnit =
  case RocsparseIndexTypeI32 of
    _ -> pure ()

rocsparseDataTypePatternsUnit :: IO ()
rocsparseDataTypePatternsUnit =
  case RocsparseDataTypeF32R of
    _ -> pure ()

rocsparseV2SpMVStagePatternsUnit :: IO ()
rocsparseV2SpMVStagePatternsUnit =
  case RocsparseV2SpMVStageAnalysis of
    _ -> pure ()
