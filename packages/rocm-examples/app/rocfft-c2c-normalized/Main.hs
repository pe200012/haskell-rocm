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
  , rocfftPlanDescriptionSetScaleFactor
  , rocfftPlanGetWorkBufferSize
  , withRocfft
  , withRocfftExecutionInfo
  , withRocfftPlan
  , withRocfftPlanDescription
  , pattern RocfftPlacementInplace
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
  let n = 16 :: Int
      input :: [Complex Float]
      input = [fromIntegral k :+ fromIntegral ((k * 7) `mod` 5) | k <- [0 .. n - 1]]
      expected = input
      bytes = fromIntegral (n * sizeOf (undefined :: Complex Float)) :: CSize
      invScale = 1.0 / fromIntegral n :: Double

  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input

      bracket (hipMallocBytes bytes :: IO (DevicePtr (Complex Float))) hipFree $ \dBuf -> do
        hipMemcpyH2D dBuf (HostPtr hIn) bytes

        bracket hipStreamCreate hipStreamDestroy $ \stream ->
          withRocfftExecutionInfo $ \info -> do
            rocfftExecutionInfoSetStream info stream

            withRocfftPlan
              ( rocfftPlanCreate
                  RocfftPlacementInplace
                  RocfftTransformTypeComplexForward
                  RocfftPrecisionSingle
                  [fromIntegral n]
                  1
                  Nothing
              )
              $ \planF ->
                withRocfftPlanDescription $ \descInv -> do
                  rocfftPlanDescriptionSetScaleFactor descInv invScale
                  withRocfftPlan
                    ( rocfftPlanCreate
                        RocfftPlacementInplace
                        RocfftTransformTypeComplexInverse
                        RocfftPrecisionSingle
                        [fromIntegral n]
                        1
                        (Just descInv)
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

                          let DevicePtr p = dBuf
                              inPtrs = [castPtr p]
                          rocfftExecute planF inPtrs [] (Just info)
                          rocfftExecute planI inPtrs [] (Just info)
                          hipStreamSynchronize stream

        hipMemcpyD2H (HostPtr hOut) dBuf bytes

      out <- peekArray n hOut
      when (not (approxComplexVec out expected)) $ do
        putStrLn "rocFFT normalized mismatch"
        putStrLn ("expected: " <> show expected)
        putStrLn ("got:      " <> show out)
        exitFailure

  putStrLn "rocFFT normalized C2C: OK"

approxComplexVec :: [Complex Float] -> [Complex Float] -> Bool
approxComplexVec xs ys = length xs == length ys && and (zipWith approxComplex xs ys)

approxComplex :: Complex Float -> Complex Float -> Bool
approxComplex (ar :+ ai) (br :+ bi) = abs (ar - br) <= eps && abs (ai - bi) <= eps
  where
    eps = 1.0e-2
