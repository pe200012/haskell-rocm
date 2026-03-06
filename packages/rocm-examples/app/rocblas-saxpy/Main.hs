module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.Process (readProcess)

import ROCm.FFI.Core.Types (DevicePtr, HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocBLAS
  ( RocblasInt
  , rocblasSaxpy
  , rocblasSetStream
  , withRocblasHandle
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
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"
  archs <- discoverGpuArchs

  if any ("gfx1103" `isPrefixOf`) archs && hsaOverride /= Just "11.0.0"
    then do
      putStrLn "rocBLAS saxpy: skipped on gfx1103 because this rocBLAS install only ships gfx1100 kernels."
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocblas-saxpy"
    else do
      let n = 16 :: Int
          alpha = 2.0 :: Float
          xVals = [1 .. fromIntegral n] :: [Float]
          yVals = [100, 101 ..] :: [Float]

          xC = fmap CFloat xVals
          yC = take n (fmap CFloat yVals)

          expected = zipWith (\(CFloat x) (CFloat y) -> CFloat (alpha * x + y)) xC yC

          bytes :: CSize
          bytes = fromIntegral (n * sizeOf (undefined :: CFloat))

      bracket (mallocArray n) free $ \hX ->
        bracket (mallocArray n) free $ \hY ->
          bracket (mallocArray n) free $ \hOut -> do
            pokeArray hX xC
            pokeArray hY yC

            bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dX ->
              bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
                hipMemcpyH2D dX (HostPtr hX) bytes
                hipMemcpyH2D dY (HostPtr hY) bytes

                bracket hipStreamCreate hipStreamDestroy $ \stream ->
                  withRocblasHandle $ \handle -> do
                    rocblasSetStream handle stream
                    rocblasSaxpy handle (fromIntegral n :: RocblasInt) alpha dX 1 dY 1
                    hipStreamSynchronize stream

                hipMemcpyD2H (HostPtr hOut) dY bytes

            out <- peekArray n hOut
            when (not (approxVec out expected)) $ do
              putStrLn "rocblas_saxpy mismatch"
              putStrLn ("expected: " <> show expected)
              putStrLn ("got:      " <> show out)
              exitFailure

      putStrLn "rocBLAS saxpy: OK"

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys =
  length xs == length ys
    && and (zipWith approxCFloat xs ys)

approxCFloat :: CFloat -> CFloat -> Bool
approxCFloat (CFloat a) (CFloat b) = abs (a - b) <= 1.0e-4

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
    extractName :: String -> Maybe String
    extractName line =
      case break (== ':') line of
        ("Name", ':' : rest) -> Just (dropWhile isSpace rest)
        _ -> Nothing
