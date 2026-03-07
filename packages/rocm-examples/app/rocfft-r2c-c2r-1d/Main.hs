{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Complex (Complex)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (castPtr)
import Foreign.Storable (sizeOf)
import System.Exit (exitFailure)

import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..))
import ROCm.HIP
  ( hipFree
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  )
import ROCm.RocFFT
  ( rocfftExecute
  , rocfftExecutionInfoSetStream
  , rocfftExecutionInfoSetWorkBuffer
  , rocfftPlanCreate
  , rocfftPlanDescriptionSetDataLayout
  , rocfftPlanGetPrint
  , rocfftPlanGetWorkBufferSize
  , withRocfft
  , withRocfftExecutionInfo
  , withRocfftPlan
  , withRocfftPlanDescription
  , pattern RocfftArrayTypeHermitianInterleaved
  , pattern RocfftArrayTypeReal
  , pattern RocfftPlacementNotInplace
  , pattern RocfftPrecisionSingle
  , pattern RocfftTransformTypeRealForward
  , pattern RocfftTransformTypeRealInverse
  )

main :: IO ()
main = do
  r <- try run :: IO (Either SomeException ())
  case r of
    Left e -> putStrLn (displayException e) >> exitFailure
    Right () -> pure ()

run :: IO ()
run = withRocfft $ do
  let n = 8 :: Int
      freqCount = n `div` 2 + 1
      input = fmap (CFloat . fromIntegral) [0 .. n - 1]
      expected = fmap (\(CFloat x) -> CFloat (x * fromIntegral n)) input
      bytesIn = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      bytesFreq = fromIntegral (freqCount * sizeOf (undefined :: Complex Float)) :: CSize
      bytesOut = bytesIn
      lengths = [fromIntegral n]
      freqDistance = fromIntegral freqCount :: CSize
      realDistance = fromIntegral n :: CSize

  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      bracket (hipMallocBytes bytesIn :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
        bracket (hipMallocBytes bytesFreq :: IO (DevicePtr (Complex Float))) hipFree $ \dFreq ->
          bracket (hipMallocBytes bytesOut :: IO (DevicePtr CFloat)) hipFree $ \dOut -> do
            hipMemcpyH2D dIn (HostPtr hIn) bytesIn
            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              withRocfftExecutionInfo $ \info -> do
                rocfftExecutionInfoSetStream info stream
                withRocfftPlanDescription $ \descF -> do
                  rocfftPlanDescriptionSetDataLayout
                    descF
                    RocfftArrayTypeReal
                    RocfftArrayTypeHermitianInterleaved
                    Nothing
                    Nothing
                    [1]
                    realDistance
                    [1]
                    freqDistance
                  withRocfftPlanDescription $ \descI -> do
                    rocfftPlanDescriptionSetDataLayout
                      descI
                      RocfftArrayTypeHermitianInterleaved
                      RocfftArrayTypeReal
                      Nothing
                      Nothing
                      [1]
                      freqDistance
                      [1]
                      realDistance
                    withRocfftPlan
                      (rocfftPlanCreate RocfftPlacementNotInplace RocfftTransformTypeRealForward RocfftPrecisionSingle lengths 1 (Just descF))
                      $ \planF ->
                        withRocfftPlan
                          (rocfftPlanCreate RocfftPlacementNotInplace RocfftTransformTypeRealInverse RocfftPrecisionSingle lengths 1 (Just descI))
                          $ \planI -> do
                            rocfftPlanGetPrint planF
                            workF <- rocfftPlanGetWorkBufferSize planF
                            workI <- rocfftPlanGetWorkBufferSize planI
                            let workBytes = max workF workI
                            bracket
                              (if workBytes > 0 then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ())) else pure Nothing)
                              (maybe (pure ()) hipFree)
                              $ \mWork -> do
                                case mWork of
                                  Nothing -> pure ()
                                  Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes
                                let DevicePtr pIn = dIn
                                    DevicePtr pFreq = dFreq
                                    DevicePtr pOut = dOut
                                rocfftExecute planF [castPtr pIn] [castPtr pFreq] (Just info)
                                rocfftExecute planI [castPtr pFreq] [castPtr pOut] (Just info)
                                hipStreamSynchronize stream
            hipMemcpyD2H (HostPtr hOut) dOut bytesOut
      output <- peekArray n hOut
      when (not (approxVec output expected)) $ do
        putStrLn "rocFFT R2C/C2R mismatch"
        putStrLn ("expected: " <> show expected)
        putStrLn ("got:      " <> show output)
        exitFailure

  putStrLn "rocFFT r2c/c2r 1d: OK"

approxVec :: [CFloat] -> [CFloat] -> Bool
approxVec xs ys =
  length xs == length ys && and (zipWith approxCFloat xs ys)

approxCFloat :: CFloat -> CFloat -> Bool
approxCFloat (CFloat a) (CFloat b) = abs (a - b) <= 1.0e-2
