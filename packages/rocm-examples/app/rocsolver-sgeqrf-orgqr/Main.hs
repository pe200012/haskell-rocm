{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr)
import Foreign.Storable (sizeOf)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.Process (readProcess)

import ROCm.FFI.Core.Types (DevicePtr, HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipGetCurrentDeviceGcnArchName
  , hipGetCurrentDeviceName
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocBLAS
  ( RocblasInt
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER
  ( rocsolverSgeqrf
  , rocsolverSorgqr
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
  deviceName <- hipGetCurrentDeviceName
  archName <- detectCurrentGpuArch
  hsaOverride <- lookupEnv "HSA_OVERRIDE_GFX_VERSION"

  if "gfx1103" `isPrefixOf` archName && hsaOverride /= Just "11.0.0"
    then do
      putStrLn ("rocSOLVER sgeqrf/orgqr: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sgeqrf-orgqr"
      putStrLn ("Current device: " <> deviceName)
    else do
      let m = 3 :: Int
          n = 2 :: Int
          k = min m n
          aOriginal = fmap CFloat [1, 2, 3, 4, 5, 6]
          identity2 = fmap CFloat [1, 0, 0, 1]
          bytesA = fromIntegral (m * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesTau = fromIntegral (k * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hAIn ->
        bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hAFact ->
          bracket (mallocArray (m * n) :: IO (Ptr CFloat)) free $ \hQ -> do
            pokeArray hAIn aOriginal

            bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
              bracket (hipMallocBytes bytesTau :: IO (DevicePtr CFloat)) hipFree $ \dTau -> do
                hipMemcpyH2D dA (HostPtr hAIn) bytesA

                bracket hipStreamCreate hipStreamDestroy $ \stream ->
                  withRocblasHandle $ \handle -> do
                    rocblasSetStream handle stream
                    rocsolverSgeqrf
                      handle
                      (fromIntegral m :: RocblasInt)
                      (fromIntegral n :: RocblasInt)
                      dA
                      (fromIntegral m :: RocblasInt)
                      dTau
                    hipStreamSynchronize stream
                    hipMemcpyD2H (HostPtr hAFact) dA bytesA

                    rocsolverSorgqr
                      handle
                      (fromIntegral m :: RocblasInt)
                      (fromIntegral n :: RocblasInt)
                      (fromIntegral k :: RocblasInt)
                      dA
                      (fromIntegral m :: RocblasInt)
                      dTau
                    hipStreamSynchronize stream
                    hipMemcpyD2H (HostPtr hQ) dA bytesA

            factorized <- peekArray (m * n) hAFact
            qVals <- peekArray (m * n) hQ
            let rVals = extractThinRColMajor m n factorized
                recon = matMulColMajorCFloat m n n qVals rVals
                qtq = gramMatrixColMajorCFloat m n qVals
            when (not (approxVecWithTol 1.0e-3 recon aOriginal && approxVecWithTol 1.0e-3 qtq identity2)) $ do
              putStrLn "rocsolver_sgeqrf/orgqr mismatch"
              putStrLn ("reconstructed A: " <> show recon)
              putStrLn ("Q^T Q:          " <> show qtq)
              putStrLn ("R:              " <> show rVals)
              exitFailure

      putStrLn "rocSOLVER sgeqrf/orgqr: OK"

approxVecWithTol :: Float -> [CFloat] -> [CFloat] -> Bool
approxVecWithTol eps xs ys =
  length xs == length ys
    && and (zipWith (approxCFloatWithTol eps) xs ys)

approxCFloatWithTol :: Float -> CFloat -> CFloat -> Bool
approxCFloatWithTol eps (CFloat a) (CFloat b) = abs (a - b) <= eps

extractThinRColMajor :: Int -> Int -> [CFloat] -> [CFloat]
extractThinRColMajor m n vals =
  [ if row <= col then indexColMajor m vals row col else CFloat 0
  | col <- [0 .. k - 1]
  , row <- [0 .. k - 1]
  ]
  where
    k = min m n

matMulColMajorCFloat :: Int -> Int -> Int -> [CFloat] -> [CFloat] -> [CFloat]
matMulColMajorCFloat m k n a b =
  [ CFloat (sum [unCFloat (indexColMajor m a row t) * unCFloat (indexColMajor k b t col) | t <- [0 .. k - 1]])
  | col <- [0 .. n - 1]
  , row <- [0 .. m - 1]
  ]

gramMatrixColMajorCFloat :: Int -> Int -> [CFloat] -> [CFloat]
gramMatrixColMajorCFloat m n q =
  [ CFloat (sum [unCFloat (indexColMajor m q row i) * unCFloat (indexColMajor m q row j) | row <- [0 .. m - 1]])
  | j <- [0 .. n - 1]
  , i <- [0 .. n - 1]
  ]

indexColMajor :: Int -> [a] -> Int -> Int -> a
indexColMajor rows vals row col = vals !! (row + col * rows)

unCFloat :: CFloat -> Float
unCFloat (CFloat x) = x

detectCurrentGpuArch :: IO String
detectCurrentGpuArch = do
  archName <- hipGetCurrentDeviceGcnArchName
  if "gfx" `isPrefixOf` archName
    then pure archName
    else do
      archs <- discoverGpuArchs
      pure (case archs of
        x : _ -> x
        [] -> archName)

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
    extractName line =
      case break (== ':') line of
        ("Name", ':' : rest) -> Just (dropWhile isSpace rest)
        _ -> Nothing
