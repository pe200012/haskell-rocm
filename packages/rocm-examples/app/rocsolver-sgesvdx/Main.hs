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
  , pattern RocblasSrangeIndex
  , pattern RocblasSvectSingular
  , rocblasSetStream
  , withRocblasHandle
  )
import ROCm.RocSOLVER (rocsolverSgesvdx)

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
      putStrLn ("rocSOLVER sgesvdx: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsolver-sgesvdx"
      putStrLn ("Current device: " <> deviceName)
    else do
      let n = 2 :: Int
          k = 1 :: Int
          aOriginal = fmap CFloat [3, 0, 0, 1]
          expectedS = [CFloat 3]
          expectedPartial = fmap CFloat [3, 0, 0, 0]
          identity1 = [CFloat 1]
          bytesA = fromIntegral (n * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesNsv = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize
          bytesS = fromIntegral (k * sizeOf (undefined :: CFloat)) :: CSize
          bytesU = fromIntegral (n * k * sizeOf (undefined :: CFloat)) :: CSize
          bytesV = fromIntegral (k * n * sizeOf (undefined :: CFloat)) :: CSize
          bytesIfail = fromIntegral (n * sizeOf (undefined :: RocblasInt)) :: CSize
          bytesInfo = fromIntegral (sizeOf (undefined :: RocblasInt)) :: CSize

      bracket (mallocArray (n * n) :: IO (Ptr CFloat)) free $ \hA ->
        bracket (mallocArray k :: IO (Ptr CFloat)) free $ \hS ->
          bracket (mallocArray (n * k) :: IO (Ptr CFloat)) free $ \hU ->
            bracket (mallocArray (k * n) :: IO (Ptr CFloat)) free $ \hV ->
              bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hNsv ->
                bracket (mallocArray n :: IO (Ptr RocblasInt)) free $ \hIfail ->
                  bracket (mallocArray 1 :: IO (Ptr RocblasInt)) free $ \hInfo -> do
                    pokeArray hA aOriginal

                    bracket (hipMallocBytes bytesA :: IO (DevicePtr CFloat)) hipFree $ \dA ->
                      bracket (hipMallocBytes bytesNsv :: IO (DevicePtr RocblasInt)) hipFree $ \dNsv ->
                        bracket (hipMallocBytes bytesS :: IO (DevicePtr CFloat)) hipFree $ \dS ->
                          bracket (hipMallocBytes bytesU :: IO (DevicePtr CFloat)) hipFree $ \dU ->
                            bracket (hipMallocBytes bytesV :: IO (DevicePtr CFloat)) hipFree $ \dV ->
                              bracket (hipMallocBytes bytesIfail :: IO (DevicePtr RocblasInt)) hipFree $ \dIfail ->
                                bracket (hipMallocBytes bytesInfo :: IO (DevicePtr RocblasInt)) hipFree $ \dInfo -> do
                                  hipMemcpyH2D dA (HostPtr hA) bytesA

                                  bracket hipStreamCreate hipStreamDestroy $ \stream ->
                                    withRocblasHandle $ \handle -> do
                                      rocblasSetStream handle stream
                                      rocsolverSgesvdx
                                        handle
                                        RocblasSvectSingular
                                        RocblasSvectSingular
                                        RocblasSrangeIndex
                                        (fromIntegral n :: RocblasInt)
                                        (fromIntegral n :: RocblasInt)
                                        dA
                                        (fromIntegral n :: RocblasInt)
                                        0.0
                                        0.0
                                        1
                                        1
                                        dNsv
                                        dS
                                        dU
                                        (fromIntegral n :: RocblasInt)
                                        dV
                                        1
                                        dIfail
                                        dInfo
                                      hipStreamSynchronize stream

                                  hipMemcpyD2H (HostPtr hNsv) dNsv bytesNsv
                                  hipMemcpyD2H (HostPtr hS) dS bytesS
                                  hipMemcpyD2H (HostPtr hU) dU bytesU
                                  hipMemcpyD2H (HostPtr hV) dV bytesV
                                  hipMemcpyD2H (HostPtr hIfail) dIfail bytesIfail
                                  hipMemcpyD2H (HostPtr hInfo) dInfo bytesInfo

                    nsvVals <- peekArray 1 hNsv
                    sVals <- peekArray k hS
                    uVals <- peekArray (n * k) hU
                    vVals <- peekArray (k * n) hV
                    ifailVals <- peekArray n hIfail
                    infoVals <- peekArray 1 hInfo
                    let infoOk = case infoVals of
                          [infoVal] -> infoVal == 0
                          _ -> False
                        nsvOk = case nsvVals of
                          [nsv] -> nsv == 1
                          _ -> False
                        ifailOk = case ifailVals of
                          x : _ -> x == 0
                          _ -> False
                        partial = matMulRightRowVector (matMulColMajorCFloat n k k uVals (diagColMajorCFloat sVals)) vVals
                        uGram = gramMatrixColMajorCFloat n k uVals
                        vNorm = [CFloat (sum [unCFloat x * unCFloat x | x <- vVals])]
                    when (not (infoOk && nsvOk && ifailOk && approxVecWithTol 1.0e-3 sVals expectedS && approxVecWithTol 1.0e-3 partial expectedPartial && approxVecWithTol 1.0e-3 uGram identity1 && approxVecWithTol 1.0e-3 vNorm identity1)) $ do
                      putStrLn "rocsolver_sgesvdx mismatch"
                      putStrLn ("nsv:     " <> show nsvVals)
                      putStrLn ("s:       " <> show sVals)
                      putStrLn ("partial: " <> show partial)
                      putStrLn ("uGram:   " <> show uGram)
                      putStrLn ("vNorm:   " <> show vNorm)
                      putStrLn ("ifail:   " <> show ifailVals)
                      putStrLn ("info:    " <> show infoVals)
                      exitFailure

      putStrLn "rocSOLVER sgesvdx: OK"

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

matMulRightRowVector :: [CFloat] -> [CFloat] -> [CFloat]
matMulRightRowVector left right =
  [ CFloat (unCFloat x * unCFloat y)
  | y <- right
  , x <- left
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
