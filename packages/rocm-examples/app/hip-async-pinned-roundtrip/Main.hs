{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Array (peekArray, pokeArray)
import Foreign.Ptr (castPtr)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr(..), PinnedHostPtr(..))
import ROCm.HIP
  ( hipEventRecord
  , hipEventSynchronize
  , hipFree
  , hipHostFree
  , hipHostMallocBytes
  , hipMallocBytes
  , hipMemcpyD2HAsync
  , hipMemcpyWithStream
  , hipStreamCreate
  , hipStreamDestroy
  , pattern HipMemcpyHostToDevice
  , withHipEvent
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

  bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hIn ->
    bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOut ->
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
        bracket hipStreamCreate hipStreamDestroy $ \stream ->
          withHipEvent $ \ev -> do
            let PinnedHostPtr pIn = hIn
                PinnedHostPtr pOut = hOut
                DevicePtr pDev = dBuf

            pokeArray pIn input
            hipMemcpyWithStream (castPtr pDev) (castPtr pIn) bytes HipMemcpyHostToDevice stream
            hipMemcpyD2HAsync hOut dBuf bytes stream
            hipEventRecord ev stream
            hipEventSynchronize ev

            output <- peekArray n pOut
            when (output /= input) $ do
              putStrLn "hip async pinned roundtrip mismatch"
              putStrLn ("expected: " <> show input)
              putStrLn ("got:      " <> show output)
              exitFailure

  putStrLn "hip async pinned roundtrip: OK"
