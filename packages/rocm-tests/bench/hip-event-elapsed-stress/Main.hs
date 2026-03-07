{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (foldM, when)
import Data.List (stripPrefix)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Array (pokeArray)
import Foreign.Marshal.Utils (with)
import Foreign.Storable (sizeOf, peek)
import GHC.Stack (HasCallStack)
import System.Environment (getArgs)
import Text.Printf (printf)
import Text.Read (readMaybe)

import ROCm.FFI.Core.Types (DevicePtr(..), HipEvent(..), HipStream, PinnedHostPtr(..))
import ROCm.HIP
  ( hipEventCreate
  , hipEventDestroy
  , hipEventElapsedTime
  , hipEventQuery
  , hipEventRecord
  , hipEventSynchronize
  , hipFree
  , hipHostFree
  , hipHostMallocBytesWithFlags
  , hipMallocBytes
  , hipMemcpyH2DAsync
  , hipStreamCreate
  , hipStreamDestroy
  , pattern HipHostMallocPortable
  )
import ROCm.HIP.Raw (c_hipEventElapsedTime)
import ROCm.HIP.Types (HipError(..), pattern HipSuccess)

data Config = Config
  { configRounds :: !Int
  }

data Stats = Stats
  { statsRounds :: !Int
  , statsReadyFalseCount :: !Int
  , statsRawStatusFailureCount :: !Int
  , statsRawSentinelUnchangedCount :: !Int
  , statsRawNegativeCount :: !Int
  , statsWrappedExceptionCount :: !Int
  , statsWrappedNegativeCount :: !Int
  , statsRawWrappedMismatchCount :: !Int
  , statsRawMin :: !(Maybe Float)
  , statsRawMax :: !(Maybe Float)
  , statsWrappedMin :: !(Maybe Float)
  , statsWrappedMax :: !(Maybe Float)
  , statsFirstAnomaly :: !(Maybe String)
  }

defaultConfig :: Config
defaultConfig = Config {configRounds = 5000}

usage :: String
usage = unlines
  [ "Usage: cabal run rocm-tests:hip-event-elapsed-stress -- [--rounds=N]"
  , "  --rounds=N  positive number of repeated event-timing rounds"
  ]

parseConfig :: [String] -> IO Config
parseConfig = foldM step defaultConfig
 where
  step cfg arg
    | Just raw <- stripPrefix "--rounds=" arg
    , Just n <- readMaybe raw
    , n > 0 = pure cfg {configRounds = n}
    | otherwise = ioError (userError ("invalid argument: " ++ arg ++ "\n" ++ usage))

emptyStats :: Stats
emptyStats =
  Stats
    { statsRounds = 0
    , statsReadyFalseCount = 0
    , statsRawStatusFailureCount = 0
    , statsRawSentinelUnchangedCount = 0
    , statsRawNegativeCount = 0
    , statsWrappedExceptionCount = 0
    , statsWrappedNegativeCount = 0
    , statsRawWrappedMismatchCount = 0
    , statsRawMin = Nothing
    , statsRawMax = Nothing
    , statsWrappedMin = Nothing
    , statsWrappedMax = Nothing
    , statsFirstAnomaly = Nothing
    }

recordFloat :: Maybe Float -> Maybe Float -> Float -> (Maybe Float, Maybe Float)
recordFloat curMin curMax x =
  ( Just (maybe x (min x) curMin)
  , Just (maybe x (max x) curMax)
  )

recordAnomaly :: String -> Stats -> Stats
recordAnomaly msg stats =
  stats {statsFirstAnomaly = statsFirstAnomaly stats <|> Just msg}

hipErrorCode :: HipError -> Int
hipErrorCode = fromIntegral . unHipError

rawElapsedTimeInitialized :: HasCallStack => HipEvent -> HipEvent -> IO (HipError, Float)
rawElapsedTimeInitialized (HipEvent start) (HipEvent stop) =
  with (CFloat (-12345.0)) $ \pMs -> do
    status <- c_hipEventElapsedTime pMs start stop
    CFloat ms <- peek pMs
    pure (status, ms)

runRound :: Int -> PinnedHostPtr CFloat -> DevicePtr CFloat -> CSize -> HipStream -> HipEvent -> HipEvent -> Stats -> IO Stats
runRound roundIndex hIn dBuf bytes stream startEv stopEv stats0 = do
  hipEventRecord startEv stream
  hipMemcpyH2DAsync dBuf hIn bytes stream
  hipEventRecord stopEv stream
  hipEventSynchronize stopEv
  ready <- hipEventQuery stopEv
  let stats1Base = stats0 {statsRounds = statsRounds stats0 + 1}
      stats1
        | ready = stats1Base
        | otherwise =
            recordAnomaly
              ("round " ++ show roundIndex ++ ": stop event not ready after synchronize")
              stats1Base {statsReadyFalseCount = statsReadyFalseCount stats1Base + 1}
  (rawStatus, rawMs) <- rawElapsedTimeInitialized startEv stopEv
  let rawStatusOk = rawStatus == HipSuccess
      stats2
        | not rawStatusOk =
            recordAnomaly
              ("round " ++ show roundIndex ++ ": raw hipEventElapsedTime status=" ++ show (hipErrorCode rawStatus))
              stats1 {statsRawStatusFailureCount = statsRawStatusFailureCount stats1 + 1}
        | rawMs == (-12345.0) =
            recordAnomaly
              ("round " ++ show roundIndex ++ ": raw hipEventElapsedTime left sentinel unchanged")
              stats1 {statsRawSentinelUnchangedCount = statsRawSentinelUnchangedCount stats1 + 1}
        | rawMs < 0 =
            let (newMin, newMax) = recordFloat (statsRawMin stats1) (statsRawMax stats1) rawMs
             in recordAnomaly
                  ("round " ++ show roundIndex ++ ": raw hipEventElapsedTime negative ms=" ++ show rawMs)
                  stats1
                    { statsRawNegativeCount = statsRawNegativeCount stats1 + 1
                    , statsRawMin = newMin
                    , statsRawMax = newMax
                    }
        | otherwise =
            let (newMin, newMax) = recordFloat (statsRawMin stats1) (statsRawMax stats1) rawMs
             in stats1 {statsRawMin = newMin, statsRawMax = newMax}
  wrapped <- try (hipEventElapsedTime startEv stopEv) :: IO (Either SomeException Float)
  pure $ case wrapped of
    Left e ->
      recordAnomaly
        ("round " ++ show roundIndex ++ ": wrapped hipEventElapsedTime threw " ++ displayException e)
        stats2 {statsWrappedExceptionCount = statsWrappedExceptionCount stats2 + 1}
    Right wrappedMs
      | wrappedMs < 0 ->
          let (newMin, newMax) = recordFloat (statsWrappedMin stats2) (statsWrappedMax stats2) wrappedMs
           in recordAnomaly
                ("round " ++ show roundIndex ++ ": wrapped hipEventElapsedTime negative ms=" ++ show wrappedMs)
                stats2
                  { statsWrappedNegativeCount = statsWrappedNegativeCount stats2 + 1
                  , statsWrappedMin = newMin
                  , statsWrappedMax = newMax
                  }
      | rawStatusOk && rawMs /= (-12345.0) && rawMs >= 0 && abs (wrappedMs - rawMs) > 1e-6 ->
          let (newMin, newMax) = recordFloat (statsWrappedMin stats2) (statsWrappedMax stats2) wrappedMs
           in recordAnomaly
                ("round " ++ show roundIndex ++ ": raw/wrapped mismatch raw=" ++ show rawMs ++ ", wrapped=" ++ show wrappedMs)
                stats2
                  { statsRawWrappedMismatchCount = statsRawWrappedMismatchCount stats2 + 1
                  , statsWrappedMin = newMin
                  , statsWrappedMax = newMax
                  }
      | otherwise ->
          let (newMin, newMax) = recordFloat (statsWrappedMin stats2) (statsWrappedMax stats2) wrappedMs
           in stats2 {statsWrappedMin = newMin, statsWrappedMax = newMax}

main :: IO ()
main = do
  cfg <- parseConfig =<< getArgs
  let n = 1024 * 256 :: Int
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      input = fmap (CFloat . fromIntegral . (`mod` 97)) [0 .. n - 1]
  printf "hipEventElapsedTime stress: rounds=%d bytes=%d\n" (configRounds cfg) (fromIntegral bytes :: Int)
  bracket (hipHostMallocBytesWithFlags bytes HipHostMallocPortable :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
      bracket hipStreamCreate hipStreamDestroy $ \stream ->
        bracket hipEventCreate hipEventDestroy $ \startEv ->
          bracket hipEventCreate hipEventDestroy $ \stopEv -> do
            let PinnedHostPtr pIn = hIn
            pokeArray pIn input
            stats <- foldM (\stats i -> runRound i hIn dBuf bytes stream startEv stopEv stats) emptyStats [1 .. configRounds cfg]
            printf "ready_false=%d raw_status_fail=%d raw_sentinel_unchanged=%d raw_negative=%d wrapped_exception=%d wrapped_negative=%d raw_wrapped_mismatch=%d\n"
              (statsReadyFalseCount stats)
              (statsRawStatusFailureCount stats)
              (statsRawSentinelUnchangedCount stats)
              (statsRawNegativeCount stats)
              (statsWrappedExceptionCount stats)
              (statsWrappedNegativeCount stats)
              (statsRawWrappedMismatchCount stats)
            printf "raw_range=%s..%s wrapped_range=%s..%s\n"
              (showMaybeFloat (statsRawMin stats))
              (showMaybeFloat (statsRawMax stats))
              (showMaybeFloat (statsWrappedMin stats))
              (showMaybeFloat (statsWrappedMax stats))
            case statsFirstAnomaly stats of
              Nothing -> putStrLn "first_anomaly=none"
              Just msg -> putStrLn ("first_anomaly=" ++ msg)
            let badCount =
                  statsReadyFalseCount stats
                    + statsRawStatusFailureCount stats
                    + statsRawSentinelUnchangedCount stats
                    + statsRawNegativeCount stats
                    + statsWrappedExceptionCount stats
                    + statsWrappedNegativeCount stats
                    + statsRawWrappedMismatchCount stats
            when (badCount > 0) (ioError (userError "hipEventElapsedTime stress detected anomalies"))

showMaybeFloat :: Maybe Float -> String
showMaybeFloat = maybe "n/a" (printf "%.6f")
