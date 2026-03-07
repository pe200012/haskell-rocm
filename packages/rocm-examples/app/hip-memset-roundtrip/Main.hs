module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Word (Word8)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray)
import Foreign.Ptr (Ptr)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr, HostPtr(..))
import ROCm.HIP (hipFree, hipMallocBytes, hipMemcpyD2H, hipMemset)

main :: IO ()
main = do
  r <- try run :: IO (Either SomeException ())
  case r of
    Left e -> putStrLn (displayException e) >> exitFailure
    Right () -> pure ()

run :: IO ()
run = do
  let n = 32 :: Int
      bytes = fromIntegral n :: CSize
      expected = replicate n (0x5a :: Word8)

  bracket (mallocArray n :: IO (Ptr Word8)) free $ \hOut -> do
    bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf -> do
      hipMemset dBuf 0x5a bytes
      hipMemcpyD2H (HostPtr hOut) dBuf bytes
    output <- peekArray n hOut
    when (output /= expected) $ do
      putStrLn "hip memset mismatch"
      putStrLn ("expected: " <> show expected)
      putStrLn ("got:      " <> show output)
      exitFailure

  putStrLn "hip memset roundtrip: OK"
