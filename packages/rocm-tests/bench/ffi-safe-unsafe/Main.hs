{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Control.Monad (foldM, replicateM, void)
import Data.List (stripPrefix)
import Data.Word (Word64)
import Foreign.C.Types (CInt(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr)
import GHC.Clock (getMonotonicTimeNSec)
import ROCm.HIP.Types (HipError(..))
import System.Environment (getArgs)
import Text.Printf (printf)
import Text.Read (readMaybe)

data Config = Config
  { configIterations :: !Int
  , configRepeats :: !Int
  }

data BenchCase = BenchCase
  { benchCaseName :: String
  , benchCaseSafe :: IO HipError
  , benchCaseUnsafe :: IO HipError
  }

data BenchStats = BenchStats
  { benchStatsBestNsPerCall :: !Double
  , benchStatsAvgNsPerCall :: !Double
  }

defaultConfig :: Config
defaultConfig =
  Config
    { configIterations = 200000
    , configRepeats = 5
    }

usage :: String
usage = unlines
  [ "Usage: cabal run rocm-tests:ffi-safe-unsafe-bench -- [--iterations=N] [--repeats=N]"
  , "  --iterations=N  positive number of calls per timing sample"
  , "  --repeats=N     positive number of timing samples per mode"
  ]

parseConfig :: [String] -> IO Config
parseConfig = foldM step defaultConfig
 where
  step cfg arg
    | Just raw <- stripPrefix "--iterations=" arg
    , Just n <- readMaybe raw
    , n > 0 = pure cfg {configIterations = n}
    | Just raw <- stripPrefix "--repeats=" arg
    , Just n <- readMaybe raw
    , n > 0 = pure cfg {configRepeats = n}
    | otherwise = ioError (userError ("invalid argument: " ++ arg ++ "\n" ++ usage))

hipErrorCode :: HipError -> Int
hipErrorCode = fromIntegral . unHipError

preflight :: String -> IO HipError -> IO Bool
preflight label action = do
  status <- action
  if hipErrorCode status == 0
    then pure True
    else do
      putStrLn $ label ++ " preflight failed with hip error code " ++ show (hipErrorCode status)
      pure False

measureAction :: Int -> IO () -> IO Word64
measureAction iterations action = do
  start <- getMonotonicTimeNSec
  go iterations
  end <- getMonotonicTimeNSec
  pure (end - start)
 where
  go :: Int -> IO ()
  go !n
    | n <= 0 = pure ()
    | otherwise = action >> go (n - 1)

computeStats :: Int -> [Word64] -> BenchStats
computeStats iterations samples =
  let sampleCount = fromIntegral (length samples) :: Double
      bestNs = fromIntegral (minimum samples) :: Double
      totalNs = fromIntegral (sum samples) :: Double
      iterationsD = fromIntegral iterations :: Double
   in BenchStats
        { benchStatsBestNsPerCall = bestNs / iterationsD
        , benchStatsAvgNsPerCall = (totalNs / sampleCount) / iterationsD
        }

runMode :: Config -> String -> IO HipError -> IO (Maybe BenchStats)
runMode cfg label action = do
  ready <- preflight label action
  if not ready
    then pure Nothing
    else do
      void action
      samples <- replicateM (configRepeats cfg) (measureAction (configIterations cfg) (void action))
      pure (Just (computeStats (configIterations cfg) samples))

runBenchCase :: Config -> BenchCase -> IO ()
runBenchCase cfg benchCase = do
  putStrLn $ "\n== " ++ benchCaseName benchCase ++ " =="
  safeStats <- runMode cfg (benchCaseName benchCase ++ " safe") (benchCaseSafe benchCase)
  unsafeStats <- runMode cfg (benchCaseName benchCase ++ " unsafe") (benchCaseUnsafe benchCase)
  case (safeStats, unsafeStats) of
    (Just safeResult, Just unsafeResult) -> do
      printStats "safe" safeResult
      printStats "unsafe" unsafeResult
      printf "ratio   unsafe/safe  best=%.4f  avg=%.4f\n"
        (benchStatsBestNsPerCall unsafeResult / benchStatsBestNsPerCall safeResult)
        (benchStatsAvgNsPerCall unsafeResult / benchStatsAvgNsPerCall safeResult)
    _ ->
      putStrLn "skipped because preflight did not succeed for both modes"
 where
  printStats :: String -> BenchStats -> IO ()
  printStats mode stats =
    printf "%-7s best=%10.2f ns/call  avg=%10.2f ns/call\n"
      mode
      (benchStatsBestNsPerCall stats)
      (benchStatsAvgNsPerCall stats)

withBenchCases :: (Config -> [BenchCase] -> IO a) -> Config -> IO a
withBenchCases action cfg =
  alloca $ \pDeviceCount ->
    alloca $ \pCurrentDevice ->
      alloca $ \pRuntimeVersion ->
        alloca $ \pDriverVersion ->
          action cfg
            [ BenchCase
                { benchCaseName = "hipGetDeviceCount"
                , benchCaseSafe = c_safe_hipGetDeviceCount pDeviceCount
                , benchCaseUnsafe = c_unsafe_hipGetDeviceCount pDeviceCount
                }
            , BenchCase
                { benchCaseName = "hipGetDevice"
                , benchCaseSafe = c_safe_hipGetDevice pCurrentDevice
                , benchCaseUnsafe = c_unsafe_hipGetDevice pCurrentDevice
                }
            , BenchCase
                { benchCaseName = "hipRuntimeGetVersion"
                , benchCaseSafe = c_safe_hipRuntimeGetVersion pRuntimeVersion
                , benchCaseUnsafe = c_unsafe_hipRuntimeGetVersion pRuntimeVersion
                }
            , BenchCase
                { benchCaseName = "hipDriverGetVersion"
                , benchCaseSafe = c_safe_hipDriverGetVersion pDriverVersion
                , benchCaseUnsafe = c_unsafe_hipDriverGetVersion pDriverVersion
                }
            ]

main :: IO ()
main = do
  cfg <- parseConfig =<< getArgs
  putStrLn "FFI safe/unsafe microbenchmark (initial HIP query slice)"
  printf "iterations=%d repeats=%d\n" (configIterations cfg) (configRepeats cfg)
  withBenchCases
    (\cfg' benchCases -> mapM_ (runBenchCase cfg') benchCases)
    cfg

foreign import ccall safe "hipGetDeviceCount"
  c_safe_hipGetDeviceCount :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipGetDeviceCount"
  c_unsafe_hipGetDeviceCount :: Ptr CInt -> IO HipError

foreign import ccall safe "hipGetDevice"
  c_safe_hipGetDevice :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipGetDevice"
  c_unsafe_hipGetDevice :: Ptr CInt -> IO HipError

foreign import ccall safe "hipRuntimeGetVersion"
  c_safe_hipRuntimeGetVersion :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipRuntimeGetVersion"
  c_unsafe_hipRuntimeGetVersion :: Ptr CInt -> IO HipError

foreign import ccall safe "hipDriverGetVersion"
  c_safe_hipDriverGetVersion :: Ptr CInt -> IO HipError

foreign import ccall unsafe "hipDriverGetVersion"
  c_unsafe_hipDriverGetVersion :: Ptr CInt -> IO HipError
