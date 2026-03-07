{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Array (peekArray, pokeArray)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr, PinnedHostPtr(..))
import ROCm.HIP
  ( hipEventCreateWithFlags
  , hipEventDestroy
  , hipEventRecordWithFlags
  , hipFree
  , hipHostFree
  , hipHostMallocBytes
  , hipMallocBytes
  , hipMemcpyD2HAsync
  , hipMemcpyH2DAsync
  , hipStreamCreateWithFlags
  , hipStreamDestroy
  , hipStreamQuery
  , hipStreamSynchronize
  , hipStreamWaitEvent
  , pattern HipEventBlockingSync
  , pattern HipEventRecordExternal
  , pattern HipStreamNonBlocking
  )

main :: IO ()
main = do
  r <- try run :: IO (Either SomeException ())
  case r of
    Left e -> putStrLn (displayException e) >> exitFailure
    Right () -> pure ()

run :: IO ()
run = do
  let n = 16 :: Int
      input = fmap (CFloat . fromIntegral) [0 .. n - 1]
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

  bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
    bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOut ->
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
        bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream1 ->
          bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream2 ->
            bracket (hipEventCreateWithFlags HipEventBlockingSync) hipEventDestroy $ \ev -> do
              let PinnedHostPtr pIn = hIn
                  PinnedHostPtr pOut = hOut
              pokeArray pIn input
              hipMemcpyH2DAsync dBuf hIn bytes stream1
              hipEventRecordWithFlags ev stream1 HipEventRecordExternal
              hipStreamWaitEvent stream2 ev 0
              hipMemcpyD2HAsync hOut dBuf bytes stream2
              hipStreamSynchronize stream2
              ready <- hipStreamQuery stream2
              output <- peekArray n pOut
              when (not ready || output /= input) $ do
                putStrLn "hip stream wait-event mismatch"
                putStrLn ("ready:    " <> show ready)
                putStrLn ("expected: " <> show input)
                putStrLn ("got:      " <> show output)
                exitFailure

  putStrLn "hip stream wait-event: OK"
