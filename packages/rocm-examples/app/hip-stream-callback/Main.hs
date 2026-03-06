{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, bracket, displayException, try)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr, HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2DWithStream
  , hipStreamAddCallback
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipSuccess
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
  let n = 16 :: Int
      input = fmap (CFloat . fromIntegral) [0 .. n - 1]
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize

  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      cbMVar <- newEmptyMVar

      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
        bracket hipStreamCreate hipStreamDestroy $ \stream -> do
          hipMemcpyH2DWithStream dBuf (HostPtr hIn) bytes stream
          hipStreamAddCallback stream (\_ status -> putMVar cbMVar status)
          hipStreamSynchronize stream
          cbStatus <- takeMVar cbMVar
          hipMemcpyD2H (HostPtr hOut) dBuf bytes
          out <- peekArray n hOut
          if cbStatus == HipSuccess && out == input
            then putStrLn "hip stream callback: OK"
            else do
              putStrLn ("callback status: " <> show cbStatus)
              putStrLn ("expected: " <> show input)
              putStrLn ("got:      " <> show out)
              exitFailure
