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
import ROCm.RocSPARSE
  ( RocsparseInt
  , pattern RocsparseIndexBaseZero
  , pattern RocsparseMatrixTypeGeneral
  , pattern RocsparseOperationNone
  , rocsparseScsrmv
  , rocsparseSetMatIndexBase
  , rocsparseSetMatType
  , rocsparseSetStream
  , withRocsparseHandle
  , withRocsparseMatDescr
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
      putStrLn ("rocSPARSE scsrmv: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsparse-scsrmv"
      putStrLn ("Current device: " <> deviceName)
    else do
      let m = 3 :: Int
          n = 3 :: Int
          nnz = 5 :: Int
          rowPtrVals = [0, 2, 3, 5] :: [Int]
          colIndVals = [0, 2, 1, 0, 2] :: [Int]
          valVals = fmap CFloat [1, 2, 3, 4, 5]
          xVals = fmap CFloat [10, 20, 30]
          expected = fmap CFloat [70, 60, 190]
          bytesRowPtr = fromIntegral (length rowPtrVals * sizeOf (undefined :: RocsparseInt)) :: CSize
          bytesColInd = fromIntegral (nnz * sizeOf (undefined :: RocsparseInt)) :: CSize
          bytesVal = fromIntegral (nnz * sizeOf (undefined :: CFloat)) :: CSize
          bytesX = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
          bytesY = fromIntegral (m * sizeOf (undefined :: CFloat)) :: CSize

      bracket (mallocArray (length rowPtrVals) :: IO (Ptr RocsparseInt)) free $ \hRowPtr ->
        bracket (mallocArray nnz :: IO (Ptr RocsparseInt)) free $ \hColInd ->
          bracket (mallocArray nnz :: IO (Ptr CFloat)) free $ \hVal ->
            bracket (mallocArray n :: IO (Ptr CFloat)) free $ \hX ->
              bracket (mallocArray m :: IO (Ptr CFloat)) free $ \hY -> do
                pokeArray hRowPtr (fromIntegral <$> rowPtrVals)
                pokeArray hColInd (fromIntegral <$> colIndVals)
                pokeArray hVal valVals
                pokeArray hX xVals
                pokeArray hY (replicate m (CFloat 0))

                bracket (hipMallocBytes bytesRowPtr :: IO (DevicePtr RocsparseInt)) hipFree $ \dRowPtr ->
                  bracket (hipMallocBytes bytesColInd :: IO (DevicePtr RocsparseInt)) hipFree $ \dColInd ->
                    bracket (hipMallocBytes bytesVal :: IO (DevicePtr CFloat)) hipFree $ \dVal ->
                      bracket (hipMallocBytes bytesX :: IO (DevicePtr CFloat)) hipFree $ \dX ->
                        bracket (hipMallocBytes bytesY :: IO (DevicePtr CFloat)) hipFree $ \dY -> do
                          hipMemcpyH2D dRowPtr (HostPtr hRowPtr) bytesRowPtr
                          hipMemcpyH2D dColInd (HostPtr hColInd) bytesColInd
                          hipMemcpyH2D dVal (HostPtr hVal) bytesVal
                          hipMemcpyH2D dX (HostPtr hX) bytesX
                          hipMemcpyH2D dY (HostPtr hY) bytesY

                          bracket hipStreamCreate hipStreamDestroy $ \stream ->
                            withRocsparseHandle $ \handle ->
                              withRocsparseMatDescr $ \descr -> do
                                rocsparseSetStream handle stream
                                rocsparseSetMatIndexBase descr RocsparseIndexBaseZero
                                rocsparseSetMatType descr RocsparseMatrixTypeGeneral
                                rocsparseScsrmv
                                  handle
                                  RocsparseOperationNone
                                  (fromIntegral m :: RocsparseInt)
                                  (fromIntegral n :: RocsparseInt)
                                  (fromIntegral nnz :: RocsparseInt)
                                  1.0
                                  descr
                                  dVal
                                  dRowPtr
                                  dColInd
                                  dX
                                  0.0
                                  dY
                                hipStreamSynchronize stream

                          hipMemcpyD2H (HostPtr hY) dY bytesY

                out <- peekArray m hY
                when (not (approxVec out expected)) $ do
                  putStrLn "rocsparse_scsrmv mismatch"
                  putStrLn ("expected: " <> show expected)
                  putStrLn ("got:      " <> show out)
                  exitFailure

      putStrLn "rocSPARSE scsrmv: OK"

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys = length xs == length ys && and (zipWith approxCFloat xs ys)

approxCFloat :: CFloat -> CFloat -> Bool
approxCFloat (CFloat a) (CFloat b) = abs (a - b) <= 1.0e-4

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
