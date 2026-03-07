{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, bracket_, displayException, try)
import Control.Monad (when)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipHostRegister
  , hipHostUnregister
  , hipMallocBytes
  , hipMemcpyAsync
  , hipStreamCreateWithFlags
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipHostRegisterMapped
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyHostToDevice
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

  bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hIn ->
    bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hOut -> do
      pokeArray hIn input
      bracket_ (hipHostRegister (HostPtr hIn) bytes HipHostRegisterMapped) (hipHostUnregister (HostPtr hIn)) $
        bracket_ (hipHostRegister (HostPtr hOut) bytes HipHostRegisterMapped) (hipHostUnregister (HostPtr hOut)) $
          bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
            bracket (hipStreamCreateWithFlags HipStreamNonBlocking) hipStreamDestroy $ \stream -> do
              let DevicePtr pDev = dBuf
              hipMemcpyAsync (castPtr pDev) (castPtr hIn) bytes HipMemcpyHostToDevice stream
              hipMemcpyAsync (castPtr hOut) (castPtr pDev) bytes HipMemcpyDeviceToHost stream
              hipStreamSynchronize stream
              output <- peekArray n hOut
              when (output /= input) $ do
                putStrLn "hip host register roundtrip mismatch"
                putStrLn ("expected: " <> show input)
                putStrLn ("got:      " <> show output)
                exitFailure

  putStrLn "hip host register roundtrip: OK"
