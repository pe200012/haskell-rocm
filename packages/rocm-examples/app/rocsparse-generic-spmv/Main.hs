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
  , pattern RocsparseDataTypeF32R
  , pattern RocsparseIndexBaseZero
  , pattern RocsparseIndexTypeI32
  , pattern RocsparseOperationNone
  , pattern RocsparseV2SpMVStageAnalysis
  , pattern RocsparseV2SpMVStageCompute
  , rocsparseConfigureSV2SpMV
  , rocsparseSV2SpMV
  , rocsparseSV2SpMVBufferSize
  , rocsparseSetStream
  , withRocsparseCsrDescr
  , withRocsparseDnVecDescr
  , withRocsparseHandle
  , withRocsparseSpMVDescr
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
      putStrLn ("rocSPARSE generic SpMV: skipped on " <> archName <> " because this install only ships gfx1100 kernels.")
      putStrLn "Run with: HSA_OVERRIDE_GFX_VERSION=11.0.0 cabal run rocsparse-generic-spmv"
      putStrLn ("Current device: " <> deviceName)
    else do
      let m = 3 :: Int
          n = 3 :: Int
          nnz = 5 :: Int
          rowPtrVals = [0, 2, 3, 5] :: [Int]
          colIndVals = [0, 2, 1, 0, 2] :: [Int]
          valVals = fmap CFloat [1, 2, 3, 4, 5]
          xVals = fmap CFloat [10, 20, 30]
          yVals = replicate m (CFloat 0)
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
                pokeArray hY yVals

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
                            withRocsparseHandle $ \handle -> do
                              rocsparseSetStream handle stream
                              withRocsparseCsrDescr
                                (fromIntegral m)
                                (fromIntegral n)
                                (fromIntegral nnz)
                                dRowPtr
                                dColInd
                                dVal
                                RocsparseIndexTypeI32
                                RocsparseIndexTypeI32
                                RocsparseIndexBaseZero
                                RocsparseDataTypeF32R
                                $ \aDescr ->
                                  withRocsparseDnVecDescr (fromIntegral n) dX RocsparseDataTypeF32R $ \xDescr ->
                                    withRocsparseDnVecDescr (fromIntegral m) dY RocsparseDataTypeF32R $ \yDescr ->
                                      withRocsparseSpMVDescr $ \spmvDescr -> do
                                        rocsparseConfigureSV2SpMV handle spmvDescr RocsparseOperationNone
                                        analysisBytes <- rocsparseSV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr RocsparseV2SpMVStageAnalysis
                                        computeBytes <- rocsparseSV2SpMVBufferSize handle spmvDescr aDescr xDescr yDescr RocsparseV2SpMVStageCompute
                                        let bufferBytes = max analysisBytes computeBytes
                                        bracket
                                          ( if bufferBytes > 0
                                              then Just <$> (hipMallocBytes bufferBytes :: IO (DevicePtr ()))
                                              else pure Nothing
                                          )
                                          (\mTemp -> maybe (pure ()) hipFree mTemp)
                                          $ \mTemp -> do
                                            rocsparseSV2SpMV handle spmvDescr aDescr xDescr yDescr 1.0 0.0 RocsparseV2SpMVStageAnalysis bufferBytes mTemp
                                            rocsparseSV2SpMV handle spmvDescr aDescr xDescr yDescr 1.0 0.0 RocsparseV2SpMVStageCompute bufferBytes mTemp
                                            hipStreamSynchronize stream

                          hipMemcpyD2H (HostPtr hY) dY bytesY

                out <- peekArray m hY
                when (not (approxVec out expected)) $ do
                  putStrLn "rocsparse generic spmv mismatch"
                  putStrLn ("expected: " <> show expected)
                  putStrLn ("got:      " <> show out)
                  exitFailure

      putStrLn "rocSPARSE generic SpMV: OK"

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
