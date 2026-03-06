{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (when)
import Data.Complex (Complex((:+)))
import Foreign.C.Types (CSize)
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
  , rocfftPlanGetWorkBufferSize
  , withRocfft
  , withRocfftExecutionInfo
  , withRocfftPlan
  , withRocfftPlanDescription
  , pattern RocfftArrayTypeComplexInterleaved
  , pattern RocfftPlacementNotInplace
  , pattern RocfftPrecisionSingle
  , pattern RocfftTransformTypeComplexForward
  , pattern RocfftTransformTypeComplexInverse
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
run = withRocfft $ do
  let len1 = 4 :: Int
      batchCount = 2 :: Int
      total = len1 * batchCount
      scale = fromIntegral len1 :: Float
      input :: [Complex Float]
      input = [fromIntegral i :+ fromIntegral ((i * 3) `mod` 5) | i <- [0 .. total - 1]]
      expected = fmap (\z -> z * (scale :+ 0)) input
      bytes = fromIntegral (total * sizeOf (undefined :: Complex Float)) :: CSize
      strides = [1]
      distance = fromIntegral len1 :: CSize

  bracket (mallocArray total) free $ \hIn ->
    bracket (mallocArray total) free $ \hOut -> do
      pokeArray hIn input

      bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dMid ->
          bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dOut -> do
            hipMemcpyH2D dIn (HostPtr hIn) bytes

            bracket hipStreamCreate hipStreamDestroy $ \stream ->
              withRocfftExecutionInfo $ \info -> do
                rocfftExecutionInfoSetStream info stream

                withRocfftPlanDescription $ \desc -> do
                  rocfftPlanDescriptionSetDataLayout
                    desc
                    RocfftArrayTypeComplexInterleaved
                    RocfftArrayTypeComplexInterleaved
                    Nothing
                    Nothing
                    strides
                    distance
                    strides
                    distance

                  withRocfftPlan
                    ( rocfftPlanCreate
                        RocfftPlacementNotInplace
                        RocfftTransformTypeComplexForward
                        RocfftPrecisionSingle
                        [fromIntegral len1]
                        (fromIntegral batchCount)
                        (Just desc)
                    )
                    $ \planF ->
                      withRocfftPlan
                        ( rocfftPlanCreate
                            RocfftPlacementNotInplace
                            RocfftTransformTypeComplexInverse
                            RocfftPrecisionSingle
                            [fromIntegral len1]
                            (fromIntegral batchCount)
                            (Just desc)
                        )
                        $ \planI -> do
                          workF <- rocfftPlanGetWorkBufferSize planF
                          workI <- rocfftPlanGetWorkBufferSize planI
                          let workBytes = max workF workI

                          bracket
                            (if workBytes > 0 then Just <$> (hipMallocBytes workBytes :: IO (DevicePtr ())) else pure Nothing)
                            (\m -> maybe (pure ()) hipFree m)
                            $ \mWorkBuf -> do
                              case mWorkBuf of
                                Nothing -> pure ()
                                Just workBuf -> rocfftExecutionInfoSetWorkBuffer info workBuf workBytes

                              let DevicePtr pIn = dIn
                                  DevicePtr pMid = dMid
                                  DevicePtr pOut = dOut
                              rocfftExecute planF [castPtr pIn] [castPtr pMid] (Just info)
                              rocfftExecute planI [castPtr pMid] [castPtr pOut] (Just info)
                              hipStreamSynchronize stream

            hipMemcpyD2H (HostPtr hOut) dOut bytes

      out <- peekArray total hOut
      when (not (approxComplexVec out expected)) $ do
        putStrLn "rocFFT batched not-inplace mismatch"
        putStrLn ("expected: " <> show expected)
        putStrLn ("got:      " <> show out)
        exitFailure

  putStrLn "rocFFT batched not-inplace: OK"

approxComplexVec :: [Complex Float] -> [Complex Float] -> Bool
approxComplexVec xs ys = length xs == length ys && and (zipWith approxComplex xs ys)

approxComplex :: Complex Float -> Complex Float -> Bool
approxComplex (ar :+ ai) (br :+ bi) = abs (ar - br) <= eps && abs (ai - bi) <= eps
  where
    eps = 1.0e-2
