module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Int (Int32)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (HostPtr(..))
import ROCm.HIP
  ( hipDeviceSynchronize
  , hipFree
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
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
      input = fromIntegral <$> [0 .. n - 1] :: [Int32]
      bytes = fromIntegral (n * sizeOf (undefined :: Int32)) :: CSize

  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input

      bracket (hipMallocBytes bytes) hipFree $ \dBuf -> do
        hipMemcpyH2D dBuf (HostPtr hIn) bytes
        hipMemcpyD2H (HostPtr hOut) dBuf bytes
        hipDeviceSynchronize

      output <- peekArray n hOut
      when (output /= input) $ do
        putStrLn "mismatch between input and output"
        putStrLn ("input:  " <> show input)
        putStrLn ("output: " <> show output)
        exitFailure

  putStrLn "hipMemcpy roundtrip: OK"
