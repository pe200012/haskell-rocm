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
  , pattern RocblasEvectOriginal
  , pattern RocblasFillLower
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSsyev)

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
      putStrLn ("rocSOLVER ssyev: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-ssyev"
      putStrLn ("Current device: " <> deviceName)
    else do
      let n = 2 :: Int
          aOriginal = fmap CFloat [2, 1, 1, 2]
          expectedVals = fmap CFloat [1, 3]
          identity2 = fmap CFloat [1, 0, 0, 1]
          bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesD = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
          bytesE = fromIntegral ((n - 1) * sizeOf (undefined :: CFloat)) :: CSize
          bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

      bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
        bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hD ->
          bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
            pokeArray hA aOriginal

            bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
              bracket (hipMallocBytes bytesD :: IO (DevicePtr CFloat)) hipFree $ \dD ->
                bracket (hipMallocBytes bytesE :: IO (DevicePtr CFloat)) hipFree $ \dE ->
                  bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                    hipMemcpyH2D dA (HostPtr hA) bytesA

                    bracket hipStreamCreate hipStreamDestroy $ \stream ->
                      withRocblasHandle $ \handle -> do
                        rocblasSetStream handle stream
                        rocsolverSsyev
                          handle
                          RocblasEvectOriginal
                          RocblasFillLower
                          (fromIntegral n :: RocblasInt)
                          dA
                          (fromIntegral n :: RocblasInt)
                          dD
                          dE
                          dInfo
                        hipStreamSynchronize stream

                    hipMemcpyD2H (HostPtr hA) dA bytesA
                    hipMemcpyD2H (HostPtr hD) dD bytesD
                    hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

            vectors <- peekArray (n * n) hA
            eigenVals <- peekArray n hD
            infoVals <- peekArray 1 hInfo
            let infoOk = case infoVals of
                  [infoVal] -> infoVal == 0
                  _ -> False
                lhs = matMulColMajorCFloat n n n aOriginal vectors
                rhs = matMulColMajorCFloat n n n vectors (diagColMajorCFloat eigenVals)
                gram = gramMatrixColMajorCFloat n n vectors
            when (not (infoOk && approxVecWithTol 1.0e-3 eigenVals expectedVals && approxVecWithTol 1.0e-3 lhs rhs && approxVecWithTol 1.0e-3 gram identity2)) $ do
              putStrLn "rocsolver_ssyev mismatch"
              putStrLn ("eigenVals: " <> show eigenVals)
              putStrLn ("lhs:      " <> show lhs)
              putStrLn ("rhs:      " <> show rhs)
              putStrLn ("gram:     " <> show gram)
              putStrLn ("info:     " <> show infoVals)
              exitFailure

      putStrLn "rocSOLVER ssyev: OK"

approxVecWithTol :: Float -> [CFloat] -> [CFloat] -> Bool
approxVecWithTol eps xs ys =
  length xs == length ys
    && and (zipWith (approxCFloatWithTol eps) xs ys)

approxCFloatWithTol :: Float -> CFloat -> CFloat -> Bool
approxCFloatWithTol eps (CFloat a) (CFloat b) = abs (a - b) <= eps

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

diagColMajorCFloat :: [CFloat] -> [CFloat]
diagColMajorCFloat vals =
  [ if row == col then vals !! row else CFloat 0
  | col <- [0 .. n - 1]
  , row <- [0 .. n - 1]
  ]
  where
    n = length vals

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
